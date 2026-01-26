# LB Docker - HAProxy with Inotify Auto-Reload

A Docker-based HAProxy load balancer with automatic configuration reloading using inotify. This container watches for configuration changes and gracefully reloads HAProxy without downtime, making it ideal for dynamic environments and automated certificate management.

## Features

- **HAProxy v3.3.0** - Latest stable version with full feature support
- **Prometheus Metrics** - Built-in Prometheus exporter for monitoring
- **Auto-Reload** - Automatic graceful reload on configuration changes using inotify
- **Certificate Watching** - Monitors certificate directory for updates (perfect for Let's Encrypt/Certbot)
- **Maps Support** - Watches HAProxy maps directory for dynamic routing updates
- **Syslog Integration** - Optional remote syslog server support
- **Lua Scripts** - Includes auth-request and haproxy-lua-http for advanced features
- **Zero Downtime** - Graceful reloads maintain active connections

## Quick Start

### Using Docker Compose (Recommended)

```yaml
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

### Using Docker Run

```bash
docker run -d \
  --name lb \
  -e LBID=mydockerlb \
  -e LOGSPATH=/lblogs \
  -e HASVC=lbdkr.conf \
  -p 80:80 \
  -p 443:443 \
  -v /pathtovolumes/lbdkr/conf:/hacfg \
  -v /pathtovolumes/lbdkr/log:/lblogs \
  --restart always \
  acaranta/lbdocker:latest
```

## Configuration

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `LBID` | Yes | - | Unique identifier for your load balancer instance |
| `HASVC` | Yes | `hapconf.cfg` | Name of your service configuration file (must exist in `/hacfg`) |
| `LOGSPATH` | No | - | Path inside container where logs will be written |
| `SYSLOG_SERVER` | No | `127.0.0.1` | Remote syslog server address for centralized logging |
| `SYSLOG_PORT` | No | `514` | Syslog server port |
| `SYSLOG_PROTO` | No | `udp` | Syslog protocol (`udp` or `tcp`) |

### Volume Mounts

- **`/hacfg`** (Required) - Configuration directory containing:
  - Your HAProxy service configuration file (specified in `HASVC`)
  - `certs/` - SSL/TLS certificates (optional, auto-watched)
  - `maps/` - HAProxy map files (optional, auto-watched)
- **`/lblogs`** - Log output directory (optional)

### Directory Structure Example

```
/pathtovolumes/lbdkr/conf/
├── lbdkr.conf           # Your service configuration (HASVC)
├── certs/               # SSL certificates (optional)
│   ├── wildcard.example.com.crt
│   └── importantweb.example.com.crt
└── maps/                # HAProxy maps (optional)
    └── domains.map
```

## Service Configuration

The service configuration file contains your HAProxy frontends, backends, and other settings. The container provides the `global` and `defaults` sections automatically.

### Simple Example

```haproxy
# Frontend
frontend front_http
    bind :::80 v4v6
    mode http
    option httplog
    default_backend back_web

# Backend
backend back_web
    mode http
    server web1 webserver.local:80 check
```

### Advanced Example with SSL and Authentication

```haproxy
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

    # Default
    default_backend back_default

frontend front_HTTPS
    bind :::443 ssl crt /hacfg/certs/wildcard.example.com.crt crt /hacfg/certs/importantweb.example.com.crt accept-proxy v4v6
    mode http
    option dontlognull
    option forwardfor

    log-format "%ci:%cp\ [%Tl]\ %ft\ %b/%s\ %[ssl_fc_sni]\ %ST\ %B\ %CC\ %CS\ %tsc\ %sq/%bq\ %hr\ %hs\ %{+Q}r"
    
    use_backend back_importantweb if { ssl_fc_sni importantweb.example.com }
    
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
    http-request auth unless AuthUsers_ACL
    server srv_importantweb secureserver.mylan.net:82 maxconn 40 check inter 10s fall 4 rise 2

backend back_webassets
    mode http
    server srv_webassets mysrvaddress:8080 maxconn 40 check inter 10s fall 4 rise 2
```

### Configuration Scope

**You can configure:**
- All frontend definitions
- All backend definitions
- ACLs and userlists
- Lua scripts and custom logic
- Most HAProxy directives

**Pre-configured (cannot override):**
- `global` section (logging, uid/gid, Lua modules, etc.)
- `defaults` section (timeouts, retries, base options)

## Advanced Features

### Automatic Certificate Reloading

Place certificates in `/hacfg/certs/` and reference them in your configuration:

```haproxy
frontend front_HTTPS
    bind :::443 ssl crt /hacfg/certs/wildcard.example.com.crt v4v6
    ...
```

When certificates are updated (e.g., by Certbot), HAProxy automatically reloads gracefully.

### HAProxy Maps

Use maps for dynamic routing without config changes:

1. Create map file at `/hacfg/maps/domains.map`:
```
example.com back_example
api.example.com back_api
```

2. Reference in configuration:
```haproxy
frontend front_http
    use_backend %[req.hdr(host),lower,map(/hacfg/maps/domains.map,back_default)]
```

Changes to map files trigger automatic reloads.

### Prometheus Metrics

HAProxy is compiled with Prometheus exporter support. Add to your configuration:

```haproxy
frontend prometheus
    bind *:8404
    http-request use-service prometheus-exporter if { path /metrics }
```

Then scrape metrics from `http://container:8404/metrics`

### Lua Scripts

Two Lua scripts are included:

- **auth-request.lua** - External authentication support
- **haproxy-lua-http.lua** - HTTP client library for Lua scripts

These are automatically loaded and available in your configuration.

## How It Works

The container runs an inotify loop that monitors:
1. Your service configuration file (`HASVC`)
2. The `/hacfg/certs/` directory (if present)
3. The `/hacfg/maps/` directory (if present)

When changes are detected:
1. Files are synced to `/etc/haproxy/`
2. HAProxy configuration is validated
3. A graceful reload is triggered using `haproxy -sf` (keeps existing connections alive)

The inotify loop checks every 5 seconds and responds immediately to file changes.

## Building from Source

```bash
# Clone repository
git clone https://github.com/acaranta/lbdocker.git
cd lbdocker

# Build with default HAProxy version (v3.3.0)
docker build -t lbdocker:latest .

# Build with specific HAProxy version
docker build --build-arg HAPROXY_BRANCH=v3.4.0 -t lbdocker:custom .
```

The build process:
- Uses Ubuntu 22.04 as base
- Compiles HAProxy from source with Prometheus, Lua, OpenSSL, PCRE, and systemd support
- Installs inotify-tools for configuration watching
- Creates a minimal multi-stage build

## Troubleshooting

### HAProxy won't start

Check your configuration syntax:
```bash
docker exec lb haproxy -c -f /etc/haproxy/haproxy.cfg -f /etc/haproxy/lbdkr.conf
```

### Configuration not reloading

Check the inotify loop logs:
```bash
docker logs lb
```

You should see messages like:
```
Starting inotify loop
Found changes in /hacfg/lbdkr.conf ...
Found changes... gracefully reloading HAProxy
```

### Certificate errors

Ensure certificates are in PEM format with the full chain:
```bash
cat certificate.crt intermediate.crt root.crt private.key > combined.crt
```

### Viewing HAProxy stats

Add a stats frontend to your configuration:
```haproxy
frontend stats
    bind *:8080
    stats enable
    stats uri /
    stats refresh 5s
```

## Performance Tuning

The container uses these default timeouts (in haproxy.cfg:23-25):
- Connect: 90s
- Client: 90s  
- Server: 90s

Adjust in your environment or rebuild with custom haproxy.cfg for your use case.

## Security Considerations

- The container runs HAProxy as uid/gid 99
- Supervisord manages the process lifecycle
- No unnecessary services are included
- All build dependencies are removed in the final image
- Multi-stage build reduces attack surface

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is maintained by Arthur Caranta (arthur@caranta.com).

## Links

- **GitHub**: https://github.com/acaranta/lbdocker
- **Docker Hub**: https://hub.docker.com/r/acaranta/lbdocker
- **HAProxy Documentation**: https://www.haproxy.com/documentation/haproxy-configuration-manual/latest/
