FROM node:20-alpine

USER root

RUN apk add --no-cache \
    git \
    python3 \
    py3-pip \
    make \
    g++ \
    build-base \
    cairo-dev \
    pango-dev \
    chromium \
    postgresql-client \
    ffmpeg \
    bash \
    curl \
    jq \
    tini

ENV PUPPETEER_SKIP_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser

RUN npm install -g n8n@1.123.5

RUN mkdir -p /root/.n8n && chmod -R 777 /root/.n8n

WORKDIR /data

EXPOSE 5678

ENTRYPOINT ["tini", "--"]
CMD ["n8n", "start"]
