FROM n8nio/n8n:latest

USER root

RUN apk add --no-cache \
    ffmpeg \
    bash \
    curl \
    git \
    jq \
    python3 \
    py3-pip \
    tzdata

USER node
