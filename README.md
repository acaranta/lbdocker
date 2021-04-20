# LB Docker : HaProxy on inotify

This project is a Load Balancer for your docker containers using HaProxy.
It uses an inotify loop to watch over it's configuration file and reload itself whenever it changes. This container will also check the /hacfg/certs directory for changes (usefull when using certbot like auto updating certificates)

## docker-compose usage :
```
services:
  lb:
    image: acaranta/lbdocker:latest
    environment:
      - LBID=mydockerlb
      - LOGSPATH=/lblogs
      - HASVC=lbdkr.conf
      - SYSLOG_SERVER=192.168.0.12
      - SYSLOG_PORT=514
      - SYSLOG_PROTO=udp
    ports:
      - 80:80
      - 443:443
    volumes:
       - /pathtovolumes/lbdkr/conf:/hacfg
       - /pathtovolumes/lbdkr/log:/lblogs
    restart: always
```

Environment vars :
* `LBID` : ID of you load balancer
* `LOGSPATH` : Path (in the container) where logs will be output
* `HASVC` : Name your service configuration file which will be located in `/hacfg` within the container
* `SYSLOG_SERVER` : (Optional) Syslog server address to send logs to
* `SYSLOG_PORT` : (Optional) Syslog server port
* `SYSLOG_PROTO` : (Optional) Syslog server protocol (udp/tcp)

NB : `/hacfg` volume is a good place to store your other files such as certificates and such

## Service configuration example :
Service configuration can contain most of the configuration options for an haproxy configuration, except for the `[global]` section.
For instance :
```
#########################
#          Auth         #
#########################

userlist AuthUsers
  user useradmin insecure-password S3cureP4ss!


#########################
# Frontends definitions #
#########################

frontend front_LB
	bind :::80 v4v6
	mode http
	option httplog
	option dontlognull
	option forwardfor

       # SSL Redirections
       redirect scheme https code 301 if { hdr(Host) -i importantweb.example.com } !{ ssl_fc }
	   
       # Insecure sites
       use_backend back_webassets if { hdr_beg(host) -i assets.example.com }

       #Default
       default_backend back_default

frontend front_HTTPS
	bind :::443 ssl crt /hacfg/certs/wildcard.example.com.crt ssl crt /hacfg/certs/importantweb.exemple.com.crt accept-proxy v4v6
	mode http
	option dontlognull
	option forwardfor

	log-format "%ci:%cp\ [%Tl]\ %ft\ %b/%s\ %[ssl_fc_sni]\ %ST\ %B\ %CC\ %CS\ %tsc\ %sq/%bq\ %hr\ %hs\ %{+Q}r"
	
	use_backend back_importantweb  if { ssl_fc_sni importantweb.example.com }
	
    default_backend back_default
	
#######################
# Backend Definitions #
#######################

backend back_default
        mode http
        server srv_default mainsrv.mylan.net:80 maxconn 40 check inter 10s fall 4 rise 2 

backend back_importantweb
        mode http
		# Add basic authentication
        acl AuthUsers_ACL http_auth(AuthUsers)
        server srv_importantweb secureserver.mylan.net:82 maxconn 40 check inter 10s fall 4 rise 2

backend back_webassets
        mode http
        server srv_webassets mysrvaddress:8080 maxconn 40 check inter 10s fall 4 rise 2

```
