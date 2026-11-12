#!/bin/bash
if [ "$LOG_TO_DISK" = "true" ]; then
	cd "$LOGSPATH" || exit 1
	rm -f current >/dev/null 2>&1
	ln -s $DOCKERID current
fi

cd /app
cp /hacfg/$HASVC /etc/haproxy/$HASVC
if [ $? -gt 0 ]; then
	echo "Configuration file /hacfg/hapconf.cfg was not found !!!"
	exit 1
fi

/usr/local/bin/supervisord -c /etc/supervisor/supervisord.conf
