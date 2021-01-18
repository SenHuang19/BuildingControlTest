import requests
import time
import csv
import os

url = 'http://127.0.0.1:5500'

# Set simulation parameters
length = 24*3600

step = 600

inputs = requests.get('{0}/inputs'.format(url)).json()

print(inputs)

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

y = requests.post('{0}/advance'.format(url), data={}).json()

print(y)


res = requests.put('{0}/reset'.format(url), data={'start_time':200*86400,'end_time':201*86400})
print(res)


for i in range(144):
   
    y = requests.post('{0}/advance'.format(url), data={}).json()
    
    print(y)
    
    writer.writerow(dict(sorted(y.items(), key = lambda x: x[0])))

