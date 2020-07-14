#!/bin/bash

# DOCKERID be overriden
export DOCKERID=$(awk 'BEGIN{FS="/"} /\docker\//{a[$3]++} END {for (b in a) { print substr(b,1,12)}}' /proc/1/cgroup)

# Is LOGSPATH defined ?
if [ -z "$LOGSPATH" ];
then
	echo "Variable LOGSPATH not set"
	exit 1
fi 

# Is LOGSPATH a mount-point ?
mount | grep -q -E "\s$LOGSPATH(/|\s)"
if [ $? -gt 0 ];
then
	echo "LOGSPATH $LOGSPATH is not a mount-point"
	exit 1
fi

mkdir -p $LOGSPATH/$DOCKERID/supervisor/haproxy
