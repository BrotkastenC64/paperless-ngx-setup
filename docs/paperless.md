# Paperless-NGX Setup mit Podman (rootless)

In diesem Dokument halten wir die notwendigen Schritte und Rahmenbedingungen für die manuelle Container-Instanziierung von Paperless-NGX unter Podman fest. Dabei legen wir besonderen Wert auf:

1. **Rootless-Modus und Namespaces**  
   Podman läuft ohne Root-Rechte und verwendet User- und Netzwerk-Namespaces (Slirp4netns). Dadurch:
   - können Container keine privilegierten Ports (<1024) direkt öffnen,  
   - läuft der Netzwerkverkehr über einen unprivilegierten Netzwerk-Tunnel,  
   - und Volumes müssen mit korrekten UID/GID-Mappings gemountet werden.

2. **Verzicht auf `podman-compose`**  
   Werkzeuge wie `podman-compose` setzen oft auf root-Privilegien oder vorausgesetzte Netzwerk-Bridges, die im rootless-Modus nicht automatisch zur Verfügung stehen.  
   Wir vermeiden daher Compose-Definitionen und starten jeden Dienst einzeln mit `podman run`, um:
   - präzise Kontrolle über Volumes und Umgebungsvariablen zu haben,  
   - direktes Feedback bei Fehlern zu erhalten,  
   - und spätere Ableitungen in Systemd-Units zu erleichtern.

3. **Manuelles Starten und Verifizieren**  
   Jeder der drei Hauptdienste wird separat gestartet und getestet:
   - **Datenbank (PostgreSQL)**  
   - **Cache/Queue (Redis)**  
   - **Anwendung (Paperless-NGX)**  

Für jeden Dienst dokumentieren wir:
- den genauen `podman run`-Befehl,
- notwendige Umgebungsvariablen und Flags,
- Volume-Mounts mit UID/GID,
- Port-Mappings oder Netzwerk-Einstellungen,
- und die grundlegenden Tests (Logs, Health-Checks).

Mit diesen Vorgaben stellen wir sicher, dass unser Paperless-NGX-Stack im rootless Podman-Modus stabil und sicher betrieben werden kann. Im nächsten Abschnitt führen wir Schritt für Schritt durch die Einrichtung der PostgreSQL-Datenbank.

## Verzeichnisstruktur und Berechtigungen

Bevor wir die Container starten, legen wir das lokale Verzeichnis-Layout an, passen die Besitz- und Zugriffsrechte an und prüfen später den Mount von `/var/scan`.

### 1. Verzeichnisstruktur anlegen

```bash
sudo mkdir -p /opt/paperless/{data,media,consume,export,logs}
````

* `data` … persistente Anwendungsdaten (Datenbank, Metadaten)
* `media` … extrahierte Dokumente, Vorschaubilder
* `consume` … Import-Ordner (später gemountet von `/var/scan`)
* `export` … optionaler Export-Ordner
* `logs` … eigene Log-Dateien

### 2. Berechtigungen setzen

```bash
sudo chown -R master:master /opt/paperless
sudo chmod -R 750 /opt/paperless
```

* Eigentümer `master` (oder später `paperless`-UID/GID)
* `7` (rwx) für den Besitzer, `5` (r-x) für die Gruppe, `0` für alle anderen

### 3. Mount von `/var/scan` in `consume` prüfen

Da wir später rootless Podman einsetzen, prüfen wir schon jetzt, ob der Ordner `/opt/paperless/consume` korrekt von `/var/scan` aus dem Host erreichbar ist:

```bash
# Testweise binden (temporär)
sudo mount --bind /var/scan /opt/paperless/consume

# Verzeichnisinhalt prüfen
ls -l /opt/paperless/consume

# Bind wieder auflösen
sudo umount /opt/paperless/consume
```

**Prüfung des Bind-Mounts**

```bash
sudo mount --bind /var/scan /opt/paperless/consume
ls -l /opt/paperless/consume
# Erwartete Ausgabe:
# total 440
# drwx------ 2 root    root     16384 Jun 23 12:30 lost+found
# -rw------- 1 scanner scanner 431183 Jun 25 09:03 scan20250625095605.pdf

sudo umount /opt/paperless/consume
```

>[!NOTE] 
>
>im finalen Podman-Run verwenden wir dann `-v /var/scan:/usr/src/paperless/src/consume`, hier prüfen wir nur die Zugriffsrechte und Pfade.

## Podman Installation und Konfiguration (rootless)

Bevor wir Container starten, installieren und konfigurieren wir Podman im rootless-Modus:

### 1. System aktualisieren und Podman installieren

```bash
sudo apt update
sudo apt install -y podman
````

### 2. Subuid/Subgid prüfen

Stelle sicher, dass dein User (`master`) in `/etc/subuid` und `/etc/subgid` eingetragen ist:

```bash
grep "^master:" /etc/subuid /etc/subgid
```

Erwartet etwa:

```
/etc/subuid: master:100000:65536
/etc/subgid: master:100000:65536
```

Falls nicht vorhanden, lege die Einträge an:

```bash
echo "master:100000:65536" | sudo tee -a /etc/subuid
echo "master:100000:65536" | sudo tee -a /etc/subgid
```

### 3. Verzeichnis für Cgroups v2 freigeben (Ubuntu 24.04)

Podman verwendet Cgroups v2. Prüfe, ob dein System im Cgroup v2-Modus läuft:

```bash
mount | grep cgroup2
```

Falls kein `cgroup2` gemountet ist, ergänze in `/etc/default/grub`:

```
GRUB_CMDLINE_LINUX="systemd.unified_cgroup_hierarchy=1"
```

Dann Grub neu laden und neu booten:

```bash
sudo update-grub
sudo reboot
```

### 4. Netzwerk-Backend für Rootless

Podman nutzt standardmäßig `slirp4netns`. Prüfe, ob das Paket installiert ist:

```bash
sudo apt install -y slirp4netns
```

### 5. Testlauf

Starte einen einfachen Container als Check:

```bash
podman run --rm -it docker.io/library/alpine sh -c "echo Podman rootless läuft OK"
```

Erwartete Ausgabe:

```
Podman rootless läuft OK
```
## Start des PostgreSQL-Containers

Bevor wir beginnen, legen wir sicherheitshalber das Datenverzeichnis für PostgreSQL an und stellen sicher, dass es leer ist:

```bash
sudo mkdir -p /opt/paperless/data
sudo chown master:master /opt/paperless/data
````

### 1. Container starten

```bash
podman run -d \
  --name paperless-db \
  -e POSTGRES_USER=paperless \
  -e POSTGRES_PASSWORD=securepassword \
  -e POSTGRES_DB=paperless \
  -v /opt/paperless/data:/var/lib/postgresql/data:Z \
  docker.io/library/postgres:15-alpine
```

* `--name paperless-db` … bequemer Verweis auf den Container
* Umgebungsvariablen definiert User, Passwort und Datenbank-Namen
* Das Host-Verzeichnis `/opt/paperless/data` wird als persistentes DB-Volume gemountet
* Das Suffix `:Z` stellt sicher, dass SELinux-Kontext (falls aktiv) richtig gesetzt wird

> [!NOTE]
>
> * ``docker.io/library/postgres:15-alpine`` statt nur ``postgres:15-alpine``
> * Podman weiß so direkt, wo es das Image suchen muss.

Wenn der Container dann läuft, prüfen wir gemeinsam mit:
```bash
podman ps --filter name=paperless-db
podman logs -f paperless-db
```

### 2. Logs prüfen

Direkt nach dem Start prüfen wir, ob PostgreSQL erfolgreich initialisiert:

```bash
podman logs -f paperless-db
```

* Erfolgreich sichtbar:

  ```
  PostgreSQL init process complete; ready for start up.
  ```

### 3. Datenbank-Verbindung testen

```bash
podman exec -it paperless-db psql -U paperless -d paperless -c "\dt"
```

* Erwartete Ausgabe: Liste der Tabellen (ggf. noch leer, sobald Paperless seine Migrationen ausführt)

Der PostgreSQL-Container läuft jetzt einwandfrei und ist bereit:

* **`podman ps`** zeigt den Container `paperless-db` mit Status „Up“ an.
* In den Logs sehen wir, dass der Datenbank-Cluster initialisiert wurde und der Server auf `0.0.0.0:5432` bzw. `::5432` lauscht:

  ```
  LOG:  database system is ready to accept connections
  ```
* Die Warnung `no usable system locales were found` ist bei Alpine-Images typisch und beeinträchtigt den Betrieb nicht, kann aber später durch Installation von `locales` im Container behoben werden, falls benötigt.

### 4. Erfolgskontrolle

```bash
podman ps --filter name=paperless-db
# Erwartete Ausgabe:
# CONTAINER ID  IMAGE                                 STATUS
# 130cb893d798  docker.io/library/postgres:15-alpine  Up

podman logs paperless-db | tail -n 5
# Erwartete Log-Zeilen:
# LOG:  database system is ready to accept connections
````

**Datenbank-Check**
```bash
podman exec -it paperless-db psql -U paperless -d paperless -c "\dt"
# Sollte ohne Fehler laufen und (ggf. leere) Tabelle(n) zurückliefern.
```

Die Meldung

```
Did not find any relations.
```

ist erwartungsgemäß: Die Datenbank existiert, enthält aber noch keine Tabellen, da Paperless-NGX seine Migrationen erst beim Start der Anwendung selbst anlegt.

---

## Dokumentationsergänzung in `docs/paperless.md`

Füge nach dem bestehenden Abschnitt zur Erfolgskontrolle dieses Unterkapitel ein:

#### 5. Datenbank-Check

```bash
podman exec -it paperless-db psql -U paperless -d paperless -c "\dt"
# Ausgabe:
# Did not find any relations.
````

> [!NOTE]
>
>Die Datenbank ist korrekt angelegt, enthält aber noch keine Tabellen, bis Paperless-NGX beim Anwendungsstart seine Migrationen durchführt.

## Start des Redis-Containers

Nachdem die Datenbank bereitsteht, richten wir Redis als Cache/Queue-Dienst ein. Paperless-NGX nutzt Redis für Hintergrundjobs und Task-Queues.

### 1. Verzeichnis für Redis-Daten anlegen

```bash
sudo mkdir -p /opt/paperless/redis
sudo chown master:master /opt/paperless/redis
sudo chmod 750 /opt/paperless/redis
````

### 2. Redis-Container starten

```bash
podman run -d \
  --name paperless-redis \
  -v /opt/paperless/redis:/data:Z \
  docker.io/library/redis:7-alpine \
  redis-server --save 60 1 --port 6379
```

* `--name paperless-redis` … bequeme Referenz
* `-v /opt/paperless/redis:/data:Z` … persistente Speicherung
* `redis:7-alpine` … offizielles, leichtgewichtiges Redis-Image
* `redis-server --save 60 1` … speichert das DB-Snapshot alle 60 Sek. bei ≥ 1 Änderung

### 3. Logs prüfen

```bash
### 3. Logs prüfen und Warning behandeln

```bash
podman logs -f paperless-redis
# Ausgabe enthält:
# * Ready to accept connections
# WARNING Memory overcommit must be enabled! …
```

Du solltest sehen:

```
* Ready to accept connections
```

> [!NOTE]
>
> ```bash
> echo "vm.overcommit_memory=1" | sudo tee -a /etc/sysctl.conf
> sudo sysctl -p```

### 4. Connectivity-Test

Falls auf dem Host-Ports gebunden werden sollen (nicht zwingend erforderlich), kann man Redis so starten:

```bash
podman run -d \
  --name paperless-redis \
  -p 6379:6379 \
  -v /opt/paperless/redis:/data:Z \
  docker.io/library/redis:7-alpine \
  redis:7-alpine
```

Anschließend testest du die Verbindung mit dem in Podman eingebetteten CLI:

```bash
podman exec -it paperless-redis redis-cli ping
# Antwort: PONG
```

## Start der Paperless-NGX-Anwendung

Nachdem PostgreSQL und Redis laufen, starten wir nun den Paperless-NGX-Container. Wir mounten dabei:

- `/var/scan` in den Konsume-Pfad  
- `/opt/paperless/media` für Medien und Vorschaubilder  
- `/opt/paperless/data` für Applikationsdaten (lokale Settings, Exporte)  

### 1. Umgebungsdatei anlegen

Lege in `/opt/paperless/.env` folgende Variablen ab:

```ini
# Database
DBHOST=localhost
DBNAME=paperless
DBUSER=paperless
DBPASS=securepassword

# Redis
REDIS_URL=redis://localhost:6379

# Pfade im Container
PAPERLESS_CONSUMPTION_DIR=/usr/src/paperless/src/consume
PAPERLESS_MEDIA_ROOT=/usr/src/paperless/src/media
PAPERLESS_DATA_DIR=/usr/src/paperless/src/data

# User/Group IDs (master = 1000)
PAPERLESS_UID=1000
PAPERLESS_GID=1000
````

### 2. Paperless-NGX-Container starten

```bash
podman run -d \
  --name paperless-app \
  --env-file /opt/paperless/.env \
  -p 8000:8000 \
  -v /var/scan:/usr/src/paperless/src/consume:Z \
  -v /opt/paperless/media:/usr/src/paperless/src/media:Z \
  -v /opt/paperless/data:/usr/src/paperless/src/data:Z \
  ghcr.io/paperless-ngx/paperless-ngx:latest
```

* `-p 8000:8000` macht die Web-GUI unter `http://<Server-IP>:8000` verfügbar.
* Alle Volumes im SELinux-Kontext (`:Z`).

### 3. Logs überwachen

```bash
podman logs -f paperless-app
```

Du solltest nach einigen Sekunden u. a. sehen:

```
INFO  [main] Starting Paperless-NGX ...
INFO  [django] Applying migrations ...
INFO  [django] Starting development server at http://0.0.0.0:8000/
```

### 4. Web-Zugriff testen

Öffne im Browser:

```
http://<Server-IP>:8000
```

→ Die Login-Seite von Paperless-NGX erscheint.