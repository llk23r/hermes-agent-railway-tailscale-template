#!/bin/sh
set -eu
umask 077

HERMES_HOME="${HERMES_HOME:-/data/.hermes}"
PORT="${PORT:-9119}"
TS_STATE_DIR="${TS_STATE_DIR:-/data/tailscale}"
TS_SOCKET="${TS_SOCKET:-/tmp/tailscaled.sock}"
TS_HOSTNAME="${TS_HOSTNAME:-hermes-agent}"
TS_SERVE_ENABLE="${TS_SERVE_ENABLE:-true}"
TS_PROXY_PORT="${TS_PROXY_PORT:-9120}"
TS_SERVE_TARGET="${TS_SERVE_TARGET:-http://127.0.0.1:$TS_PROXY_PORT}"

start_dashboard_proxy() {
  nginx_config="/tmp/hermes-dashboard-nginx.conf"

  cat >"$nginx_config" <<EOF
worker_processes 1;
pid /tmp/hermes-dashboard-nginx.pid;

events {
  worker_connections 64;
}

http {
  access_log off;
  error_log /dev/stderr warn;

  map \$http_upgrade \$connection_upgrade {
    default upgrade;
    '' close;
  }

  server {
    listen 127.0.0.1:$TS_PROXY_PORT;
    server_name _;

    location / {
      proxy_pass http://127.0.0.1:$PORT;
      proxy_http_version 1.1;
      proxy_set_header Host 127.0.0.1:$PORT;
      proxy_set_header X-Forwarded-Host \$host;
      proxy_set_header X-Forwarded-Proto https;
      proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
      proxy_set_header Upgrade \$http_upgrade;
      proxy_set_header Connection \$connection_upgrade;
    }
  }
}
EOF

  nginx -t -q -c "$nginx_config"
  nginx -c "$nginx_config" -g "daemon off;" &
  nginx_pid="$!"
}

tailscale_up() {
  if [ -n "${TS_TAGS:-}" ]; then
    tailscale --socket="$TS_SOCKET" up "$@" \
      --hostname="$TS_HOSTNAME" \
      --accept-dns=false \
      --advertise-tags="$TS_TAGS"
  else
    tailscale --socket="$TS_SOCKET" up "$@" \
      --hostname="$TS_HOSTNAME" \
      --accept-dns=false
  fi
}

mkdir -p "$HERMES_HOME" "$TS_STATE_DIR"
rm -f "$TS_SOCKET"

tailscaled \
  --state="$TS_STATE_DIR/tailscaled.state" \
  --socket="$TS_SOCKET" \
  --tun=userspace-networking \
  --socks5-server=127.0.0.1:1055 \
  >"$TS_STATE_DIR/tailscaled.log" 2>&1 &

for _ in 1 2 3 4 5; do
  [ -S "$TS_SOCKET" ] && break
  sleep 1
done

if ! tailscale_up; then
  if [ -z "${TS_AUTHKEY:-}" ]; then
    echo "TS_AUTHKEY is required for first boot" >&2
    exit 1
  fi

  tailscale_up --auth-key="$TS_AUTHKEY"
fi

export PORT

shutdown() {
  [ -n "${nginx_pid:-}" ] && kill "$nginx_pid" 2>/dev/null || true
  [ -n "${gateway_pid:-}" ] && kill "$gateway_pid" 2>/dev/null || true
  [ -n "${dashboard_pid:-}" ] && kill "$dashboard_pid" 2>/dev/null || true
}

trap shutdown INT TERM

hermes gateway run &
gateway_pid="$!"

hermes dashboard --host 127.0.0.1 --port "$PORT" --no-open --skip-build &
dashboard_pid="$!"

start_dashboard_proxy

if [ "$TS_SERVE_ENABLE" = "true" ]; then
  tailscale --socket="$TS_SOCKET" serve --bg "$TS_SERVE_TARGET"
fi

wait "$dashboard_pid"
