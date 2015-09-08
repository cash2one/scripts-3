#!/usr/local/python27/bin/python
# -*- coding: utf-8 -*-
# Author: junyan.yang
# Date:   2015/09/07

import ConfigParser
import time
import MySQLdb
import smtplib
import mimetypes
from email.MIMEText import MIMEText
from email.MIMEMultipart import MIMEMultipart


# init env

yesterday=time.strftime('%Y-%m-%d',time.localtime(time.time()-60*60*24))
today=time.strftime('%Y-%m-%d',time.localtime(time.time()))

channelJihuo = {} 
channelDianji = {}

# smtp info

messagePre="""
<style type="text/css">
table-layout:fixed; 
empty-cells:show; 
border-collapse: collapse; 
margin:0 auto; 
} 
td{ 
height:30px; 
} 
h1,h2,h3{ 
	font-size:12px; 
margin:0; 
padding:0; 
} 
.table{ 
border:1px solid #cad9ea; 
color:#666; 
} 
.table th { 
	background-repeat:repeat-x; 
height:30px; 
} 
.table td,.table th{ 
border:1px solid #cad9ea; 
padding:0 1em 0; 
} 
.table tr.alter{ 
	background-color:#f5fafe; 
} 
</style>
<table class="table">
<th colspan=3>NOVO %s</th>
<tr><td>渠道</td><td>激活量</td><td>点击量</td></tr>
""" % yesterday

messagePost="""
</table>
"""
messageText = ""
receivers = ["yjy_cn21@163.com"]
#receivers = ["yjy_cn21@163.com", "ycc_bj@163.com", "kfalpawx@163.com", "510540892@qq.com"]

# read db configure

cf = ConfigParser.ConfigParser()
cf.read("/data/scripts/novo_db.conf")
db_host=cf.get("novo_slave", "host")
db_user=cf.get("novo_slave", "user")
db_pass=cf.get("novo_slave", "pass")




# get DATA from DB
try:
	db = MySQLdb.connect(db_host,db_user,db_pass, "db_novo_ad")
	cursor = db.cursor()
except:
	print "Unable to connect to DB"
#激活量
jihuo_sql="""select channel_id,count(id) 
             from player_device 
	     where create_time >= unix_timestamp('%s') and create_time < unix_timestamp('%s') group by channel_id
          """ % (yesterday, today)

try:
	cursor.execute(jihuo_sql)
	results = cursor.fetchall()
	for row in results:
		channel = row[0]
		jihuo_sum = int(row[1])
		channelJihuo[channel] = jihuo_sum
except MySQLdb.Error, e:
	print "Error: unable to fetch data. (%s)"  % e


#点击量
dianji_sql="""select channel_id,count(id) 
              from device_info 
              where create_time >= unix_timestamp('%s') and create_time < unix_timestamp('%s') group by channel_id
           """ % (yesterday, today)

try:
        cursor.execute(dianji_sql)
	results = cursor.fetchall()
	for row in results:
		channel = row[0]
	        dianji_sum = int(row[1])
		channelDianji[channel] = dianji_sum
except MySQLdb.Error, e:
        print "Error: unable to fetch data. (%s)"  % e                                                                                


for c in channelJihuo:
	messageText="<tr><td>%s</td><td>%s</td><td>%s</td></tr>" % ( c, channelJihuo[c], channelDianji[c])

# send mail
message = messagePre + messageText + messagePost
subject = "NOVO 渠道激活每日统计"

def sendmail(receivers, subject, message):
	msgRoot = MIMEMultipart('related')
	msgRoot['Subject'] = subject
	msgRoot['To'] = receivers 

	msgAlternative = MIMEMultipart('alternative')
	msgRoot.attach(msgAlternative)

	#设定HTML信息
	msgText = MIMEText(message, 'html', 'utf-8')
	msgAlternative.attach(msgText)

        smtp = smtplib.SMTP()
	smtp.set_debuglevel(1)
	smtp.connect('localhost')
	smtp.sendmail("novo@novocn.com",receivers,msgRoot.as_string())
	smtp.quit()
	return

for receiver in receivers:
	print receiver
	sendmail(receiver, subject, message)
