import requests
import json

start_day = 33
run_period = 86400

url_eplus    = 'http://127.0.0.1:5500'
url_modelica = 'http://127.0.0.1:5000'

# Set the step
requests.put('{}/step'.format(url_eplus), data={'step': 60})

# Set the simulation start and end times in units of seconds
start_sec = start_day*86400
end_sec_run = start_sec + run_period  # end time of the run
end_day = (end_sec_run // 86400) + 1  # need the end time to be an integer day for eplus to be happy
end_sec = end_day*86400
inputs = requests.get('{0}/inputs'.format(url_eplus)).json()
default = {}

default['floor1_ahu_dis'] = {'variable':'floor1_ahu_dis_input'}
 
res = requests.put('{0}/fault_scenario'.format(url_modelica), json=default)

inputs = requests.get('{0}/inputs'.format(url_eplus)).json()

y = requests.post('{0}/advance'.format(url_eplus), data=json.dumps({})).json()

requests.put('{}/reset'.format(url_eplus), data={'start_time':start_sec, 'end_time':end_sec})

print(y['floor1_dis_T_set'])
print(y['floor1_pressure_set'])
print(y['floor1_mix_T_set'])

y = requests.post('{0}/advance'.format(url_eplus), data=json.dumps({'floor1_ahu_dis_temp_set_u':287.0367,'floor1_ahu_dis_temp_set_activate':1,'floor1_ahu_mix_temp_set_u':289.5483,'floor1_ahu_mix_temp_set_activate':1,'floor1_ahu_dis_pre_set_u':433.31,'floor1_ahu_dis_pre_set_activate':1})).json()

print(y['floor1_dis_T_set'])
print(y['floor1_pressure_set'])
print(y['floor1_mix_T_set'])