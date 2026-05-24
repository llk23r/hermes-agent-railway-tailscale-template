# Hermes Agent on Railway with Tailscale

Minimal Railway worker for Hermes Agent.

## Variables

Required:

- `TS_AUTHKEY`

Optional:

- `TS_HOSTNAME`, default `railway-hermes-agent`
- `TS_TAGS`, example `tag:hermes-agent`
- `TS_SERVE_ENABLE`, default `true`
- `HERMES_HOME`, default `/data/.hermes`

## Railway

Attach a volume at `/data`.

Use a tagged, pre-approved Tailscale auth key.

Do not add a public domain unless you need one.

The dashboard binds to loopback and is exposed through Tailscale Serve.
