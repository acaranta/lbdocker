############################################################################
# Build stage: compile HAProxy and build the Python tools in a venv.
# Nothing from this stage reaches the final image except what is COPY'd.
############################################################################
FROM ubuntu:26.04 AS buildstage

ENV DEBIAN_FRONTEND=noninteractive
# Also the image version tag: keep the master imagetag in .drone.yml in sync
ARG HAPROXY_BRANCH=v3.4.0

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
        ca-certificates gcc git libc6-dev libcrypt-dev liblua5.3-dev libpcre2-dev \
        libssl-dev libsystemd-dev make zlib1g-dev python3

# Fetch and build haproxy from github, compile it with prometheus exporter
RUN git clone --branch "$HAPROXY_BRANCH" --depth 1 https://github.com/haproxy/haproxy.git /tmp/haproxy && \
    cd /tmp/haproxy && \
    make -j"$(nproc)" TARGET=linux-glibc USE_LUA=1 USE_OPENSSL=1 USE_PCRE2=1 USE_PCRE2_JIT=1 USE_ZLIB=1 \
        USE_SYSTEMD=1 USE_PROMEX=1 EXTRA_OBJS="addons/promex/service-prometheus.o" && \
    make install-bin && \
    strip /usr/local/sbin/haproxy && \
    # Same error pages the Ubuntu haproxy package ships in /etc/haproxy/errors
    mkdir -p /out/errors && cp examples/errorfiles/*.http /out/errors/

# Self-contained venv built with uv (much faster than pip, and the venv holds no pip).
# It is built on the system python3: same base image in both stages, so the venv's
# /usr/bin/python3 matches at runtime (never let uv download its own interpreter).
COPY --from=ghcr.io/astral-sh/uv:0.13.8 /uv /usr/local/bin/uv
ENV UV_PYTHON_DOWNLOADS=never UV_NO_CACHE=1
RUN uv venv --python /usr/bin/python3 /opt/venv && \
    uv pip install --python /opt/venv envtpl supervisor supervisor-logging

############################################################################
# Runtime stage: only the runtime libraries and tools.
############################################################################
FROM ubuntu:26.04

LABEL maintainer="arthur@caranta.com"
ENV DEBIAN_FRONTEND=noninteractive
ENV INITRD=No
ENV PATH=/opt/venv/bin:$PATH
ENV TPLFILES=/etc/supervisor/supervisord.conf
ENV HASVC=hapconf.cfg
ENV SYSLOG_SERVER=127.0.0.1
ENV SYSLOG_PORT=514
ENV SYSLOG_PROTO=udp
ENV LOG_TO_DISK=true

# - liblua5.3-0, libssl3t64: HAProxy runtime libs not in the base image (pcre2, zlib,
#   libsystemd0 and libcrypt1 already are; "haproxy -vv" below fails the build if one is missing)
# - procps (pgrep), inotify-tools, rsync: used by inotifreload.sh
# - lua-*: Lua modules available to lua-load'ed scripts (lua-json is required by haproxy-lua-http)
# - haproxy user/group and directories: what the Ubuntu haproxy package used to provide
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
        ca-certificates curl inotify-tools liblua5.3-0 libssl3t64 lua-http lua-json lua-socket \
        procps python3 rsync && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/* /var/log/apt/* /var/log/dpkg.log && \
    groupadd --system haproxy && \
    useradd --system --gid haproxy --home-dir /var/lib/haproxy --no-create-home \
        --shell /usr/sbin/nologin haproxy && \
    mkdir -p /etc/haproxy /var/lib/haproxy /run/haproxy /etc/supervisor

COPY --from=buildstage /usr/local/sbin/haproxy /usr/sbin/haproxy
COPY --from=buildstage /out/errors /etc/haproxy/errors
COPY --from=buildstage /opt/venv /opt/venv
# run.sh starts supervisord from this absolute path
RUN ln -s /opt/venv/bin/supervisord /usr/local/bin/supervisord && \
    haproxy -vv >/dev/null

VOLUME ["/hacfg"]

COPY . /app
WORKDIR /app

COPY supervisord.conf.tpl /etc/supervisor/supervisord.conf.tpl
COPY dir-prereqs.sh /dir-prereqs.sh
COPY haproxy.cfg /etc/haproxy/haproxy.cfg
#Source : https://raw.githubusercontent.com/haproxytech/haproxy-lua-http/master/http.lua
COPY lua/haproxy-lua-http.lua /usr/share/lua/5.3/haproxy-lua-http.lua
#Source : https://raw.githubusercontent.com/TimWolla/haproxy-auth-request/master/auth-request.lua
COPY lua/auth-request.lua /etc/haproxy/auth-request.lua

EXPOSE 80

CMD . ./dir-prereqs.sh && for FILE in $TPLFILES; do envtpl --keep-template --allow-missing $FILE.tpl; done && ./run.sh
