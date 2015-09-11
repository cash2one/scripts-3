#!/bin/sh
# Author: junyanyang
# Date : 2015/1/22

# init environment 
source /etc/profile

workdir="/data/apps/nginx/html/novo/server/command"
PHP="/data/apps/php/bin/php"
test -d /data/logs || mkdir /data/logs
args=$@

if [ -z "$args" ];then
	echo "Usage:$0 scriptname [para1] [para2] ......"
	exit 1
fi


function exe_script()
{
	paras=$@
	echo $paras
	filename=$1
	para1=$2
        echo $para1  
	if [ -z "${para1}" ]
	then
		SCRIPT_PID="/var/run/${filename%%.*}.pid"
		output_logfile="/data/logs/${filename%%.*}.log"
	else 
		SCRIPT_PID="/var/run/${filename%%.*}_${para1}.pid"
		output_logfile="/data/logs/${filename%%.*}_${para1}.log"
	fi

	if [ -f $SCRIPT_PID ]; then
  		PID=`cat $SCRIPT_PID `
  		if (ps -e | awk '{print $1}' | grep $PID >/dev/null); then
   	 		exit
  		fi
	fi

	echo $$ > $SCRIPT_PID

	type=${filename##*.}
	
        case $type in
	php)
		$PHP ${workdir}/$paras >> ${output_logfile}
		;;
	sh)
		/bin/sh ${workdir}/$paras >> ${output_logfile}
	        ;;	
	*)
		echo "scrips only php and bash scrips!"
		exit 2
		;;
	esac

	rm $SCRIPT_PID
}

exe_script $@
