# Building Fault & CyberAttack Test Framework

This repository contains prototype code for the Building Fault & CyberAttack Test Framework

## Structure
- ``/testcases`` contains model dependencies, model files and default configuration files
- ``/examples`` contains examples about how to use different Application Programming Interface (APIs)

## Quick-Start to Run Test Cases
1) Install [Docker](https://docs.docker.com/get-docker/) and [make](Window: http://gnuwin32.sourceforge.net/packages/make.htm; Linux: sudo apt-get install build-essential; Mac: https://stackoverflow.com/questions/11494522/installing-make-on-mac/11494872).
2) Clone this repo with git clone --recurse-submodules https://github.com/SenHuang19/AFDD_test.
3) Build the test case by ``$ make build``
4) Deploy the test case by ``$ make run``
   * Note that the localhost (port:5000) will be used by default
     To modify the default setting, change the line 5 of the makefile.
	 See more information in https://docs.docker.com/config/containers/container-networking/
5) In a separate process, use the APIs to interact with the Docker.
6) Shutdown a Docker with ``Ctrl+C`` to close port, and ``Ctrl+D`` to exit the Docker container.
7) Remove the Docker container by ``$ docker rm jmodelica``.
8) Remove the Docker image by ``$ make remove-image``.