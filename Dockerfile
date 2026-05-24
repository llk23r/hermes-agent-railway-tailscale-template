FROM ghcr.io/astral-sh/uv:python3.12-bookworm-slim

ARG NODE_VERSION=22.22.3
ARG TAILSCALE_VERSION=1.98.3
ARG HERMES_REF=186bf25cb11077b8c158dbfc1f768e48bc28b0db

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends curl ca-certificates git nginx-light xz-utils && \
    rm -rf /var/lib/apt/lists/*

RUN curl -fsSLO "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz" && \
    curl -fsSLO "https://nodejs.org/dist/v${NODE_VERSION}/SHASUMS256.txt" && \
    grep " node-v${NODE_VERSION}-linux-x64.tar.xz$" SHASUMS256.txt | sha256sum -c - && \
    mkdir -p /opt/node && \
    tar -xJf "node-v${NODE_VERSION}-linux-x64.tar.xz" -C /opt/node --strip-components=1 && \
    rm "node-v${NODE_VERSION}-linux-x64.tar.xz" SHASUMS256.txt

ENV PATH="/opt/node/bin:${PATH}"

RUN curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.noarmor.gpg \
      -o /usr/share/keyrings/tailscale-archive-keyring.gpg && \
    curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.tailscale-keyring.list \
      -o /etc/apt/sources.list.d/tailscale.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends "tailscale=${TAILSCALE_VERSION}" && \
    rm -rf /var/lib/apt/lists/*

RUN git init /tmp/hermes-agent && \
    cd /tmp/hermes-agent && \
    git remote add origin https://github.com/NousResearch/hermes-agent.git && \
    git fetch --depth 1 origin "$HERMES_REF" && \
    git checkout --detach FETCH_HEAD && \
    rm -rf plugins/platforms && \
    uv pip install --system --no-cache -e ".[web]" "python-telegram-bot[webhooks]==22.6" "qrcode==7.4.2" && \
    cd /tmp/hermes-agent/web && \
    npm install --no-audit --no-fund && \
    npm run build && \
    rm -rf /tmp/hermes-agent/.git

RUN mkdir -p /data/.hermes /data/tailscale /app

COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh

ENV HOME=/data
ENV HERMES_HOME=/data/.hermes

CMD ["/app/start.sh"]
