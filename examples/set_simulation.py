import requests

url = 'http://127.0.0.1:5000'


####################### setting the fault scenario ###############################################

fault_scenario = requests.get('{0}/fault_scenario'.format(url)).json()

print(fault_scenario)

r ={'floor3_pre':{'value':1,'fault_time':0},
    'floor2_pre':{'value':1,'fault_time':0},
    'floor3_ahu_dis_T':{'name':'floor3_ahu_dis_T'},
    'floor3_ahu_dis_pre_set':{'name':'floor3_ahu_dis_pre_set'}}
     
     # ############ note that "fault_time" should be postive  ############################     
     
res = requests.put('{0}/fault_scenario'.format(url), json=r)

fault_scenario = requests.get('{0}/fault_scenario'.format(url)).json()

#print(fault_scenario)

####################### setting the simulation ###############################################

step = 60

res = requests.put('{0}/step'.format(url), data={'step':step})


res = requests.put('{0}/reset'.format(url), data={'start_time':200*86400,'end_time':200*86400})


res = requests.post('{0}/advance'.format(url), data={'Occ':1})







