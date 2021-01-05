# Building Fault & CyberAttack Test Framework

This repository contains prototype code for the Building Fault & CyberAttack Test Framework

## Structure
- ``/model`` contains model dependencies, model files and default configuration files
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

## Test Case RESTful API
- To interact with a deployed test case, use the API defined in the table below by sending RESTful requests to: ``http://127.0.0.1:5000/<request>``

  Example RESTful interaction:
  -- Receive a list of available measurement names and their metadata: ``$ curl http://127.0.0.1:5000/measurements``

| Interaction                                                           | Request                                                   |
|-----------------------------------------------------------------------|-----------------------------------------------------------|
| Advance simulation with control input and receive measurements        |  POST ``advance`` with json data "{<input_name>:<value>}" |
| Initialize simulation using a warmup period in seconds                |  PUT ``reset`` with arguments ``start_time=<value>``, ``end_time=<value>``|
| Receive communication step in seconds                                 |  GET ``step``                                             |
| Set communication step in seconds                                     |  PUT ``step`` with argument ``step=<value>``              |
| Receive sensor signal names (y) and metadata                          |  GET ``measurements``                                     |
| Receive control signals names (u) and metadata                        |  GET ``inputs``                                           |
| Receive test result data                                              |  GET ``results``                                          |
| Receive model key points (fault types, I/O)                           |  GET ``faults``                                           |
| Receive detailed information for a given key point                    |  GET ``fault_info`` with argument ``fault=<point_name>``  |
| Receive current scenario setting, including faults and I/O            |  GET ``fault_scenario``                                   |
| Set test scenario  		                                            |  PUT ``fault_scenario`` with arguments regarding faults and I/O |

## Key Points 

The key points for the testing AFDD model (AHU) is discussed in ``/model/fmu/fault.json``.
Those points can be categorized in three groups and have three properties: ``path``, ``description``, and ``type``. 
The ``path`` defines the location of the corresponding fault in the studied model.
The ``description`` defines the location of the corresponding fault in the system that the studied model represent.
The ``type`` defines the type of this key point. 
Types of key points are defined in ``/model/fmu/config.json`` and are independent of AFDD models.  

## Fault Scenario

The fault scenario defines the faults, the inputs, and the outputs for a simulation run.
The fault points are defined as ``{<point_name>:{value:<value of fault intensive parameter>,fault_time:<time when the fault occurs>}``.
The input/output points are defined as ``{<point_name>:{name:<name of the input and output>}``.
