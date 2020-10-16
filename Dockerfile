FROM ubuntu:18.04

MAINTAINER arthur@caranta.com
ENV DEBIAN_FRONTEND noninteractive
ENV INITRD No

RUN apt-get update -y
RUN apt-get install --force-yes -y haproxy inotify-tools python-pip curl lua-socket lua-json lua-http && \
    pip install envtpl supervisor supervisor-logging && \
    apt-get -y remove build-essential ".*-dev" && \
    apt-get -y autoremove

ADD . /app
WORKDIR /app

RUN mkdir -p /etc/supervisor && cp /app/supervisord.conf.tpl /etc/supervisor/supervisord.conf.tpl
RUN cp /app/dir-prereqs.sh /dir-prereqs.sh
RUN cp /app/haproxy.cfg /etc/haproxy
#Source : https://raw.githubusercontent.com/haproxytech/haproxy-lua-http/master/http.lua 
RUN cp /app/lua/haproxy-lua-http.lua /usr/share/lua/5.3/haproxy-lua-http.lua
#Source : https://raw.githubusercontent.com/TimWolla/haproxy-auth-request/master/auth-request.lua
RUN cp /app/lua/auth-request.lua /etc/haproxy/auth-request.lua

ENV TPLFILES /etc/supervisor/supervisord.conf
ENV HASVC hapconf.cfg
ENV SYSLOG_SERVER 127.0.0.1
ENV SYSLOG_PORT 514
ENV SYSLOG_PROTO udp

VOLUME ["/hacfg"]

EXPOSE 80

CMD . ./dir-prereqs.sh && for FILE in $TPLFILES; do envtpl --keep-template --allow-missing $FILE.tpl; done && ./run.sh
