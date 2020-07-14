[supervisord]
nodaemon=true
logfile = {{ LOGSPATH }}/{{DOCKERID}}/supervisor/supervisor.log
pidfile = /var/run/supervisord.pid
loglevel = warn

[eventlistener:logging]
command = supervisor_logging
events = PROCESS_LOG

[program:inotifreload]
command=/app/inotifreload.sh
stdout_logfile = {{ LOGSPATH }}/{{DOCKERID}}/supervisor/inotifyreload.log
stderr_logfile = {{ LOGSPATH }}/{{DOCKERID}}/supervisor/inotifyreload.log
stdout_syslog = true
stderr_syslog = true
autorestart = true
directory=/app

