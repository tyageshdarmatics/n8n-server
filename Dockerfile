FROM node:20-bookworm-slim

# Install dependencies
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

# Install n8n globally
RUN npm install -g n8n

# Set working dir
WORKDIR /data

# Expose port
EXPOSE 5678

# Use tini (important for Render)
ENTRYPOINT ["tini", "--"]

# Start n8n
CMD ["n8n"]
