# -*- coding: utf-8 -*-
"""
This module is an example python-based testing interface.  It uses the
``requests`` package to make REST API calls to the test case container,
which mus already be running.  A controller is tested, which is 
imported from a different module.
  
"""
import sys
import numpy as np
import json
import importlib
from datetime import datetime, timedelta


def setup_resets(config, measurements):
    resets = []
    for name, _f in config.items():
        path = _f
        with open(path) as f:
            reset_config = json.load(f)
        print(reset_config)
        try:
            class_name = reset_config.pop("class")
            cls = factory(class_name)
            resets.append(cls(measurements, reset_config))
        except KeyError:
            print("Missing class definition for {}".format(name))
            continue
    return resets


def factory(classname):
    base_module = "examples.Resets.resets"
    module = importlib.import_module(base_module)
    cls = getattr(module, classname)
    return cls


class Reset:
    def __init__(self, config):
        self.validate_config(config)
        self.min_sp = config.pop("min_sp")
        self.max_sp = config.pop("max_sp")
        self.trim = config.pop("trim")
        self.respond = config.pop("respond")
        self.occupancy = 0
        self.direction = 1.0
        try:
            self.max_respond = config.pop("max_respond")
        except KeyError:
            self.max_respond = 2*self.respond
        self.default_setpoint = config.pop("default_sp")
        try:
            self.ignored_requests = config.pop("ignored_requests")
        except KeyError:
            self.ignored_requests = 1
        self.current_sp = float(self.default_setpoint)
        self.control = config.pop("control")
        self.activate = config.pop("activate")
        self.activate_value = 1

    def validate_config(self, config):
        config_error = False
        config_keys = list(config.keys())
        if "min_sp" not in config_keys:
            print("Missing min_sp from config!")
            config_error = True
        if "max_sp" not in config_keys:
            print("Missing max_sp from config!")
            config_error = True
        if "trim" not in config_keys:
            print("Missing trim from config!")
            config_error = True
        if "respond" not in config_keys:
            print("Missing respond from config!")
            config_error = True
        if "default_sp" not in config_keys:
            print("Missing default_setpoint from config!")
            config_error = True
        if config_error:
            sys.exit()

    def reset(self, _requests):
        if not self.occupancy:
            self.current_sp = self.default_setpoint
            return

        if _requests > self.ignored_requests:
            sp = self.current_sp - self.direction * min((_requests - self.ignored_requests) * self.respond, self.max_respond)
        else:
            sp = self.current_sp + self.direction * self.trim
        self.current_sp = min(self.max_sp, max(sp, self.min_sp))


class DatReset(Reset):
    def __init__(self, measurements, config):
        """
        Trim and respond DAT Reset
        """
        super().__init__(config)
        self.name = config.pop('name', "reset")
        try:
            oat_low = config.pop("oat_low")
        except KeyError:
            oat_low = 15.56
        try:
            oat_high = config.pop("oat_high")
        except KeyError:
            oat_high = 294.26
        try:
            self.request1 = config.pop("request1")
        except KeyError:
            self.request1 = 1.5
        try:
            self.request2 = config.pop("request2")
        except KeyError:
            self.request2 = 2.0
        try:
            self.clg_request_thr = config.pop("clg_request_thr")
        except KeyError:
            self.clg_request_thr = 0.95
        try:
            self.htg_request_thr = config.pop("htg_request_thr")
        except KeyError:
            self.htg_request_thr = 0.2
        try:
            self.oat_name = config.pop("oat_name")
        except KeyError:
            self.oat_name = 'outdoor_air_temp'
        try:
            self.occupancy_name = config.pop("occupancy_name")
        except KeyError:
            self.occupancy_name = 'occ'

        self.csp = {}
        self.hsp = {}
        self.zt = {}
        self.zclg = {}
        self.zhtg = {}
        self.zone_list = []
        self.validate(measurements, config)
        self.max_sat_bounds = np.linspace(self.max_sp, self.max_sp, 100)
        self.oat_bounds = np.linspace(oat_low, oat_high, 100)

    def validate(self, measurements, config):
        self.zone_list = list(config.keys())
        for zone, zone_info in config.items():
            for name, point in zone_info.items():
                #if point not in measurements:
                #    print("DAT RESET cannot be implemented check configuration mapping! -- {}".format(point))
                if name == "temperature":
                    self.zt[zone] = point
                elif name == "cooling_setpoint":
                    self.csp[zone] = point
                elif name == "heating_setpoint":
                    self.hsp[zone] = point
                elif name == "cooling_signal":
                    self.zclg[zone] = point
                elif name == "heating_signal":
                    self.zhtg[zone] = point

    def check_requests(self, measurements):
        clg_requests = 0
        htg_requests = 0
        temp = 0
        for zone in self.zone_list:
            temp = 0
            zt = measurements[self.zt[zone]]
            csp = measurements[self.csp[zone]]
            hsp = measurements[self.hsp[zone]]
            clg_signal = measurements[self.zclg[zone]]
            htg_signal = measurements[self.zhtg[zone]]
            print("name: {} - zone {} -- occ {} -- max_sp: {} -- zt: {} -- cps: {} -- clg: {} -- htg: {}".format(self.name, zone, self.occupancy, self.max_sp, zt, csp, clg_signal, htg_signal))
            if htg_signal < 0.05 and clg_signal > self.clg_request_thr:
                if zt - csp > self.request2:
                    temp = 3
                elif zt - csp > self.request1:
                    temp = 2
                clg_requests += temp + 1
            elif htg_signal > self.htg_request_thr:
                if hsp - zt > self.request2:
                    temp = 3
                elif hsp - zt > self.request1:
                    temp = 2
                htg_requests += temp + 1
        _requests = max(0, clg_requests - htg_requests)
        print("request: {} -- temp: {}".format(_requests, temp))
        return _requests

    def update(self, measurements):
        oat = measurements[self.oat_name]
        self.occupancy = int(measurements[self.occupancy_name])
        self.max_sp = np.interp(oat, self.oat_bounds, self.max_sat_bounds)


class ChwReset(Reset):
    def __init__(self, measurements, config):
        """
        Trim and respond DAT Reset
        """
        super().__init__(config)
        self.name = config.pop('name', "reset")
        try:
            oat_low = config.pop("oat_low")
        except KeyError:
            oat_low = 288.71
        try:
            oat_high = config.pop("oat_high")
        except KeyError:
            oat_high = 294.26
        try:
            self.request1 = config.pop("request1")
        except KeyError:
            self.request1 = 2.0
        try:
            self.request2 = config.pop("request2")
        except KeyError:
            self.request2 = 3.0
        try:
            self.clg_request_thr = config.pop("clg_request_thr")
        except KeyError:
            self.clg_request_thr = 0.95
        try:
            self.htg_request_thr = config.pop("htg_request_thr")
        except KeyError:
            self.htg_request_thr = 0.95
        try:
            self.oat_name = config.pop("oat_name")
        except KeyError:
            self.oat_name = 'outdoor_air_temp'
        try:
            self.occupancy_name = config.pop("occupancy_name")
        except KeyError:
            self.occupancy_name = 'occ'

        self.sat_sp = {}
        self.clg_signal = {}
        self.sat = {}
        self.rated_clg_flow = {}
        self.device_list = []
        self.validate(measurements, config)
        self.max_chw_bounds = np.linspace(self.max_sp, self.min_sp, 100)
        self.oat_bounds = np.linspace(oat_low, oat_high, 100)

    def validate(self, measurements, config):
        self.device_list = list(config.keys())
        for device, device_info in config.items():
            for name, point in device_info.items():
                if point not in measurements:
                    print("DAT RESET cannot be implemented check configuration mapping! -- {}".format(point))
                if name == "cooling_signal":
                    self.clg_signal[device] = point
                elif name == "supply_temperature_setpoint":
                    self.sat_sp[device] = point
                elif name == "supply_temperature":
                    self.sat[device] = point
                elif name == "rated_clg_flow":
                    self.rated_clg_flow[device] = point

    def check_requests(self, measurements, zt=None):
        clg_requests = 0
        temp = 0
        for device in self.device_list:
            temp = 0
            sat = measurements[self.sat[device]]
            sat_sp = measurements[self.sat_sp[device]]
            clg_signal = measurements[self.clg_signal[device]]
            if self.rated_clg_flow[device]:
                clg_signal = clg_signal/self.rated_clg_flow[device]
            else:
                clg_signal = 0.0
            print("name: {} - device {} -- occ {} -- max_sp: {} -- sat: {} -- sat_sp: {} -- clg: {}".format(self.name, device, self.occupancy, self.max_sp, sat, sat_sp, clg_signal))
            if clg_signal > self.clg_request_thr:
                if sat - sat_sp > self.request2:
                    temp = 3
                elif sat - sat_sp > self.request1:
                    temp = 2
                clg_requests += temp + 1
        _requests = clg_requests
        print("request: {} -- temp: {}".format(_requests, temp))
        return _requests

    def update(self, measurements):
        oat = measurements[self.oat_name]
        self.occupancy = int(measurements[self.occupancy_name])
        self.max_sp = np.interp(oat, self.oat_bounds, self.max_chw_bounds)


class StaticPressureReset(Reset):
    def __init__(self, measurements, config):
        """
        Trim and respond DAT Reset
        """
        super().__init__(config)
        self.name = config.pop('name', "reset")
        try:
            self.request1 = config.pop("request1")
        except KeyError:
            self.request1 = 0.7
        try:
            self.request2 = config.pop("request2")
        except KeyError:
            self.request2 = 0.5
        try:
            self.dmp_request_thr = config.pop("dmpr_request_thr")
        except KeyError:
            self.dmp_request_thr = 0.95
        try:
            self.occupancy_name = config.pop("occupancy_name")
        except KeyError:
            self.occupancy_name = 'occ'

        self.airflow_sp = {}
        self.airflow = {}
        self.dmpr = {}
        self.zone_list = []
        self.direction = -1.0
        self.validate(measurements, config)

    def validate(self, measurements, config):
        #self.control = config.pop('control')
        self.zone_list = list(config.keys())
        for zone, zone_info in config.items():
            for name, point in zone_info.items():
                #if point not in measurements:
                #    print("DAT RESET cannot be implemented check configuration mapping! -- {}".format(point))
                if name == "damper_command":
                    self.dmpr[zone] = point
                elif name == "airflow":
                    self.airflow[zone] = point
                elif name == "airflow_setpoint":
                    self.airflow_sp[zone] = point

    def check_requests(self, measurements):
        _requests = 0
        for zone in self.zone_list:
            temp = 0
            dmpr = measurements[self.dmpr[zone]]
            airflow = measurements[self.airflow[zone]]
            airflow_sp = measurements[self.airflow_sp[zone]]
            airflow_fraction = max(0., min(1., airflow/airflow_sp))

            print("name: {} - zone {} -- occ {} -- dmpr: {} -- airflow_fraction: {}".format(self.name, zone, self.occupancy, dmpr, airflow_fraction))
            if dmpr >= self.dmp_request_thr:
                if airflow_fraction < self.request2:
                    temp = 2
                elif airflow_fraction < self.request1:
                    temp = 1
                _requests += temp + 1
        print("request: {} -- temp: {}".format(_requests, temp))
        return _requests

    def update(self, measurements):
        self.occupancy = int(measurements[self.occupancy_name])