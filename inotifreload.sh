#!/bin/bash

#Launch haproxy at startup
haproxy -f /etc/haproxy/haproxy.cfg -f /etc/haproxy/$HASVC -D -p /run/haproxy.pid

# watch for changes in /mnt and update nginx if there is one on /mnt/proxy
echo "$(date) - Starting inotify loop"
while true; do 
    RELOAD=0
    #Check if haproxy is still running
    if ! kill -0 $(cat /run/haproxy.pid) ; then
	haproxy -f /etc/haproxy/haproxy.cfg -f /etc/haproxy/$HASVC -D -p /run/haproxy.pid
    fi
    #start an inotifywait (timeout -s <#> seconds)
    # inotifywait -t 10 -q -e close_write,moved_to,create /hacfg/$HASVC 2>&1 >/dev/null
    if [ -d /hacfg/certs ];  then
        inotifywait -t 10 -q -e close_write,moved_to,create -r /hacfg/$HASVC /hacfg/certs 2>&1 >/dev/null
    else
        inotifywait -t 10 -q -e close_write,moved_to,create /hacfg/$HASVC 2>&1 >/dev/null
    fi

    #If the config did not really change don't do anything
    diff /hacfg/$HASVC /etc/haproxy/$HASVC 2>&1 >/dev/null
    if [ $? -gt 0 ]; then
	    echo "$(date) - Found changes in $HASVC file..."
	    #if it changed, then copy it and set for reload
        cp -f /hacfg/$HASVC /etc/haproxy/$HASVC
        RELOAD=1
    fi
    
    #If the certificate store did not really change don't do anything
    if [ -d /hacfg/certs ];  then
        #Check if initial sync is needed
        if [ ! -d /etc/haproxy/certs ]; then
	        rsync -ad /hacfg/certs /etc/haproxy  --delete 
        fi

        #Check for difference
        diff /hacfg/certs /etc/haproxy/certs 2>&1 >/dev/null
        if [ $? -gt 0 ]; then
            echo "$(date) - Found changes in /hacfg/certs directory ..."
            #if it changed, then copy it and set for reload
	        rsync -ad /hacfg/certs /etc/haproxy  --delete 
            RELOAD=1
        fi
    fi

    # If Reload is needed, do it
    if [ $RELOAD -gt 0 ]; then
        echo "$(date) - Found changes... gracefully reloading HAProxy"
        #reload properly haproxy
        echo "### Reloading PID $(cat /run/haproxy.pid)"
        haproxy -f /etc/haproxy/haproxy.cfg -f /etc/haproxy/$HASVC -D -p /run/haproxy.pid -sf $(cat /run/haproxy.pid)
    fi

done
