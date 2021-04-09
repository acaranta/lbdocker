FROM ubuntu:18.04 AS buildstage

MAINTAINER arthur@caranta.com
ENV DEBIAN_FRONTEND noninteractive
ENV INITRD No

RUN apt-get update -y
RUN apt-get install --force-yes -y haproxy inotify-tools python-pip curl lua-socket lua-json lua-http && \
    pip install envtpl supervisor supervisor-logging

#Fetch and build haproxy from github, compile it with prometheus exporter
RUN cd /tmp && \
    apt install -y git ca-certificates gcc libc6-dev liblua5.3-dev libpcre3-dev libssl-dev libsystemd-dev make wget zlib1g-dev && \
    git clone https://github.com/haproxy/haproxy.git && \
    cd haproxy && \
    make TARGET=linux-glibc USE_LUA=1 USE_OPENSSL=1 USE_PCRE=1 USE_ZLIB=1 USE_SYSTEMD=1 EXTRA_OBJS="addons/promex/service-prometheus.o" && \
    make install-bin && \
    cp /usr/local/sbin/haproxy /usr/sbin/haproxy && \
    cd / && rm -rf /tmp/haproxy

RUN apt-get -y remove build-essential ".*-dev" git gcc make && \
    apt-get -y autoremove && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/*

ADD . /app
WORKDIR /app

RUN mkdir -p /etc/supervisor && cp /app/supervisord.conf.tpl /etc/supervisor/supervisord.conf.tpl
RUN cp /app/dir-prereqs.sh /dir-prereqs.sh
RUN cp /app/haproxy.cfg /etc/haproxy
#Source : https://raw.githubusercontent.com/haproxytech/haproxy-lua-http/master/http.lua 
RUN cp /app/lua/haproxy-lua-http.lua /usr/share/lua/5.3/haproxy-lua-http.lua
#Source : https://raw.githubusercontent.com/TimWolla/haproxy-auth-request/master/auth-request.lua
RUN cp /app/lua/auth-request.lua /etc/haproxy/auth-request.lua

#Multistage build
FROM scratch

COPY --from=buildstage / /

WORKDIR /app

MAINTAINER arthur@caranta.com
ENV DEBIAN_FRONTEND noninteractive
ENV INITRD No
ENV TPLFILES /etc/supervisor/supervisord.conf
ENV HASVC hapconf.cfg
ENV SYSLOG_SERVER 127.0.0.1
ENV SYSLOG_PORT 514
ENV SYSLOG_PROTO udp

VOLUME ["/hacfg"]

EXPOSE 80

CMD . ./dir-prereqs.sh && for FILE in $TPLFILES; do envtpl --keep-template --allow-missing $FILE.tpl; done && ./run.sh
