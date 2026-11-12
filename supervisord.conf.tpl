[supervisord]
nodaemon=true
# With nodaemon=true supervisord also writes its own log to the container stdout
{% if LOG_TO_DISK == "true" %}
logfile = {{ LOGSPATH }}/{{DOCKERID}}/supervisor/supervisor.log
{% else %}
logfile = /dev/null
logfile_maxbytes = 0
{% endif %}
pidfile = /var/run/supervisord.pid
loglevel = warn

[eventlistener:logging]
command = supervisor_logging
events = PROCESS_LOG

[program:inotifreload]
command=/app/inotifreload.sh
# Output goes to the container stdout (docker logs); when LOG_TO_DISK=true
# inotifreload.sh also tees it to $LOGSPATH/$DOCKERID/supervisor/inotifyreload.log
stdout_logfile = /dev/stdout
stdout_logfile_maxbytes = 0
redirect_stderr = true
autorestart = true
directory=/app

