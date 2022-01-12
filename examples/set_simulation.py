import requests

url = 'http://127.0.0.1:5001'


####################### setting the fault scenario ###############################################

#fault_scenario = requests.get('{0}/fault_scenario'.format(url)).json()

#default = fault_scenario

default = {}

default['floor1_ahu_dis'] = {'variable':'floor1_ahu_dis_input'}
 
res = requests.put('{0}/fault_scenario'.format(url), json=default)

print(res)

fault_scenario = requests.get('{0}/fault_scenario'.format(url)).json()

#inputs = requests.get('{0}/inputs'.format(url)).json()

#print(fault_scenario['floor1_ahu_dis'])
inputs = requests.get('{0}/inputs'.format(url)).json()

print(inputs)

measurements = requests.get('{0}/measurements'.format(url)).json()

print(measurements)

####################### setting the simulation ###############################################

# step = 60

# res = requests.put('{0}/step'.format(url), data={'step':step})


# res = requests.put('{0}/reset'.format(url), data={'start_time':200*86400,'end_time':200*86400})


# res = requests.post('{0}/advance'.format(url), data={'Occ':1})








