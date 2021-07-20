FROM quay.io/jooholee/manifests-test-base:latest

ENV HOME /root
WORKDIR /root

COPY env.sh scripts/installandtest.sh $HOME/peak/
COPY resources $HOME/peak/operator-tests/manifests/resources
COPY util $HOME/peak/operator-tests/manifests
COPY basictests $HOME/peak/operator-tests/manifests/basictests
 
RUN mkdir -p $HOME/.kube && \
    chmod -R 777 $HOME/.kube && \
    chmod -R 777 $HOME/peak && \
    mkdir -p /peak && \
    chmod -R 777 $HOME && \
    ln -s $HOME/peak/installandtest.sh /peak/installandtest.sh

# For local testing, you can add your own kubeconfig to the image
# Note:  Do not push the image to a public repo with your kubeconfig
# ADD kubeconfig /root/.kube/config

CMD $HOME/peak/installandtest.sh
