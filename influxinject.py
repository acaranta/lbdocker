#!/usr/bin/python

import requests
import csv
import StringIO
import re
import json
import time
import sys
import os

import pprint
pp = pprint.PrettyPrinter(indent=4)
######## BEG PARAMS ###########
if os.environ.get('INFLUXSRV') == None:
  print "Please fill in at least INFLUXSRV (the influxDB server) environnement variable...not running injector"
  sys.exit(2)

influxuser = os.getenv('INFLUXUSER','root')
influxpass = os.getenv('INFLUXPASS','root')
influxserver = os.getenv('INFLUXSRV','127.0.0.1')
influxport = os.getenv('INFLUXPORT','8086')
influxdb = os.getenv('INFLUXDB','hastats')

hastatsport = os.getenv('HASTATSPORT','1936')
hastatsserver = os.getenv('HASTATSSRV','127.0.0.1')
hastatsuser = os.getenv('HASTATSUSER','test')
hastatspass = os.getenv('HASTATSPASS','test')

loopwait = os.getenv('REFRESHSEC',10)
######## END PARAMS ###########


params = {'u': influxuser, 'p': influxpass}
influxurl = 'http://'+influxserver+':'+influxport+'/db'
statsurl = 'http://'+hastatsuser+':'+hastatspass+'@'+hastatsserver+':'+hastatsport+'/;csv;norefesh'

print "Starting injector ... getting hastats on '" + statsurl + "' and injecting into '" +influxurl+"/"+influxdb+"' user : "+influxuser+"/pass : "+influxpass

data = {'name': influxdb}
r = requests.post(influxurl, params=params, data=json.dumps(data))
r = requests.get(influxurl, params=params, data=json.dumps(data))
if r.status_code == 200:
 print 'DB '+influxdb+' is OK ...'
else:
 print 'DB '+influxdb+' could not be created'
 sys.exit(1)


while True:
  f = requests.get(statsurl)
  
  f = re.sub(r'# ',"",f.text)
#  headers = f.split('\n',1)[0].split(',')
#  for head in headers:
#   print(head+' '),
  f = StringIO.StringIO(f)
  csv_data = csv.DictReader(f)
  
  for row in csv_data:
    data = [
      {
       'name': row['pxname']+'-'+row['svname'],
       'columns': ['stot','bytesin','bytesout', '1xx', '2xx', '3xx', '4xx', '5xx'],
       'points': [[ row['stot'], row['bin'], row['bout'],row['hrsp_1xx'], row['hrsp_2xx'], row['hrsp_3xx'], row['hrsp_4xx'], row['hrsp_5xx'] ] ]
      }
    ]
#    print(row['pxname']+'-'+row['svname']),
    r = requests.post(influxurl+'/'+influxdb+'/series', params=params, data=json.dumps(data))
    if r.status_code != 200:
      print 'Injection failed for ' + row['pxname']+'-'+row['svname'] 

#    print str(r.status_code) + json.dumps(data)
#    pp.pprint(r.content) 
  print 'Insert Loop done'
  del csv_data
  time.sleep(loopwait)
