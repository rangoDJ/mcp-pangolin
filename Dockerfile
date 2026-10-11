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

# Runtime stage
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy binary from builder
COPY --from=builder /usr/src/mcp-pangolin/target/release/mcp-pangolin /usr/local/bin/mcp-pangolin

# Create data directory for specs
RUN mkdir -p /app/data

ENV PANGOLIN_OPENAPI_FILE=/app/data/pangolin-api.json

ENTRYPOINT ["mcp-pangolin"]
