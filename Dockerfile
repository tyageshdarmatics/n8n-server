FROM n8nio/n8n:latest

USER root

RUN apt-get update && apt-get install -y \
    ffmpeg \
    bash \
    curl \
    git \
    jq \
    python3 \
    python3-pip \
    tzdata \
    && rm -rf /var/lib/apt/lists/*

USER node
