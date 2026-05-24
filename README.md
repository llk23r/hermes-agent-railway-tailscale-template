# Hermes Agent on Railway with Tailscale

Minimal Railway worker for Hermes Agent behind Tailscale.

## Variables

Required for first boot:

- `TS_AUTHKEY`

Required for Telegram:

- `TELEGRAM_BOT_TOKEN`

Optional:

- `TS_HOSTNAME`, default `hermes-agent`
- `TS_TAGS`, example `tag:hermes-agent`
- `TS_SERVE_ENABLE`, default `true`
- `TS_PROXY_PORT`, default `9120`
- `HERMES_HOME`, default `/data/.hermes`

## Configure

Attach a volume at `/data`.

Use a tagged, pre-approved Tailscale auth key.

Do not add a public domain unless you need one.

The dashboard binds to loopback. Tailscale Serve reaches it through a loopback proxy.

Configure Hermes from the dashboard or by editing `/data/.hermes/config.yaml` over Railway SSH.

## Verify

Open `https://<TS_HOSTNAME>.<tailnet>.ts.net/` from a device on the tailnet.

The service is working when:

- The dashboard loads.
- `hermes gateway status` reports the gateway running.
- A message to the Telegram bot receives a response.
