# Runner Docker (Web Bootstrap + Google Drive)

This document explains how to run the Runner in Docker with the web bootstrap flow.

## Why a volume is required

Google Drive OAuth tokens are persisted by the runner on disk.

By default in Docker, the runner writes the token cache to:

- `/data/auth/google_drive_tokens.json`

If you do not mount a persistent volume, tokens are lost on container restart.

## Build image

```bash
docker build -t bot-creator-runner .
```

## Create persistent volume

```bash
docker volume create bot_creator_data
```

## Run web mode

```bash
docker run --rm \
  -p 8080:8080 \
  -v bot_creator_data:/data \
  bot-creator-runner
```

The image now starts in web mode by default (`--web`).

## First launch flow (no token yet)

When no Drive token is found:

1. Open the web UI (`http://<server-ip>:8080`)
2. The page shows:
  - Google OAuth authorization URL
3. Open the URL in a browser and approve access
4. By default, Google redirects to `http://localhost:<port>/oauth2redirect` (Desktop OAuth constraint)
5. Once approved, the runner stores tokens in the mounted volume and automatically switches to the ready UI state

If the runner is remote (for example Raspberry Pi over SSH), use SSH local port forwarding and open the UI through `localhost` on your workstation:

```bash
ssh -L 8080:127.0.0.1:8080 <user>@<runner-host>
```

Then open `http://localhost:8080` in your local browser.

## Next launches

If token already exists and is still valid/refreshable, the web UI starts directly.

## Web UI features (after Drive is connected)

- List available bots from Google Drive backups
- Start a selected bot from the browser
- Stop the currently running bot
- Switch Google Drive account directly from the browser UI
- Read runner logs directly in the browser

When switching account, the runner clears local OAuth cache, then returns to the
authorization screen (OAuth authorization URL).

Logs are also persisted to disk by default in Docker:

- `/data/logs/runner.log`

## Failure behavior

If Google authorization fails (timeout, denial, or invalid auth state), the runner stops and exits with:

- `Connection failed`

## Useful environment variables

- `BOT_CREATOR_WEB_HOST` (default: `0.0.0.0`)
- `BOT_CREATOR_WEB_PORT` (default: `8080`)
- `BOT_CREATOR_WEB_PUBLIC_ORIGIN` (optional: override redirect origin manually; only use this if your OAuth client accepts that exact redirect URI)
- `BOT_CREATOR_DRIVE_DEVICE_ID` (optional: sent as OAuth `device_id` during desktop authorization)
- `BOT_CREATOR_DRIVE_DEVICE_NAME` (optional: sent as OAuth `device_name` during desktop authorization)
- `BOT_CREATOR_RUNNER_TOKEN_CACHE` (default in Docker image: `/data/auth/google_drive_tokens.json`)
- `BOT_CREATOR_RUNNER_LOG_FILE` (default in Docker image: `/data/logs/runner.log`)

The OAuth web flow keeps the scope on `https://www.googleapis.com/auth/drive.appdata`.

## Legacy CLI modes still available

You can still run the classic CLI modes:

- Local ZIP: `--config <file.zip>`
- Google Drive bot: `--drive-bot-id <bot_id>`
