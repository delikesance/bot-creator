# ─── Build stage ──────────────────────────────────────────────────────────────
FROM dart:stable AS builder

WORKDIR /workspace

# Copy workspace pubspec first for caching
COPY pubspec.yaml ./

# Copy all packages
COPY packages/shared  packages/shared
COPY packages/runner  packages/runner

# Resolve dependencies for the runner (workspace-aware)
WORKDIR /workspace/packages/runner
RUN dart pub get

# Compile to a native executable (AOT)
RUN dart compile exe bin/runner.dart -o /out/runner

# ─── Runtime stage ────────────────────────────────────────────────────────────
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /out/runner /usr/local/bin/runner

# Persistent runtime data (synced bot configs + logs)
ENV BOT_CREATOR_DATA_DIR=/data/bots
ENV BOT_CREATOR_RUNNER_LOG_FILE=/data/logs/runner.log
ENV BOT_CREATOR_WEB_HOST=0.0.0.0
ENV BOT_CREATOR_WEB_PORT=8080

VOLUME ["/data"]
EXPOSE 8080

# Default mode: runner REST API.
ENTRYPOINT ["/usr/local/bin/runner"]
CMD ["--web"]
