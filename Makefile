include $(shell pwd)/env
all: test
test: build run clean

build:
	podman build -t $(MANIFESTS_FULL_IMG_URL) --build-arg ORG=$(GIT_REPO_ORG) --build-arg BRANCH=$(GIT_REPO_BRANCH) .

run:
	# Confirm that we have a directory for storing any screenshots from selenium tests
	mkdir -p ${LOCAL_ARTIFACT_DIR}/screenshots
	oc config view --flatten --minify > /tmp/tests-kubeconfig
	podman run -e SKIP_INSTALL=$(SKIP_ADD_LOGIN_PROVIDER) -e TESTS_REGEX=basictests -e TEST_NAMESPACE=$(TEST_NAMESPACE) \
		-e OPENSHIFT_USER="$(OPENSHIFT_USER)" -e OPENSHIFT_PASS="$(OPENSHIFT_PASS)" -e OPENSHIFT_LOGIN_PROVIDER=$(OPENSHIFT_LOGIN_PROVIDER) -e ARTIFACT_DIR=$(ARTIFACT_DIR) \
		-it -v ${LOCAL_ARTIFACT_DIR}/:$(ARTIFACT_DIR):z -v /tmp/tests-kubeconfig:/tmp/kubeconfig:z $(MANIFESTS_FULL_IMG_URL)

push-image:
	@echo "Pushing the $(MANIFESTS_FULL_IMG_URL)"
	podman push $(MANIFESTS_FULL_IMG_URL)

image: build push-image

build-base-img:
	podman build -f Dockerfile.base -t quay.io/jooholee/manifests-test-base:latest .

push-base-img:
	podman push quay.io/jooholee/manifests-test-base:latest

base-image: build-base-img push-base-img


# During building ODH manifest test image, many garbage iamges will be created. This target clean them up.
clean-images:
	for im in $$(podman images|grep '\<none' |awk '{print $$3}'); do podman rmi --force $$im;done
