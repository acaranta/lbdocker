FROM ubuntu:26.04 AS buildstage

MAINTAINER arthur@caranta.com
ENV DEBIAN_FRONTEND noninteractive
ENV INITRD No
# Also the image version tag: keep the master imagetag in .drone.yml in sync
ENV HAPROXY_BRANCH v3.4.0
RUN apt-get update -y
# liblua5.3-0 is listed explicitly: on 26.04 nothing else depends on it, so the "*-dev" removal +
# autoremove below would take the runtime library HAProxy links against (liblua5.3.so.0).
RUN apt-get install --force-yes -y haproxy inotify-tools python3-pip curl lua-socket lua-json lua-http liblua5.3-0 rsync
# Python >= 3.12 refuses system-wide pip installs (PEP 668); this image is single-purpose.
RUN pip3 install --break-system-packages envtpl supervisor supervisor-logging

#Fetch and build haproxy from github, compile it with prometheus exporter
RUN cd /tmp && \
    apt install -y git ca-certificates gcc libc6-dev libcrypt-dev liblua5.3-dev libpcre2-dev libssl-dev libsystemd-dev make wget zlib1g-dev && \
    git clone --branch $HAPROXY_BRANCH --depth 1 https://github.com/haproxy/haproxy.git && \
    cd haproxy && \
    make TARGET=linux-glibc USE_LUA=1 USE_OPENSSL=1 USE_PCRE2=1 USE_PCRE2_JIT=1 USE_ZLIB=1 USE_SYSTEMD=1 USE_PROMEX=1 EXTRA_OBJS="addons/promex/service-prometheus.o" && \
    make install-bin && \
    cp /usr/local/sbin/haproxy /usr/sbin/haproxy && \
    cd / && rm -rf /tmp/haproxy

RUN apt-get -y remove build-essential ".*-dev" git gcc make && \
    apt-get -y autoremove && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/*

#Multistage build
FROM scratch

COPY --from=buildstage / /

MAINTAINER arthur@caranta.com
ENV DEBIAN_FRONTEND noninteractive
ENV INITRD No
ENV TPLFILES /etc/supervisor/supervisord.conf
ENV HASVC hapconf.cfg
ENV SYSLOG_SERVER 127.0.0.1
ENV SYSLOG_PORT 514
ENV SYSLOG_PROTO udp
ENV LOG_TO_DISK true

VOLUME ["/hacfg"]

ADD . /app
WORKDIR /app

RUN mkdir -p /etc/supervisor && cp /app/supervisord.conf.tpl /etc/supervisor/supervisord.conf.tpl
RUN cp /app/dir-prereqs.sh /dir-prereqs.sh
RUN cp /app/haproxy.cfg /etc/haproxy
#Source : https://raw.githubusercontent.com/haproxytech/haproxy-lua-http/master/http.lua 
RUN cp /app/lua/haproxy-lua-http.lua /usr/share/lua/5.3/haproxy-lua-http.lua
#Source : https://raw.githubusercontent.com/TimWolla/haproxy-auth-request/master/auth-request.lua
RUN cp /app/lua/auth-request.lua /etc/haproxy/auth-request.lua

EXPOSE 80

CMD . ./dir-prereqs.sh && for FILE in $TPLFILES; do envtpl --keep-template --allow-missing $FILE.tpl; done && ./run.sh
