import requests

url = 'http://127.0.0.1:5000'

####################### getting inputs for the simulation ###############################################

inputs = requests.get('{0}/inputs'.format(url)).json()

print(inputs)

####################### getting measurements for the simulation #########################################

measurements = requests.get('{0}/measurements'.format(url)).json()

print(measurements)

####################### getting model informations (fault types, I/O) for the simulation ################

model_info = requests.get('{0}/faults'.format(url)).json()

print(model_info)

####################### getting detailed informations of a given point ##################################

model_detailed_info = requests.get('{0}/fault_info'.format(url), data={'fault':model_info[0]}).json()

print(model_detailed_info)

####################### getting the current fault scenario of a given point #############################

fault_scenario = requests.get('{0}/fault_scenario'.format(url)).json()

print(fault_scenario)




