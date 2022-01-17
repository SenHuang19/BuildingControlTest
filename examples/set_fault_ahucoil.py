import requests
import json

start_day = 33
run_period = 86400

url_eplus    = f'http://127.0.0.1:5501'
url_modelica = f'http://127.0.0.1:5001'

# Set the step
requests.put(f'{url_eplus}/step', data={'step': 60})

# Set the simulation start and end times in units of seconds
start_sec = start_day*86400
end_sec_run = start_sec + run_period  # end time of the run
end_day = (end_sec_run // 86400) + 1  # need the end time to be an integer day for eplus to be happy
end_sec = end_day*86400
inputs = requests.get('{0}/inputs'.format(url_eplus)).json()
default = {}

default['floor1_coil_valve'] = {'variable':'floor1_coil_valve_input'}
 
res = requests.put('{0}/fault_scenario'.format(url_modelica), json=default)

inputs = requests.get('{0}/inputs'.format(url_eplus)).json()

y = requests.post('{0}/advance'.format(url_eplus), data=json.dumps({})).json()

requests.put(f'{url_eplus}/reset', data={'start_time':start_sec, 'end_time':end_sec})

y = requests.post('{0}/advance'.format(url_eplus), data=json.dumps({'floor1_coil_valve_input':1})).json()

print(y['floor1_ahu_coil_val_pos'])
print(y['floor1_ahu_coil_val_pos_real'])