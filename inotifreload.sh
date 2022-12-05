#!/bin/bash

#Launch haproxy at startup
haproxy -f /etc/haproxy/haproxy.cfg -f /etc/haproxy/$HASVC -D -p /run/haproxy.pid

# watch for changes in /mnt and update nginx if there is one on /mnt/proxy
echo "$(date) - Starting inotify loop"
while true; do 
    RELOAD=0
    #Check if haproxy is still running
#    if ! kill -0 $(cat /run/haproxy.pid) ; then
#	    haproxy -f /etc/haproxy/haproxy.cfg -f /etc/haproxy/$HASVC -D -p /run/haproxy.pid
#    fi
    if ! pgrep haproxy 2>&1 >/dev/null ; then
        haproxy -f /etc/haproxy/haproxy.cfg -f /etc/haproxy/$HASVC -D -p /run/haproxy.pid
    else
        pgrep haproxy >/run/haproxy.pid
    fi

    # Build NOTIFY items list
    NOTIFPATHS=("$HASVC")
    # Certs
    if [ -d /hacfg/certs ];  then
        NOTIFPATHS+=("certs")
    fi

    #maps
    if [ -d /hacfg/maps ];  then
        NOTIFPATHS+=("maps")
    fi    
    
    # Build Paths list for inotify
    HALIST=""
    for item in "${NOTIFPATHS[@]}"
    do
        HALIST=$HALIST" /hacfg/$item"
    done

    #start an inotifywait (timeout -s <#> seconds)
    #inotifywait -t 5 -q -e close_write,moved_to,create /hacfg/$HASVC 2>&1 >/dev/null
    inotifywait -t 5 -q -e close_write,moved_to,create -r $HALIST 2>&1 >/dev/null

    # Check and sync changes
    for item in "${NOTIFPATHS[@]}"
    do
    if [[ -f /hacfg/$item || -d /hacfg/$item ]];  then
            #Check if initial sync is needed
            if [ ! -d /etc/haproxy/$item ]; then
                rsync -ad /hacfg/$item /etc/haproxy  --delete 
            fi

            #Check for difference
	    echo "diff"
            diff /hacfg/$item /etc/haproxy/$item
            diff /hacfg/$item /etc/haproxy/$item 2>&1 >/dev/null
            if [ $? -gt 0 ]; then
                echo "$(date) - Found changes in /hacfg/$item ..."
                #if it changed, then copy it and set for reload
                rsync -ad /hacfg/$item /etc/haproxy  --delete 
                RELOAD=1
            fi
    fi
    done


    # #If the config did not really change don't do anything
    # diff /hacfg/$HASVC /etc/haproxy/$HASVC 2>&1 >/dev/null
    # if [ $? -gt 0 ]; then
	#     echo "$(date) - Found changes in $HASVC file..."
	#     #if it changed, then copy it and set for reload
    #     cp -f /hacfg/$HASVC /etc/haproxy/$HASVC
    #     RELOAD=1
    # fi
    
    # #If the certificate store did not really change don't do anything
    # if [ -d /hacfg/certs ];  then
    #     #Check if initial sync is needed
    #     if [ ! -d /etc/haproxy/certs ]; then
	#         rsync -ad /hacfg/certs /etc/haproxy  --delete 
    #     fi

    #     #Check for difference
    #     diff /hacfg/certs /etc/haproxy/certs 2>&1 >/dev/null
    #     if [ $? -gt 0 ]; then
    #         echo "$(date) - Found changes in /hacfg/certs directory ..."
    #         #if it changed, then copy it and set for reload
	#         rsync -ad /hacfg/certs /etc/haproxy  --delete 
    #         RELOAD=1
    #     fi
    # fi

    # If Reload is needed, do it
    if [ $RELOAD -gt 0 ]; then
        echo "$(date) - Found changes... gracefully reloading HAProxy"
        #reload properly haproxy
        echo "### Reloading PID $(cat /run/haproxy.pid)"
        haproxy -f /etc/haproxy/haproxy.cfg -f /etc/haproxy/$HASVC -D -p /run/haproxy.pid -sf $(cat /run/haproxy.pid)
    fi

done
