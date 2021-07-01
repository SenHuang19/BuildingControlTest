import requests
import time
import csv
import os

url = 'http://127.0.0.1:5001'

# Set simulation parameters
length = 24*3600

step = 60

inputs = requests.get('{0}/inputs'.format(url)).json()

#print(inputs)

measurements = requests.get('{0}/measurements'.format(url)).json()

print(measurements)

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

#y = requests.post('{0}/advance'.format(url), data={'TSet_u[1]':280.15,'TSet_activate[1]':1}).json()

#print(y)

y = requests.post('{0}/advance'.format(url), data={}).json()

res = requests.put('{0}/reset'.format(url), data={'start_time':190*86400,'end_time':191*86400})

#y = requests.post('{0}/advance'.format(url), data={'TSet_u[1]':280.15,'TSet_activate[1]':1}).json()

for i in range(1440):
   
    y = requests.post('{0}/advance'.format(url), data={}).json()
    
    writer.writerow(dict(sorted(y.items(), key = lambda x: x[0])))


