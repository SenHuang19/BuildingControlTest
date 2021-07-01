# -*- coding: utf-8 -*-
"""
This module defines the API to the test case used by the REST requests to 
perform functions such as advancing the simulation, retreiving test case 
information, and calculating and reporting results.
"""

from pyfmi import load_fmu
import numpy as np
import copy
import json
import time
from jinja2 import Template
import jinja2
from pymodelica import compile_fmu
import ast
import numpy as np

templateLoader = jinja2.FileSystemLoader(searchpath='.')
templateEnv = jinja2.Environment(loader=templateLoader)

def cosim_data(u, dic):
    y = {}  
    for key in dic:
        arry = dic[key]     
        temp1 = 0      
        for i in range(len(arry[0])):        
            temp2 = 1     
            for j in range(len(arry)):
                   try:
                               temp2 = temp2 * float(arry[j][i]) 
                   except ValueError:
                               temp2 = temp2 * float(u[arry[j][i]])                                              
            temp1 = temp1 + temp2                              
        y.update({key:temp1})       
    return y   

def _process_input(u, start_time):
    '''Convert the input dictionary into a structured array.
        
    Parameters
    ----------
    u : dict
        Defines the control input data to be used for the step.
        {<input_name> : <input_value>}
        
    start_time: int
        Start time of simulation in seconds.
            
        
    Returns
    -------
    input_object : structured array
        Input for next time step
            
    '''    
        
    if u.keys():
        # If there are overwriting keys available
        # Check that any are overwritten
        written = False
        for key in u.keys():
            if u[key]:
                written = True
                break
        # If there are, create input object
        if written:
            u_list = []
            u_trajectory = start_time
            for key in u.keys():
                if key != 'time' and u[key]:
                    value = float(u[key])
                    u_list.append(key)
                    u_trajectory = np.vstack((u_trajectory, value))
            input_object = (u_list, np.transpose(u_trajectory))
        # Otherwise, input object is None
        else:
            input_object = None    
        # Otherwise, input object is None
    else:
        input_object = None  
    return input_object   

def path2modifer(keys,info,config):
    '''Generating a Modelica model modifier
        
    Parameters
    ----------
    keys : dict
        Defines the module parameters.
        
    info: dict
        Defines the module configuration.
        
    config: dict
        Defines the modifier template string.
                    
    Returns
    -------
    input_object : structured array
        Input for next time step
            
    '''   
    modifier = ''
    for key in keys.keys():
#       print keys[key]
       if keys[key] is not None:
          if not isinstance(keys[key],dict):
               keys[key] = ast.literal_eval(keys[key])
          path = info[key]['path']   
          fault_type = info[key]['type']
          args=path.split('.')
          temp =''          
          if fault_type.find('output')==-1 and fault_type.find('input')==-1:            
             temp = config[fault_type]['string'].format(args[-1],keys[key]['value'],keys[key]['fault_time'])  
          elif fault_type.find('inputs')!=-1:
             temp = config[fault_type]['string'].format(args[-1],keys[key]['name'],keys[key]['name'])   
          if temp != '':             
              for i in range(len(args)-2,-1,-1):   
                  temp =  args[i]+'('+temp+')'
              modifier = modifier + temp +',\n' 
#          print temp
    if modifier == '':
       modifier = ''
    else:
        modifier = ',\n' + modifier[:-2]          
    return modifier
       
def path2IO(keys,info,config):
    '''Generating a Modelica model modifier
        
    Parameters
    ----------
    keys : dict
        Defines the module parameters.
        
    info: dict
        Defines the module configuration.
        
    config: dict
        Defines the modifier template string.
                    
    Returns
    -------
    input_object : structured array
        Input for next time step
            
    '''   
    IO = ''
    for key in keys.keys():
       if keys[key] is not None:
          if not isinstance(keys[key],dict):
               keys[key] = ast.literal_eval(keys[key])
          path = info[key]['path']   
          fault_type = info[key]['type']
          args=path.split('.') 
          temp =''           
          if fault_type.find('output')!=-1 : 
             temp = config[fault_type]['arg'].format(keys[key]['name'],path)   
          elif (fault_type.find('input')!=-1 and fault_type.find('inputs')==-1): 
             temp = config[fault_type]['arg'].format(keys[key]['name'],keys[key]['name'])  
          elif fault_type.find('inputs')!=-1: 
             temp = config[fault_type]['arg'].format(keys[key]['name'],keys[key]['num'],keys[key]['name'],keys[key]['num'])          
          if temp != '':              
               IO = IO + temp +'\n'        
    return IO    
   
class TestCase(object):
    '''
       Class that implements the test case.   
    '''
    
    def __init__(self,con):
        '''Constructor.
        
        '''
        # Preparing the inputs for generating the model
        self.con = con
        with open(con['config']) as f: 
             data = f.read() 
        self.config = json.loads(data) 
        with open(con['model_info']) as f: 
             data = f.read()         
        self.info = json.loads(data)       
   
                
        if 'scenario' in con:
            self.scenario = self.con['scenario']
        else:
            self.ios = {} 
            for key in self.info:
                if self.info[key]['type'] == 'output' or self.info[key]['type'] == 'input':
                    self.ios[key]={'name': key}
                elif self.info[key]['type'] == 'inputs':
                    self.ios[key]={'name': key,'num':self.info[key]['dimension']}
            self.scenario = self.ios                       
        self.model_class = self.con['model_class']            
        self.model_template = templateEnv.get_template(con['model_template'])        
        modifer = path2modifer(self.scenario,self.info,self.config)        
        with open('./inner1','w') as f: 
                f.write(modifer) 
                    
        IO = path2IO(self.ios,self.info,self.config)                    
        with open('./inner2','w') as f: 
                f.write(IO)                 
                
        output = self.model_template.render(inner1='inner1',inner2='inner2')       
        with open('./fmu/test.mo','w') as f: 
                 f.write(output) 
                 
        modelpath=self.model_class
        mopath=['./fmu/test.mo']
        compile_fmu(modelpath, 
                mopath,
                compiler_log_level='error',
                # compiler_options={"state_initial_equations":True},
                target='me',
                version='2.0',
                jvm_args='-Xmx5g')
                        
        # Define simulation model
        self.fmupath = '{}.fmu'.format(self.model_class)
        # Load fmu
        self.fmu = load_fmu(self.fmupath)
        eplus_path = self.con['eplus'] 
        self.eplus = load_fmu(eplus_path)       
        self.eplus_inputs = self.eplus.get_model_variables(causality = 0)     
        self.eplus_outputs = self.eplus.get_model_variables(causality = 1)
        self.eplus_inputdict=self.con['outputs']
        self.eplus_outputdict=self.con['inputs']        
        self.init_time = eval(self.con['start_time'])       
        self.start_time = self.init_time       
        self.end_time = eval(self.con['end_time'])                
        self.step = float(con['step'])
        self.eplus.instantiate_slave('eplus_base')        
        self.eplus.initialize(tStart=self.start_time,tStop=self.end_time) 
        self.eplus.do_step(current_t=self.start_time, step_size=60)
        self.eplus_currentt = self.start_time + 60        
        self.default_input_values = None
        if 'default_input' in con:
             self.default_input_values = con['default_input']
        self.fmu.set_log_level(7)
        # Get version and check is 2.0
        self.fmu_version = self.fmu.get_version()
        if self.fmu_version != '2.0':
            raise ValueError('FMU must be version 2.0.')
        # Get available control inputs and outputs
        self.input_names = self.fmu.get_model_variables(causality = 2).keys()
        self.output_names = self.fmu.get_model_variables(causality = 3).keys()
        # Set default communication step
        self.set_step(con['step'])
        # Set default fmu simulation options
        self.options = self.fmu.simulate_options()
        self.options['CVode_options']['rtol'] = 1e-6
        # Set initial fmu simulation start
        self.initialize_fmu = True
        self.options['initialize'] = self.initialize_fmu
        # Initialize simulation data arrays
        self.__initilize_data()

    def __initilize_data(self):
        '''Initializes objects for simulation data storage.
        
        Uses self.output_names and self.input_names to create
        self.y, self.y_store, self.u, and self.u_store.
        
        Parameters
        ----------
        None
        
        Returns
        -------
        None
        
        '''
    
        # Outputs data
        self.y = {'time':[]}
        for key in self.output_names:
            self.y[key] = []
        self.y_store = copy.deepcopy(self.y)
        # Inputs data
        self.u = {'time':[]}
        for key in self.input_names:
            self.u[key] = []        
        self.u_store = copy.deepcopy(self.u)
                
    def __simulation(self,start_time,end_time,input_object=None):
        '''Simulates the FMU using the pyfmi fmu.simulate function.
        
        Parameters
        ----------
        start_time: int
            Start time of simulation in seconds.
        final_time: int
            Final time of simulation in seconds.
        input_object: pyfmi input_object, optional
            Input object for simulation
            Default is None
        
        Returns
        -------
        res: pyfmi results object
            Results of the fmu simulation.
        
        '''

        # Set fmu initialization option
        self.options['initialize'] = self.initialize_fmu
        # Simulate fmu
#        try:
#             res = self.fmu.simulate(start_time = start_time, 
#                                     final_time = end_time, 
#                                     options=self.options, 
#                                     input=input_object)
#        except Exception as e:
#            return None
        # Set internal fmu initialization
        res = self.fmu.simulate(start_time = start_time, 
                                     final_time = end_time, 
                                     options=self.options, 
                                     input=input_object)        
        self.initialize_fmu = False

        return res            

    def __get_results(self, res, store=False):
        '''Get results at the end of a simulation and throughout the 
        simulation period for storage. This method assigns these results
        to `self.y` and, if `store=True`, also to `self.y_store` and 
        to `self.u_store`. 
        This method is used by `initialize()` and `advance()` to retrieve
        results. `initialize()` does not store results whereas `advance()`
        does. 
        
        Parameters
        ----------
        res: pyfmi results object
            Results of the fmu simulation.
        store: boolean
            Set to true if desired to store results in `self.y_store` and
            `self.u_store`
        
        '''
        
        # Get result and store measurement

        for key in self.y.keys():
            self.y[key] = res[key][-1]
            if store:

                self.y_store[key].append(res[key].tolist()[1:])

        
        # Store control inputs
        if store:
            for key in self.u.keys():

                self.u_store[key].append(res[key].tolist()[1:])


    def advance(self,u):
        '''Advances the test case model simulation forward one step.
        
        Parameters
        ----------
        u : dict
            Defines the control input data to be used for the step.
            {<input_name> : <input_value>}
            
        Returns
        -------
        y : dict
            Contains the measurement data at the end of the step.
            {<measurement_name> : <measurement_value>}
            
        '''
        

            
        # Set final time
        self.final_time = self.start_time + self.step
        # Set control inputs if they exist and are written
        # Check if possible to overwrite
        # if len(u) == 0:        
            # u = self.default_input_values
        u_input = {}   
        for key in self.eplus_outputs:       
            u_input[key] = self.eplus.get(key)[0] 
        u_eplus = cosim_data(u_input,self.eplus_outputdict)            
        u.update(u_eplus)
     
        input_object = _process_input(u, self.start_time)
        # Simulate
#        print(input_object)
        res = self.__simulation(self.start_time,self.final_time,input_object) 

        # Process results
        if res is not None:        
            # Get result and store measurement and control inputs
            self.__get_results(res)
            
            if (self.final_time - self.eplus_currentt)%60 == 0:
                u_modelica = cosim_data(self.y,self.eplus_inputdict)
                print u_modelica 
                for key in u_modelica:                               
                    self.eplus.set(key, u_modelica[key])                
                for i in range(int((self.final_time - self.eplus_currentt)/60)):      
                    self.eplus.do_step(current_t=self.eplus_currentt, step_size=60)            
                    self.eplus_currentt = self.eplus_currentt + 60          
            # Advance start time
            self.start_time = self.final_time
            # Raise the flag to compute time lapse
            self.tic_time = time.time()            
            return self.y

        else:

            return None        

    def initialize(self, start_time, end_time):
        '''Initialize the test simulation.
        
        Parameters
        ----------
        start_time: int
            Start time of simulation to initialize to in seconds.
        warmup_period: int
            Length of time before start_time to simulate for warmup in seconds.
            
        Returns
        -------
        y : dict
            Contains the measurement data at the end of the initialization.
            {<measurement_name> : <measurement_value>}

        '''

        # Reset fmu
        self.fmu.reset()
        # Reset simulation data storage
        self.__initilize_data()
        # Set fmu intitialization                
        self.initialize_fmu = True
        # Simulate fmu for warmup period.
        # Do not allow negative starting time to avoid confusions
        if self.default_input_values is not None:
             input_object = _process_input(self.default_input_values,start_time)
             res = self.__simulation(start_time, end_time, input_object = input_object)        
        else:
             res = self.__simulation(start_time, start_time)
        # self.eplus.terminate()
        # self.eplus.free_instance()
        eplus_path = self.con['eplus'] 
        self.eplus = load_fmu(eplus_path)
        self.eplus.instantiate_slave('eplus_base')          
        self.eplus.initialize(tStart=start_time,tStop=end_time) 
        self.eplus.do_step(current_t=start_time, step_size=60)
        self.eplus_currentt = start_time + 60
        # Process result
        if res is not None:
            # Get result
            self.__get_results(res, store=False)
            # Set internal start time to start_time
            self.start_time = start_time

            return self.y
        
        else:

            return None
        
    def get_step(self):
        '''Returns the current simulation step in seconds.'''

        return self.step

    def set_step(self,step):
        '''Sets the simulation step in seconds.
        
        Parameters
        ----------
        step : int
            Simulation step in seconds.
            
        Returns
        -------
        None
        
        '''
        
        self.step = float(step)
        
        return None
        
    def get_inputs(self):
        '''Returns a dictionary of control inputs and their meta-data.
        
        Parameters
        ----------
        None
        
        Returns
        -------
        inputs : dict
            Dictionary of control inputs and their meta-data.
            
        '''

        inputs = self.input_names
        
        return inputs
        
    def get_measurements(self):
        '''Returns a dictionary of measurements and their meta-data.
        
        Parameters
        ----------
        None
        
        Returns
        -------
        measurements : dict
            Dictionary of measurements and their meta-data.
            
        '''

        measurements = self.output_names
        
        return measurements
        
    def get_results(self):
        '''Returns measurement and control input trajectories.
        
        Parameters
        ----------
        None
        
        Returns
        -------
        Y : dict
            Dictionary of measurement and control input names and their 
            trajectories as lists.
            {'y':{<measurement_name>:<measurement_trajectory>},
             'u':{<input_name>:<input_trajectory>}
            }
        
        '''
        
        Y = {'y':self.y_store, 'u':self.u_store}
        
        return Y
                
    def get_faults(self):
        '''Returns the name of the test case fmu.
        
        Parameters
        ----------
        None
        
        Returns
        -------
        faults : array
            List of all the possible faults.
            
        '''
        
        faults = self.info.keys()
        
        return faults

    def get_fault_info(self,fault):
        '''Returns the name of the test case fmu.
        
        Parameters
        ----------
        fault: string
            querying fault name
        
        Returns
        -------
        faults : array
            List of all the possible faults.
            
        '''       
        fault_info = {}        
        if fault in self.info:                    
            fault_info = self.info[fault]                          
        return fault_info

    def get_scenario(self):
        '''Returns the name of the test case fmu.
        
        Parameters
        ----------
        None
        
        Returns
        -------
        scenario : dict
            Dict that describes the current fault condition.
            
        ''' 
        dict = {}
        for key in self.scenario.keys():
            if self.scenario[key]:
                 dict[key] = self.scenario[key]
        
        return dict           

    def set_scenario(self,scenario):
        '''Returns the name of the test case fmu.
        
        Parameters
        ----------
        scenario : dict
            Dict that describes the current fault condition.
        
        Returns
        -------
        None
            
        '''        
        self.con['scenario'] = scenario        
        self.__init__(self.con)
        return None          