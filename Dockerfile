# Build stage
FROM rust:1-slim-bookworm AS builder

WORKDIR /usr/src/mcp-pangolin

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    pkg-config \
    libssl-dev \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Copy workspace and manifests
COPY Cargo.toml Cargo.lock ./
COPY server/Cargo.toml ./server/

# Cache dependencies with dummy source
RUN mkdir -p server/src && \
    echo "fn main() {}" > server/src/main.rs && \
    cargo build --release && \
    rm -rf server/src

# Copy real source code and build
COPY server ./server
RUN touch server/src/main.rs && cargo build --release

# Runtime stage with Node.js for supergateway (Streamable HTTP / SSE)
FROM node:20-bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# Install supergateway globally inside the container
RUN npm install -g supergateway@latest

WORKDIR /app

# Copy compiled Rust binary
COPY --from=builder /usr/src/mcp-pangolin/target/release/mcp-pangolin /usr/local/bin/mcp-pangolin

RUN mkdir -p /app/data

ENV PANGOLIN_OPENAPI_FILE=/app/data/pangolin-api.json
ENV PORT=3113

EXPOSE 3113

# Default entrypoint runs supergateway bridging Streamable HTTP on /mcp to mcp-pangolin
ENTRYPOINT ["sh", "-c", "supergateway --port ${PORT:-3113} --outputTransport streamableHttp --streamableHttpPath /mcp --cors --stdio 'mcp-pangolin'"]
