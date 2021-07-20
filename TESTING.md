# Testing

## Manifests Test Image
This image is based on `quay.io/jooholee/manifests-test-base:latest`. 

## Prerequisites
It has a integration test using RHODS jupyterhub so you need to install RHODS addon before testing it.

## How to use
~~~
# Build and Test
$ make build run

# Build and Push
$ make image
~~~

