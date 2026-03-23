# ─── Build stage ──────────────────────────────────────────────────────────────
FROM dart:stable AS builder

WORKDIR /workspace

# Copy only packages needed to build runner
COPY packages/shared packages/shared
COPY packages/runner packages/runner

# Create a minimal workspace for Docker build (exclude Flutter app package)
RUN printf "name: bot_creator_runner_workspace\ndescription: Docker build workspace for runner\npublish_to: none\nenvironment:\n  sdk: ^3.7.2\nworkspace:\n  - packages/shared\n  - packages/runner\n" > /workspace/pubspec.yaml

# Resolve dependencies for the runner (workspace-aware)
# Run from workspace root to ensure proper workspace initialization
RUN dart pub get

# Compile to a native executable (AOT)
WORKDIR /workspace/packages/runner
RUN mkdir -p /out && dart compile exe bin/runner.dart -o /out/runner

# ─── Runtime stage ────────────────────────────────────────────────────────────
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /out/runner /usr/local/bin/runner

# Persistent runtime data (synced bot configs + logs)
ENV BOT_CREATOR_DATA_DIR=/data/bots
ENV BOT_CREATOR_RUNNER_LOG_FILE=/data/logs/runner.log
ENV BOT_CREATOR_WEB_HOST=127.0.0.1
ENV BOT_CREATOR_WEB_PORT=8080

VOLUME ["/data"]
EXPOSE 8080

# Default mode: runner REST API.
ENTRYPOINT ["/usr/local/bin/runner"]
