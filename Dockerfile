FROM ubuntu:14.04

MAINTAINER arthur@caranta.com
ENV DEBIAN_FRONTEND noninteractive
ENV INITRD No

RUN echo "deb http://ppa.launchpad.net/vbernat/haproxy-1.5/ubuntu trusty main" >/etc/apt/sources.list.d/haproxy1.5.list
RUN echo "deb-src http://ppa.launchpad.net/vbernat/haproxy-1.5/ubuntu trusty main" >>/etc/apt/sources.list.d/haproxy1.5.list

RUN apt-get update -y
RUN apt-get install --force-yes -y supervisor haproxy inotify-tools python-pip
RUN pip install envtpl
ADD supervisord.conf.tpl /etc/supervisor/supervisord.conf.tpl
ADD dir-prereqs.sh /dir-prereqs.sh

#ADD supervisor.conf /etc/supervisor/conf.d/supervisor.conf

ADD . /app
WORKDIR /app
RUN cp /app/haproxy.cfg /etc/haproxy

RUN apt-get -y remove build-essential ".*-dev"
RUN apt-get -y autoremove

ENV TPLFILES /etc/supervisor/supervisord.conf

ENV HASVC hapconf.cfg
ENV SYSLOG_SERVER 127.0.0.1
ENV SYSLOG_PORT 514

VOLUME ["/hacfg"]

EXPOSE 80


CMD . ./dir-prereqs.sh && for FILE in $TPLFILES; do envtpl --keep-template --allow-missing $FILE.tpl; done && ./run.sh
