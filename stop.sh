#!/usr/bin/env bash
set -euo pipefail

# Basis-Verzeichnis (hier nicht zwingend nötig, aber symmetrisch zu start.sh)
BASE_DIR="/opt/paperless"

echo "Stoppe Paperless-Container via systemd…"
systemctl --user stop paperless-app.service paperless-redis.service paperless-db.service

echo "Fertig. Alle Paperless-Container wurden gestoppt."
