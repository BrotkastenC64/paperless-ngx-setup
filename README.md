# 📚 Paperless NGX mit FTP-Integration und rootless Podman

Dieses Projekt beschreibt den vollständigen Aufbau einer sicheren, flexiblen und wartungsfreundlichen Dokumentenmanagement-Lösung (**Paperless NGX**) mit integrierter **FTP-Schnittstelle für Netzwerkscanner** unter Verwendung von **rootless Podman** auf **Ubuntu 24.04 LTS**.

## 🗃️ Strukturübersicht

Die Projektorganisation besteht aus mehreren logischen Teilen:

```
paperless/
├── docs/
│   ├── ftp.md                # Doku: FTP-Server Einrichtung
│   └── paperless.md          # Doku: Paperless NGX Setup mit Podman
├── tessdata/                 # OCR-Sprachmodell (nicht versioniert)
├── start.sh                  # Startskript für Container-Stack
├── stop.sh                   # Stopskript für Container-Stack
└── README.md                 # Überblick zum Gesamtprojekt
```

### 🔄 Serververzeichnis-Struktur (`/opt/paperless`)

```
/opt/paperless/
├── consume                   # Eingangsordner (Scan-Import über FTP)
├── data                      
│   ├── app                   # Paperless-NGX-Anwendungsdaten
│   └── db                    # PostgreSQL-Datenbank
├── export                    # Exportierte Dokumente
├── logs                      # Eigene Log-Dateien
├── media                     # Dokumenten-Archiv und Thumbnails
└── redis                     # Redis-Daten
```

### 📂 Scanner-Eingangsverzeichnis (`/var/scan`)

* Wird als FTP-Zielverzeichnis für Netzwerkscanner genutzt.
* Dokumente werden automatisch nach `/opt/paperless/consume` (Container-Pfad) übergeben und von Paperless NGX verarbeitet.

## 🚩 Ziele des Projekts

* ✅ **Sicher:** Einsatz von rootless Podman reduziert Sicherheitsrisiken.
* ✅ **Nachvollziehbar:** Umfangreiche Schritt-für-Schritt-Dokumentation.
* ✅ **Einfach wartbar:** Automatisierung über `systemd` und saubere Trennung von Diensten.
* ✅ **Flexibel:** Jeder Dienst wird separat gestartet und konfiguriert.

## 🚀 Einstieg und Nutzung

Starte mit der ausführlichen Dokumentation zu den zentralen Komponenten:

* 📑 [FTP-Einrichtung für Netzwerkscanner](docs/ftp.md)
* 📑 [Paperless-NGX-Setup mit rootless Podman](docs/paperless.md)

Verwende die mitgelieferten Skripte für den Betrieb:

```bash
./start.sh    # Paperless-Stack starten
./stop.sh     # Paperless-Stack stoppen
```

## 🔧 Technische Voraussetzungen

* Ubuntu Server 24.04 LTS
* Podman (rootless), PostgreSQL, Redis, vsftpd (FTP-Server)
* Netzwerkscanner (z.B. Kyocera Ecosys-Serie)

## 🛠️ Wartung und Fehlerbehebung

Die häufigsten Fehler sowie Wartungshinweise findest du direkt in den Dokumentationen unter dem jeweiligen Abschnitt **„Troubleshooting“**.

---

© 2025 – Entwickelt und gepflegt von Oliver Risch
