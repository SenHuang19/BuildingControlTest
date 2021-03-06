# -*- coding: utf-8 -*-
"""
This module implements the REST API used to interact with the test case.  
The API is implemented using the ``flask`` package.  

"""

# GENERAL PACKAGE IMPORT
# ----------------------
from flask import Flask, request
from flask_restful import Resource, Api, reqparse
import json
# ----------------------

# -----------------------

# DEFINE REST REQUESTS
# --------------------
class Advance(Resource):
    """Interface to advance the test case simulation."""

    def __init__(self, **kwargs):
        self.case = kwargs["case"]
        self.parser_advance = kwargs["parser_advance"]

    def post(self):
        """
        POST request with input data to advance the simulation one step 
        and receive current measurements.
        """
        u = self.parser_advance.parse_args()
        y = self.case.advance(u)
        return y

class Reset(Resource):
    """
    Interface to test case simulation step size.
    """
    
    def __init__(self, **kwargs):
            self.case = kwargs["case"]
            self.parser_reset = kwargs["parser_reset"]

    def put(self):
        """PUT request to reset the test."""
        u = self.parser_reset.parse_args()
        y = self.case.initialize(float(u['start_time']),float(u['end_time'])-float(u['start_time']))
        return y

               
class Step(Resource):
    """Interface to test case simulation step size."""

    def __init__(self, **kwargs):
            self.case = kwargs["case"]
            self.parser_step = kwargs["parser_step"]

    def get(self):
        """GET request to receive current simulation step in seconds."""
        return self.case.get_step()

    def put(self):
        """PUT request to set simulation step in seconds."""
        args = self.parser_step.parse_args()
        step = args['step']
        self.case.set_step(step)
        return step, 201   

class Faults(Resource):
    """Interface to get the fault list."""

    def __init__(self, **kwargs):
            self.case = kwargs["case"]

    def get(self):
        """GET request to receive the fault list."""
        return self.case.get_faults()

class Info(Resource):
    """Interface to get the detailed information of a selected fault."""

    def __init__(self, **kwargs):
            self.case = kwargs["case"]
            self.parser_fault_info = kwargs["parser_fault_info"]

    def get(self):
        """GET request to receive the fault information."""
        args = self.parser_fault_info.parse_args()
        fault = args['fault']      
        return self.case.get_fault_info(fault) 
        
class Scenario(Resource):
    """Interface to test case simulation step size."""

    def __init__(self, **kwargs):
            self.case = kwargs["case"]
            self.parser_fault_scenario = kwargs["parser_fault_scenario"]

    def get(self):
        """GET request to receive current simulation step in seconds."""
        return self.case.get_scenario()

    def put(self):
        """PUT request to set simulation step in seconds."""
        args = self.parser_fault_scenario.parse_args()
        print args
        self.case.set_fault_scenario(args)
        return None  

class Results(Resource):
    """Interface to test case result data."""

    def __init__(self, **kwargs):
            self.case = kwargs["case"]

    def get(self):
        """GET request to receive measurement data."""
        
        Y = self.case.get_results()
        return Y

class Inputs(Resource):
    """Interface to test case inputs."""

    def __init__(self, **kwargs):
            self.case = kwargs["case"]
        
    def get(self):
        """GET request to receive list of available inputs."""
        u_list = self.case.get_inputs()
        return list(u_list)
                
class Measurements(Resource):
    """Interface to test case measurements."""

    def __init__(self, **kwargs):
            self.case = kwargs["case"]
        
    def get(self):
        """GET request to receive list of available measurements."""
        y_list = self.case.get_measurements()
        return list(y_list)

def main(config):
    
    # FLASK REQUIREMENTS
    # ------------------
    app = Flask(__name__)
    api = Api(app)
    # ------------------

    # INSTANTIATE TEST CASE
    # ---------------------
    from testcase import TestCase
    with open(config) as json_file:
        model_config = json.load(json_file)
    case = TestCase(model_config)
    # ---------------------

    # DEFINE ARGUMENT PARSERS
    # -----------------------
    # ``step`` interface
    parser_step = reqparse.RequestParser()
    parser_step.add_argument('step')
    # ``fault_info`` interface
    parser_fault_info = reqparse.RequestParser()
    parser_fault_info.add_argument('fault')
    # ``reset`` interface
    reset_step = reqparse.RequestParser()
    reset_step.add_argument('start_time')
    reset_step.add_argument('end_time')
    # ``advance`` interface
    parser_advance = reqparse.RequestParser()
    for key in case.u.keys():
        parser_advance.add_argument(key)

    # ``fault_scenario`` interface
    parser_fault_scenario = reqparse.RequestParser()
    for key in case.info.keys():
        parser_fault_scenario.add_argument(key)

    # --------------------------------------
    # ADD REQUESTS TO API WITH URL EXTENSION
    # --------------------------------------
    api.add_resource(Advance, '/advance', resource_class_kwargs = {"case": case, "parser_advance": parser_advance})
    api.add_resource(Reset, '/reset', resource_class_kwargs = {"case": case, "parser_reset": reset_step, "config":config})
    api.add_resource(Step, '/step', resource_class_kwargs = {"case": case, "parser_step": parser_step})
    api.add_resource(Results, '/results', resource_class_kwargs = {"case": case})
    api.add_resource(Inputs, '/inputs', resource_class_kwargs = {"case": case})
    api.add_resource(Measurements, '/measurements', resource_class_kwargs = {"case": case})
    api.add_resource(Faults, '/faults', resource_class_kwargs = {"case": case})
    api.add_resource(Info, '/fault_info', resource_class_kwargs = {"case": case, "parser_fault_info": parser_fault_info})
    api.add_resource(Scenario, '/fault_scenario', resource_class_kwargs = {"case": case, "parser_fault_scenario": parser_fault_scenario})
    # --------------------------------------

    app.run(debug=False, host='0.0.0.0')        

    # --------------------------------------

if __name__ == '__main__':
    import sys
    main(sys.argv[1])
