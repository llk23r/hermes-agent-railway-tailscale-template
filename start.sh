#!/bin/sh
set -eu

HERMES_HOME="${HERMES_HOME:-/data/.hermes}"
PORT="${PORT:-8080}"
TS_STATE_DIR="${TS_STATE_DIR:-/data/tailscale}"
TS_SOCKET="${TS_SOCKET:-/tmp/tailscaled.sock}"
TS_HOSTNAME="${TS_HOSTNAME:-railway-hermes-agent}"
TS_SERVE_ENABLE="${TS_SERVE_ENABLE:-true}"
TS_SERVE_TARGET="${TS_SERVE_TARGET:-http://127.0.0.1:$PORT}"

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

if tailscale --socket="$TS_SOCKET" status >/dev/null 2>&1; then
  tailscale_up
else
  if [ -z "${TS_AUTHKEY:-}" ]; then
    echo "TS_AUTHKEY is required for first boot" >&2
    exit 1
  fi

  tailscale_up --auth-key="$TS_AUTHKEY"
fi

if [ "$TS_SERVE_ENABLE" = "true" ]; then
  tailscale --socket="$TS_SOCKET" serve --bg "$TS_SERVE_TARGET"
fi

export PORT
exec hermes gateway
