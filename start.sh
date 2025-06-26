#!/usr/bin/env bash
set -euo pipefail

# Pfad zu deinem Projektverzeichnis (falls nötig anpassen)
BASE_DIR="/opt/paperless"

# Environment‐File sicherstellen
ENV_FILE="${BASE_DIR}/.env"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: .env nicht gefunden in $BASE_DIR" >&2
  exit 1
fi

echo "Lese Umgebungsvariablen aus $ENV_FILE"
# In Skript exportieren (optional, wir nutzen systemd, daher nicht zwingend nötig)
# set -a
# source "$ENV_FILE"
# set +a

echo "Starte Paperless-Container über systemd..."
systemctl --user start paperless-db.service
systemctl --user start paperless-redis.service
systemctl --user start paperless-app.service

echo "Status prüfen..."
systemctl --user status --no-pager paperless-db.service paperless-redis.service paperless-app.service

echo "Fertig. Die Web-UI ist erreichbar unter http://<SERVER-IP>:8000"
