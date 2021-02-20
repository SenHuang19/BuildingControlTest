import requests
import time
import csv
import os
import pandas as pd
import json

url = 'http://127.0.0.1:5500'

# Set simulation parameters
length = 24*3600

step = 60



class DatReset:
    def __init__(self, measurements, config, clg_dmp_request=0.95,
                 clg_request1=1.67, clg_request2=2.78, default_sp=13.89, min_sp=12.22,
                 max_sp=18.33, trim=0.139, respond=0.278, max_respond=0.556,
                 ignored_requests=2):
        """
        Trim and respond DAT Reset
        """
        self.min_sp = min_sp
        self.max_sp = max_sp
        self.trim = trim
        self.respond = respond
        self.max_respond = max_respond
        self.ignored_requests = ignored_requests
        self.default_setpoint = default_sp
        self.clg_request1 = clg_request1
        self.clg_request2 = clg_request2
        self.clg_dmp_request = clg_dmp_request
        self.csp = {}
        self.zt = {}
        self.zdmp = {}
        self.zone_list = list(config.keys())
        self.validate_config(measurements, config)

    def validate_config(self, measurements, config):
        for zone, zone_info in config.items():
            for name, point in zone_info.items():
                if point not in measurements:
                    print("DAT RESET cannot be implemented check configuration mapping!")
                elif name == "temperature":
                    self.zt[zone] = point
                elif name == "cooling_setpoint":
                    self.csp[zone] = point
                elif name == "damper_position":
                    self.zdmp[zone] = point

    def check_requests(self, measurements):
        requests = 0
        for zone in self.zone_list:
            temp = 0
            zt = measurements[self.zt[zone]]
            csp = measurements[self.csp[zone]]
            zdmp = measurements[self.zdmp[zone]]
            if zdmp > self.clg_dmp_request:
                if zt - csp > self.clg_request2:
                    temp = 3
                elif zt - csp > self.clg_request1:
                    temp = 2
                requests += temp + 1
        return requests

    def reset(self, current_sp, supply_fan_status, requests):
        if not supply_fan_status:
            return self.default_setpoint

        if requests > self.ignored_requests:
            sp = current_sp - min((requests-self.ignored_requests)*self.respond, self.max_respond)
        else:
            sp = current_sp + self.trim
        return min(self.max_sp, max(sp, self.min_sp))

#measurements = ["TZon[1]", "TZon[2]", "TZon[3]", "TZon[4]", "TZon[5]", "TZon[6]", "TZon[7]", "TZon[8]", "TZon[9]", "TZon[10]", "TZon[11]", "TZon[12]", "TZon[13]", "TZon[14]", "TZon[15]", "floor1_ahu_coil_val_pos", "floor1_ahu_dis_T", "floor1_ahu_dis_mflow", "floor1_ahu_fre_damper_pos", "floor1_ahu_fre_mflow", "floor1_ahu_mix_T", "floor1_ahu_return_fan_power", "floor1_ahu_supply_fan_power", "floor1_valve_pos", "floor1_vav1_cooling_set", "floor1_vav1_damper_pos", "floor1_vav1_dis_T", "floor1_vav1_dis_mflow", "floor1_vav1_heating_set", "floor1_vav1_rehea_val_pos", "floor1_vav2_cooling_set", "floor1_vav2_damper_pos", "floor1_vav2_dis_T", "floor1_vav2_dis_mflow", "floor1_vav2_heating_set", "floor1_vav2_rehea_val_pos", "floor1_vav3_cooling_set", "floor1_vav3_damper_pos", "floor1_vav3_dis_T", "floor1_vav3_dis_mflow", "floor1_vav3_heating_set", "floor1_vav3_rehea_val_pos", "floor1_vav4_cooling_set", "floor1_vav4_damper_pos", "floor1_vav4_dis_T", "floor1_vav4_dis_mflow", "floor1_vav4_heating_set", "floor1_vav4_rehea_val_pos", "floor1_vav5_cooling_set", "floor1_vav5_damper_pos", "floor1_vav5_dis_T", "floor1_vav5_dis_mflow", "floor1_vav5_heating_set", "floor1_vav5_rehea_val_pos", "floor2_ahu_coil_val_pos", "floor2_ahu_dis_T", "floor2_ahu_dis_mflow", "floor2_ahu_fre_damper_pos", "floor2_ahu_fre_mflow", "floor2_ahu_mix_T", "floor2_ahu_return_fan_power", "floor2_ahu_supply_fan_power", "floor2_valve_pos", "floor2_vav1_cooling_set", "floor2_vav1_damper_pos", "floor2_vav1_dis_T", "floor2_vav1_dis_mflow", "floor2_vav1_heating_set", "floor2_vav1_rehea_val_pos", "floor2_vav2_cooling_set", "floor2_vav2_damper_pos", "floor2_vav2_dis_T", "floor2_vav2_dis_mflow", "floor2_vav2_heating_set", "floor2_vav2_rehea_val_pos", "floor2_vav3_cooling_set", "floor2_vav3_damper_pos", "floor2_vav3_dis_T", "floor2_vav3_dis_mflow", "floor2_vav3_heating_set", "floor2_vav3_rehea_val_pos", "floor2_vav4_cooling_set", "floor2_vav4_damper_pos", "floor2_vav4_dis_T", "floor2_vav4_dis_mflow", "floor2_vav4_heating_set", "floor2_vav4_rehea_val_pos", "floor2_vav5_cooling_set", "floor2_vav5_damper_pos", "floor2_vav5_dis_T", "floor2_vav5_dis_mflow", "floor2_vav5_heating_set", "floor2_vav5_rehea_val_pos", "floor3_ahu_coil_val_pos", "floor3_ahu_dis_T", "floor3_ahu_dis_mflow", "floor3_ahu_fre_damper_pos", "floor3_ahu_fre_mflow", "floor3_ahu_mix_T", "floor3_ahu_return_fan_power", "floor3_ahu_supply_fan_power", "floor3_valve_pos", "floor3_vav1_cooling_set", "floor3_vav1_damper_pos", "floor3_vav1_dis_T", "floor3_vav1_dis_mflow", "floor3_vav1_heating_set", "floor3_vav1_rehea_val_pos", "floor3_vav2_cooling_set", "floor3_vav2_damper_pos", "floor3_vav2_dis_T", "floor3_vav2_dis_mflow", "floor3_vav2_heating_set", "floor3_vav2_rehea_val_pos", "floor3_vav3_cooling_set", "floor3_vav3_damper_pos", "floor3_vav3_dis_T", "floor3_vav3_dis_mflow", "floor3_vav3_heating_set", "floor3_vav3_rehea_val_pos", "floor3_vav4_cooling_set", "floor3_vav4_damper_pos", "floor3_vav4_dis_T", "floor3_vav4_dis_mflow", "floor3_vav4_heating_set", "floor3_vav4_rehea_val_pos", "floor3_vav5_cooling_set", "floor3_vav5_damper_pos", "floor3_vav5_dis_T", "floor3_vav5_dis_mflow", "floor3_vav5_heating_set", "floor3_vav5_rehea_val_pos", "occ", "outdoor_air_temp"]
# needs mapping for AHU zone to points of interest
config1 = {
    "zone1": {
        "temperature": "TZon[1]",
        "cooling_setpoint": "floor1_vav1_cooling_set",
        "damper_position": "floor1_vav1_damper_pos"
    },
    "zone2": {
        "temperature": "TZon[2]",
        "cooling_setpoint": "floor1_vav2_cooling_set",
        "damper_position": "floor1_vav2_damper_pos"
    },
    "zone3": {
        "temperature": "TZon[3]",
        "cooling_setpoint": "floor1_vav3_cooling_set",
        "damper_position": "floor1_vav3_damper_pos"
    },
    "zone4": {
        "temperature": "TZon[4]",
        "cooling_setpoint": "floor1_vav4_cooling_set",
        "damper_position": "floor1_vav4_damper_pos"
    },
    "zone5": {
        "temperature": "TZon[5]",
        "cooling_setpoint": "floor1_vav5_cooling_set",
        "damper_position": "floor1_vav5_damper_pos"
    }
}

config2 = {
    "zone1": {
        "temperature": "TZon[6]",
        "cooling_setpoint": "floor2_vav1_cooling_set",
        "damper_position": "floor2_vav1_damper_pos"
    },
    "zone2": {
        "temperature": "TZon[7]",
        "cooling_setpoint": "floor2_vav2_cooling_set",
        "damper_position": "floor2_vav2_damper_pos"
    },
    "zone3": {
        "temperature": "TZon[8]",
        "cooling_setpoint": "floor2_vav3_cooling_set",
        "damper_position": "floor2_vav3_damper_pos"
    },
    "zone4": {
        "temperature": "TZon[9]",
        "cooling_setpoint": "floor2_vav4_cooling_set",
        "damper_position": "floor2_vav4_damper_pos"
    },
    "zone5": {
        "temperature": "TZon[10]",
        "cooling_setpoint": "floor2_vav5_cooling_set",
        "damper_position": "floor2_vav5_damper_pos"
    }
}

config3 = {
    "zone1": {
        "temperature": "TZon[11]",
        "cooling_setpoint": "floor3_vav1_cooling_set",
        "damper_position": "floor3_vav1_damper_pos"
    },
    "zone2": {
        "temperature": "TZon[12]",
        "cooling_setpoint": "floor3_vav2_cooling_set",
        "damper_position": "floor3_vav2_damper_pos"
    },
    "zone3": {
        "temperature": "TZon[13]",
        "cooling_setpoint": "floor3_vav3_cooling_set",
        "damper_position": "floor3_vav3_damper_pos"
    },
    "zone4": {
        "temperature": "TZon[14]",
        "cooling_setpoint": "floor3_vav4_cooling_set",
        "damper_position": "floor3_vav4_damper_pos"
    },
    "zone5": {
        "temperature": "TZon[15]",
        "cooling_setpoint": "floor3_vav5_cooling_set",
        "damper_position": "floor3_vav5_damper_pos"
    }
}

setpoints = pd.read_csv('setpoints1.csv')


#print setpoints['cool set-point'].iloc[1]

inputs = requests.get('{0}/inputs'.format(url)).json()

print(inputs)

measurements = requests.get('{0}/measurements'.format(url)).json()

#print(measurements)

measurements.append('time')

outFileName = "results.csv"
if os.path.exists(outFileName):
    os.remove(outFileName)
    outFile = open(outFileName, "w", newline = "")
    writer = csv.DictWriter(outFile, fieldnames = sorted(measurements))
    writer.writeheader()
else:
    outFile = open(outFileName, "w", newline = "")
    writer = csv.DictWriter(outFile, fieldnames = sorted(measurements))
    writer.writeheader()

res = requests.put('{0}/step'.format(url), data={'step':step})

y = requests.post('{0}/advance'.format(url), json=json.dumps({})).json()

#print(y)


res = requests.put('{0}/reset'.format(url), data={'start_time':200*86400,'end_time':203*86400})
#print(res)

dat_reset1 = DatReset(measurements, config1)
current_sp1 = dat_reset1.default_setpoint

dat_reset2 = DatReset(measurements, config2)
current_sp2 = dat_reset2.default_setpoint

dat_reset3 = DatReset(measurements, config3)
current_sp3 = dat_reset3.default_setpoint

for i in range(1440*3):
    data = {}
    for j in range(15):
        data['TCooSetPoi[{}]'.format(j+1)] = setpoints['T_cool_setpoint'].iloc[i] + 273.15
        data['TCooSetPoi_activate[{}]'.format(j+1)] = 1    
        data['THeaSetPoi[{}]'.format(j+1)] = setpoints['T_heat_setpoint'].iloc[i] + 273.15
        data['THeaSetPoi_activate[{}]'.format(j+1)] = 1 
    data['floor1_ahu_dis_temp_set_u'] = 273.15+current_sp1  
    data['floor1_ahu_dis_temp_set_activate'] = 1
    data['floor2_ahu_dis_temp_set_u'] = 273.15+current_sp2  
    data['floor2_ahu_dis_temp_set_activate'] = 1 
    data['floor3_ahu_dis_temp_set_u'] = 273.15+current_sp3  
    data['floor3_ahu_dis_temp_set_activate'] = 1     
    y = requests.post('{0}/advance'.format(url), json=json.dumps(data)).json()
    if i%5 ==0:
       r1 = dat_reset1.check_requests(y)
       current_sp1 = dat_reset1.reset(current_sp1, 1, r1)
       r2 = dat_reset2.check_requests(y)
       current_sp2 = dat_reset2.reset(current_sp2, 1, r2)
       r3 = dat_reset3.check_requests(y)
       current_sp3 = dat_reset3.reset(current_sp3, 1, r3)       
    
    writer.writerow(dict(sorted(y.items(), key = lambda x: x[0])))

