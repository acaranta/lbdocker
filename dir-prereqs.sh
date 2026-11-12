#!/bin/bash

# DOCKERID be overriden
export DOCKERID=$(awk 'BEGIN{FS="/"} /\docker\//{a[$3]++} END {for (b in a) { print substr(b,1,12)}}' /proc/1/cgroup)
if [ -z "$DOCKERID" ]; then
	export DOCKERID=$(cat /etc/hostname)
fi

# Logs always go to the container stdout; LOG_TO_DISK (default true) also
# writes them under $LOGSPATH/$DOCKERID. Normalised here to "true"/"false" so
# the supervisord template and the scripts only test one value.
# POSIX only: this file is sourced by /bin/sh (dash) from the Dockerfile CMD.
case "$LOG_TO_DISK" in
	[Ff][Aa][Ll][Ss][Ee]|0|[Nn][Oo]|[Oo][Ff][Ff]) export LOG_TO_DISK=false ;;
	*) export LOG_TO_DISK=true ;;
esac

if [ "$LOG_TO_DISK" = "true" ];
then
	# Is LOGSPATH defined ?
	if [ -z "$LOGSPATH" ];
	then
		echo "Variable LOGSPATH not set (set LOG_TO_DISK=false to log to stdout only)"
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
fi
