FROM node:20-bookworm-slim

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    bash \
    curl \
    git \
    jq \
    python3 \
    python3-pip \
    tzdata \
    ca-certificates \
    tini \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g n8n

ENV N8N_PORT=5678
ENV NODE_ENV=production

EXPOSE 5678

USER root

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["n8n", "start"]
