#!/bin/bash

cp /hacfg/$HASVC /etc/haproxy/$HASVC
if [ $? -gt 0 ]; then
	echo "Configuration file /hacfg/hapconf.cfg was not found !!!"
	exit 1
fi

/usr/bin/supervisord -c /etc/supervisor/supervisord.conf
