# Runner Docker (API only)

Ce document explique comment exécuter le Runner en Docker en mode API.

Le Runner n'a qu'une seule fonction: exposer une API HTTP pour que l'application
Bot Creator puisse:

- synchroniser les configurations de bots,
- démarrer un bot par ID,
- arrêter un bot par ID,
- lire le statut/les métriques/logs.

Le mode mono-bot (CLI local ZIP) n'est plus supporté.

## Build de l'image

```bash
docker build -t bot-creator-runner .
```

## Volume persistant

```bash
docker volume create bot_creator_data
```

Ce volume conserve les données Runner (configs synchronisées, variables, logs)
entre les redémarrages du conteneur.

## Lancer le Runner API

```bash
docker run --rm \
  -p 8080:8080 \
  -v bot_creator_data:/data \
  bot-creator-runner
```

L'image démarre en mode API par défaut.

## Endpoints principaux

- `GET /health`
- `GET /status`
- `GET /metrics`
- `GET /bots`
- `POST /bots/sync`
- `POST /bots/{id}/start`
- `POST /bots/{id}/stop`
- `GET /logs?limit=N`

## Variables d'environnement utiles

- `BOT_CREATOR_WEB_HOST` (défaut: `0.0.0.0`)
- `BOT_CREATOR_WEB_PORT` (défaut: `8080`)
- `BOT_CREATOR_DATA_DIR` (défaut image: `/data/bots`)
- `BOT_CREATOR_RUNNER_LOG_FILE` (défaut image: `/data/logs/runner.log`)

## Note importante

Le binaire Runner est API-only. Les anciens usages CLI (ex: `--config` / ZIP local)
ne font plus partie du comportement supporté.
