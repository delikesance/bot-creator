# Single-Runner Coupling: Architecture Document

## Current Limitation

The app currently supports **one runner at a time**. All pages (dashboard, bot
status, logs, bot start/stop) use a single URL and API token stored in
`SharedPreferences`.

## Coupling Points

### 1. Runner Configuration — `runner_settings.dart`

| Key | Problem |
|-----|---------|
| `developer_runner_url` | Single URL stored in SharedPreferences |
| `developer_runner_api_token` | Single token for that URL |
| `RunnerSettings.createClient()` | Always returns a client for the single stored config |

Every page calls `RunnerSettings.createClient()` and operates against the
single returned `RunnerClient`.

### 2. Runner Client — `runner_client.dart`

All API methods accept an optional `botId` but never accept a **runner
selector**. Endpoints used:

| Method | Endpoint | Coupling |
|--------|----------|----------|
| `getStatus(botId?)` | `/status` or `/bots/{id}/status` | Single runner |
| `getMetrics(botId?)` | `/metrics` or `/bots/{id}/metrics` | Single runner |
| `getLogs()` | `/logs` | Single runner, no botId filter |
| `getCommandStats(botId)` | `/bots/{id}/command-stats` | Single runner |
| `syncBot(...)` | `/bots/sync` | Single runner target |
| `startBot(botId)` | `/bots/{id}/start` | Single runner |
| `stopBot(botId)` | `/bots/{id}/stop` | Single runner |
| `listBots()` | `/bots` | Single runner |

### 3. Pages Using Single Runner

| File | Usage |
|------|-------|
| `routes/app/command_dashboard.dart` | `_client` from `RunnerSettings.createClient()` |
| `routes/app/bot_stats.dart` | Polls `getMetrics()` every 3 s |
| `routes/app/bot_logs.dart` | Polls `getLogs()` every 2.5 s |
| `routes/app/home.dart` | `startBot`/`stopBot`/`syncBot` |
| `routes/home.dart` | `getStatus()` to discover running bots |
| `routes/app/settings.dart` | Single URL + token fields |

### 4. Data Model Assumptions

- `RunnerStatus.activeBotId` / `RunnerMetrics.activeBotId` — singular field.
- `RunnerBotRuntime` has no `runnerId` tracking which runner hosts it.
- Logs have no runner attribution.

## Impact on Users

- Dashboard stats are incomplete if bots run on multiple runners.
- Bot status shows as "stopped" if the configured runner isn't the one running
  the bot.
- There is no way to manage more than one runner from the settings page.

## Migration Plan (Multi-Runner)

### Phase A — Data Layer

1. Replace `RunnerSettings` with a `RunnerRegistry` that stores a **list** of
   `{id, name, url, apiToken}` entries in SharedPreferences (JSON array).
2. Add `runnerId` field to `RunnerBotRuntime`, `RunnerStatus`, and
   `RunnerMetrics`.
3. Create `RunnerPool` that wraps multiple `RunnerClient` instances and
   exposes aggregate methods (`getAllStatuses()`, `getAggregatedMetrics()`,
   `startBotOnRunner(botId, runnerId)`).

### Phase B — UI Layer

1. **Settings**: Replace single URL field with a list of runner cards
   (add/edit/remove/reorder).
2. **Home**: Aggregate `getStatus()` from all runners. Show runner badge
   per bot card.
3. **Dashboard**: Aggregate `getCommandStats()` across runners. Add
   runner-filter dropdown.
4. **Bot Logs / Stats**: Add runner selector tab or dropdown.
5. **Bot Launch**: Add runner picker when starting a bot (default = first
   available).

### Phase C — Cleanup

1. Remove `RunnerSettings.getUrl()` / `setUrl()` single-value helpers.
2. Update all callers to use `RunnerPool`.
3. Update tests.

## Files to Change (Summary)

| File | Change Required |
|------|-----------------|
| `runner_settings.dart` | Replace with `RunnerRegistry` |
| `runner_client.dart` | Add `runnerId` to models |
| `command_dashboard.dart` | Use `RunnerPool`, aggregate stats |
| `bot_stats.dart` | Use `RunnerPool`, aggregate metrics |
| `bot_logs.dart` | Use `RunnerPool`, add runner selector |
| `home.dart` (both) | Use `RunnerPool`, show runner badges |
| `settings.dart` | Multi-runner management UI |
