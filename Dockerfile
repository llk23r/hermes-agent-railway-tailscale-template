FROM ghcr.io/astral-sh/uv:python3.12-bookworm-slim

ARG NODE_VERSION=22.22.3

RUN apt-get update && \
    apt-get install -y --no-install-recommends curl ca-certificates git ffmpeg nginx-light xz-utils && \
    rm -rf /var/lib/apt/lists/*

RUN curl -fsSLO "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz" && \
    curl -fsSLO "https://nodejs.org/dist/v${NODE_VERSION}/SHASUMS256.txt" && \
    grep " node-v${NODE_VERSION}-linux-x64.tar.xz$" SHASUMS256.txt | sha256sum -c - && \
    mkdir -p /opt/node && \
    tar -xJf "node-v${NODE_VERSION}-linux-x64.tar.xz" -C /opt/node --strip-components=1 && \
    rm "node-v${NODE_VERSION}-linux-x64.tar.xz" SHASUMS256.txt

ENV PATH="/opt/node/bin:${PATH}"

RUN curl -fsSL https://tailscale.com/install.sh | sh

RUN git clone --depth 1 https://github.com/NousResearch/hermes-agent.git /tmp/hermes-agent && \
    cd /tmp/hermes-agent && \
    uv pip install --system --no-cache -e ".[all]" && \
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
