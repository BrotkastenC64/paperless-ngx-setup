# Paperless-NGX Setup mit rootless Podman

Dieses Dokument beschreibt die vollständige manuelle Einrichtung von Paperless-NGX mit rootless Podman auf einem Ubuntu-Server (getestet mit Ubuntu 24.04 LTS).

## Inhaltsverzeichnis

1. [Einleitung und Ziele](#einleitung-und-ziele)
2. [Voraussetzungen](#voraussetzungen)
3. [Verzeichnisstruktur](#verzeichnisstruktur)
4. [Podman Installation und Vorbereitung](#podman-installation-und-vorbereitung)
5. [Container starten](#container-starten)

   * PostgreSQL
   * Redis
   * Paperless-NGX
6. [Healthchecks und Tests](#healthchecks-und-tests)
7. [Automatisierung mit Systemd](#automatisierung-mit-systemd)
8. [Backup & Restore](#backup--restore)
9. [Troubleshooting](#troubleshooting)

---

## Einleitung und Ziele

Das Setup läuft vollständig im rootless Modus von Podman, was Sicherheit und Stabilität gewährleistet. Jeder Dienst wird manuell konfiguriert, um volle Kontrolle und Nachvollziehbarkeit zu gewährleisten.

## Voraussetzungen

* Ubuntu Server (24.04 LTS empfohlen)
* Podman, Slirp4netns, und Datenbank-Clients installiert:

```bash
sudo apt update
sudo apt install podman slirp4netns postgresql-client redis-tools -y
```

## Verzeichnisstruktur

```bash
sudo mkdir -p /opt/paperless/{data/db,data/app,media,consume,export,logs,redis}
sudo chown -R master:master /opt/paperless
sudo chmod -R 750 /opt/paperless
```

Prüfe Bind-Mount:

```bash
sudo mount --bind /var/scan /opt/paperless/consume
ls -l /opt/paperless/consume
sudo umount /opt/paperless/consume
```

## Podman Installation und Vorbereitung

Prüfung der Subuids:

```bash
grep "^master:" /etc/subuid /etc/subgid || sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 master
```

Cgroups v2 aktivieren:

```bash
sudo nano /etc/default/grub
# ergänze: GRUB_CMDLINE_LINUX="systemd.unified_cgroup_hierarchy=1"
sudo update-grub && sudo reboot
```

Testcontainer:

```bash
podman run --rm alpine echo "Podman OK"
```

## Container starten

### PostgreSQL

```bash
podman run -d \
  --name paperless-db \
  -e POSTGRES_USER=paperless \
  -e POSTGRES_PASSWORD=<your-secure-password> \
  -e POSTGRES_DB=paperless \
  -v /opt/paperless/data/db:/var/lib/postgresql/data:Z \
  postgres:15-alpine
```

### Redis

```bash
podman run -d \
  --name paperless-redis \
  -v /opt/paperless/redis:/data:Z \
  redis:7-alpine redis-server --save 60 1
```

### Paperless-NGX

`.env`-Datei anlegen:

```ini
DBHOST=paperless-db
DBNAME=paperless
DBUSER=paperless
DBPASS=<your-secure-password>
REDIS_URL=redis://paperless-redis:6379
PAPERLESS_CONSUMPTION_DIR=/usr/src/paperless/src/consume
PAPERLESS_MEDIA_ROOT=/usr/src/paperless/src/media
PAPERLESS_DATA_DIR=/usr/src/paperless/src/data
PAPERLESS_UID=1000  # Ersetze mit: id -u master
PAPERLESS_GID=1000  # Ersetze mit: id -g master
```

```bash
podman run -d \
  --name paperless-app \
  --env-file /opt/paperless/.env \
  -p 8000:8000 \
  -v /var/scan:/usr/src/paperless/src/consume:Z \
  -v /opt/paperless/media:/usr/src/paperless/src/media:Z \
  -v /opt/paperless/data/app:/usr/src/paperless/src/data:Z \
  ghcr.io/paperless-ngx/paperless-ngx:latest
```

## Healthchecks und Tests

Container testen:

```bash
podman exec -it paperless-db psql -U paperless -c '\l'
podman exec -it paperless-redis redis-cli ping
curl http://localhost:8000
```

## Automatisierung mit Systemd

Beispiel-Systemd-Unit für PostgreSQL (weitere analog):

```ini
[Unit]
Description=Paperless PostgreSQL Container
After=network.target

[Service]
ExecStart=/usr/bin/podman start -a paperless-db
ExecStop=/usr/bin/podman stop paperless-db
Restart=always
User=master

[Install]
WantedBy=multi-user.target
```

Aktivieren:

```bash
sudo systemctl enable --now paperless-db.service
```

## Backup & Restore

PostgreSQL-Backup:

```bash
podman exec paperless-db pg_dumpall -U paperless > paperless-db-backup.sql
```

Daten-Backup:

```bash
tar -czvf paperless-backup.tar.gz /opt/paperless
```

## Troubleshooting

| Fehler                  | Lösung                                                                               |
| ----------------------- | ------------------------------------------------------------------------------------ |
| Container starten nicht | Subuid/Subgid prüfen, Cgroups v2 aktivieren                                          |
| Keine Verbindung DB/App | Container im selben Netzwerk starten oder Pod erstellen                              |
| UID/GID Fehler          | UID/GID in `.env` anpassen                                                           |
| Redis Warnung           | `vm.overcommit_memory=1` in `/etc/sysctl.conf` setzen und `sudo sysctl -p` ausführen |
