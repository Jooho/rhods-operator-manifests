#!/bin/bash

set -x

source ./env.sh
mkdir -p ~/.kube
cp /tmp/kubeconfig ~/.kube/config 2> /dev/null || cp /var/run/secrets/ci.openshift.io/multi-stage/kubeconfig ~/.kube/config
chmod 644 ~/.kube/config
export KUBECONFIG=~/.kube/config
export ARTIFACT_SCREENSHOT_DIR="${ARTIFACT_DIR}/screenshots"

if [ ! -d "${ARTIFACT_SCREENSHOTS_DIR}" ]; then
  echo "Creating the screenshot artifact directory: ${ARTIFACT_SCREENSHOT_DIR}"
  mkdir -p ${ARTIFACT_SCREENSHOT_DIR}
fi

TESTS_REGEX=${TESTS_REGEX:-"basictests"}
TEST_NAMESPACE=${TEST_NAMESPACE:-"opendatahub"}
export TEST_NAMESPACE

echo "OCP version info"
echo `oc version`

if [ -z "${OPENSHIFT_USER}" ] || [ -z "${OPENSHIFT_PASS}" ]; then
  OAUTH_PATCH_TEXT="$(cat $HOME/peak/operator-tests/manifests/resources/oauth-patch.htpasswd.json)"
  echo "Creating HTPASSWD OAuth provider"
  oc apply -f $HOME/peak/operator-tests/manifests/resources/htpasswd.secret.yaml

  # Test if any oauth identityProviders exists. If not, initialize the identityProvider list
  if ! oc get oauth cluster -o json | jq -e '.spec.identityProviders' ; then
    echo 'No oauth identityProvider exists. Initializing oauth .spec.identityProviders = []'
    oc patch oauth cluster --type json -p '[{"op": "add", "path": "/spec/identityProviders", "value": []}]'
  fi

  # Patch in the htpasswd identityProvider prevent deletion of any existing identityProviders like ldap
  #  We can have multiple identityProvdiers enabled aslong as their 'name' value is unique
  oc patch oauth cluster --type json -p '[{"op": "add", "path": "/spec/identityProviders/-", "value": '"$OAUTH_PATCH_TEXT"'}]'

  # Add default user "admin" for jupyterhub to group "rhods-users"
  oc adm groups new rhods-users
  oc adm groups add-users rhods-users admin

  export OPENSHIFT_USER=admin
  export OPENSHIFT_PASS=admin
  
  echo "Wait 1 min for new auth applied"
  sleep 60
  
else
  # Update User/Password
  sed "s/AUTH_TYPE: test-htpasswd-provider/AUTH_TYPE: ${OPENSHIFT_LOGIN_PROVIDER}/g" -i $HOME/peak/operator-tests/manifests/resources/test-variables.yml
  sed "s/USERNAME: admin/USERNAME: ${OPENSHIFT_USER}/g" -i $HOME/peak/operator-tests/manifests/resources/test-variables.yml
  sed "s/PASSWORD: admin/PASSWORD: ${OPENSHIFT_PASS}/g" -i $HOME/peak/operator-tests/manifests/resources/test-variables.yml
fi

env | sort >  ${ARTIFACT_DIR}/env.txt

success=1
$HOME/peak/run.sh ${TESTS_REGEX}

if  [ "$?" -ne 0 ]; then
    echo "The tests failed"
    success=0
fi

echo "Saving the dump of the pods logs in the artifacts directory"
oc get pods -o yaml -n ${TEST_NAMESPACE} > ${ARTIFACT_DIR}/${TEST_NAMESPACE}.pods.yaml
oc get pods -o yaml -n openshift-operators > ${ARTIFACT_DIR}/openshift-operators.pods.yaml
echo "Saving the events in the artifacts directory"
oc get events --sort-by='{.lastTimestamp}' > ${ARTIFACT_DIR}/${TEST_NAMESPACE}.events.txt
# echo "Saving the logs from the operator pod in the artifacts directory"
# oc logs -n openshift-operators $(oc get pods -n openshift-operators -l name=$OPERATOR_NAME -o jsonpath="{$.items[*].metadata.name}") > ${ARTIFACT_DIR}/operator.log 2> /dev/null || echo "No logs for openshift-operators/$OPERATOR_NAME"

if [ "$success" -ne 1 ]; then
    exit 1
fi



## Debugging pause...uncomment below to be able to poke around the test pod post-test
# echo "Debugging pause for 3 hours"
#sleep 180m
