#!/bin/bash
cd $LOGSPATH 
rm -f current 2>&1 >/dev/null
ln -s $DOCKERID current

cd /app
cp /hacfg/$HASVC /etc/haproxy/$HASVC
if [ $? -gt 0 ]; then
	echo "Configuration file /hacfg/hapconf.cfg was not found !!!"
	exit 1
fi

/usr/local/bin/supervisord -c /etc/supervisor/supervisord.conf
