#!/bin/bash

#Launch haproxy at startup
haproxy -f /etc/haproxy/haproxy.cfg -f /etc/haproxy/$HASVC -D -p /run/haproxy.pid

# watch for changes in /mnt and update nginx if there is one on /mnt/proxy
echo "$(date) - Starting inotify loop"
while true; do 
    #Check if haproxy is still running
    if ! kill -0 $(cat /run/haproxy.pid) ; then
	haproxy -f /etc/haproxy/haproxy.cfg -f /etc/haproxy/$HASVC -D -p /run/haproxy.pid
    fi
    #start an inotifywait (timeout -s <#> seconds)
    inotifywait -t 10 -q -e close_write,moved_to,create /hacfg/$HASVC 2>&1 >/dev/null

    #If the file did not really change don't do anything
    diff /hacfg/$HASVC /etc/haproxy/$HASVC 2>&1 >/dev/null
    if [ $? -gt 0 ]; then
	    echo "$(date) - Found changes in $HASVC file... gracefully reloading HAProxy"
	    #if it changed, then copy it and reload properly haproxy
            cp -f /hacfg/$HASVC /etc/haproxy/$HASVC
	    haproxy -f /etc/haproxy/haproxy.cfg -f /etc/haproxy/$HASVC -D -p /run/haproxy.pid -sf $(cat /run/haproxy.pid)
    fi
done
