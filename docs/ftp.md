# FTP-Konfiguration für Netzwerkscanner

Dieses Dokument beschreibt die schrittweise Einrichtung eines passiven FTP-Servers (vsftpd) auf einem Ubuntu-Server unter Proxmox, um Dokumente von einem Kyocera Ecosys M5521cdn Netzwerkscanner automatisch in das Verzeichnis `/var/scan` hochzuladen.

## Inhaltsverzeichnis

1. [Einleitung](#einleitung)
2. [Voraussetzungen](#voraussetzungen)
3. [Benutzeranlage](#benutzeranlage)
4. [Verzeichnis- und Berechtigungskonfiguration](#verzeichnis--und-berechtigungskonfiguration)
5. [vsftpd Installation und Grundkonfiguration](#vsftpd-installation-und-grundkonfiguration)
6. [Passive Mode Einstellungen](#passive-mode-einstellungen)
7. [Logging aktivieren](#logging-aktivieren)
8. [Firewall-Konfiguration](#firewall-konfiguration)
9. [Dienststart und Tests](#dienststart-und-tests)
10. [Troubleshooting bekannter Fehler](#troubleshooting-bekannter-fehler)

---

## Einleitung

In diesem Leitfaden beschreiben wir die vollständige Einrichtung eines passiven FTP-Servers auf einem Ubuntu-Server in einer Proxmox-Umgebung. Ziel ist es, einen dedizierten Scanner-User zu konfigurieren und den Dienst so zu betreiben, dass ein Kyocera Ecosys M5521cdn Netzwerkscanner Dokumente automatisch in das Verzeichnis /var/scan hochlädt. Jede Konfigurations­option und jeder Testschritt wird dabei erklärt, um Fehlerquellen frühzeitig zu erkennen und zu beheben.

Abschnitt Inhalt:

1. Anlegen des Scanner-Users ohne Shell-Zugriff
2. Einrichten und Vergabe von Verzeichnisrechten
3. Installation und Basiskonfiguration von vsftpd
4. Aktivierung des passiven Modus für FTP
5. Logging für Transfers und Authentifizierung
6. Konfiguration der Firewall für Port-Freigaben
7. Dienststart und Verbindungstests aus Client-Sicht
8. Sammlung häufig auftretender Fehlermeldungen und deren Lösungen

Mit diesem Leitfaden kann jeder Administrator Schritt für Schritt nachvollziehen, wie ein stabiler FTP-Zugang für Netzwerkscanner realisiert wird.

## Voraussetzungen

*Hier werden die Systemvoraussetzungen und Installationspakete aufgeführt.*

## Benutzeranlage

*Abschnitt zur Erstellung des FTP-Benutzers.*

## Verzeichnis- und Berechtigungskonfiguration

*Abschnitt zur Einrichtung von `/var/scan` und Rechtemanagement.*

## vsftpd Installation und Grundkonfiguration

*Abschnitt zur Installation von vsftpd und den Basis-Parametern.*

## Passive Mode Einstellungen

*Abschnitt mit `pasv_enable`, Ports und IP.*

## Logging aktivieren

*Abschnitt zur Aktivierung von xferlog und syslog.*

## Firewall-Konfiguration

*Abschnitt zur Freigabe der Ports in ufw oder iptables.*

## Dienststart und Tests

*Abschnitt zu `systemctl restart vsftpd`, `ss`, `nc` und `ftp` Tests.*

## Troubleshooting bekannter Fehler

*Tabellarische Übersicht der häufigsten Fehlermeldungen und Lösungen.*
