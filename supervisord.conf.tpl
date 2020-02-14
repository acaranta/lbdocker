[supervisord]
nodaemon=true
logfile = {{ LOGSPATH }}/{{DOCKERID}}/supervisor/supervisor.txt
pidfile = /var/run/supervisord.pid
loglevel = warn

[eventlistener:logging]
command = supervisor_logging
events = PROCESS_LOG

[program:inotifreload]
command=/app/inotifreload.sh
#stdout_logfile = {{ LOGSPATH }}/{{DOCKERID}}/supervisor/supervisor.txt
#stderr_logfile = {{ LOGSPATH }}/{{DOCKERID}}/supervisor/supervisor.txt
stdout_syslog = true
stderr_syslog = true
autorestart = true
directory=/app

[program:injectinfluxdb]
command=/app/influxinject.py
stdout_logfile = {{ LOGSPATH }}/{{DOCKERID}}/supervisor/injectinfluxdb/injector.txt
stderr_logfile = {{ LOGSPATH }}/{{DOCKERID}}/supervisor/injectinfluxdb/injector.txt
autorestart = unexpected
exitcodes=0,2
directory=/app

