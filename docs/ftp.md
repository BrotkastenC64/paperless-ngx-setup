# FTP-Konfiguration für Netzwerkscanner

Dieses Dokument beschreibt die vollständige Einrichtung eines passiven FTP-Servers (`vsftpd`) auf einem Ubuntu-Server (getestet mit Ubuntu 24.04 LTS) unter Proxmox, um Dokumente von einem Kyocera Ecosys M5521cdn Netzwerkscanner automatisch in das Verzeichnis `/var/scan` hochzuladen.

## Inhaltsverzeichnis

1. [Einleitung](#einleitung)
2. [Voraussetzungen](#voraussetzungen)
3. [Benutzeranlage](#benutzeranlage)
4. [Verzeichnis- und Berechtigungskonfiguration](#verzeichnis--und-berechtigungskonfiguration)
5. [Installation und Grundkonfiguration von vsftpd](#installation-und-grundkonfiguration-von-vsftpd)
6. [Passive Mode konfigurieren](#passive-mode-konfigurieren)
7. [Logging aktivieren](#logging-aktivieren)
8. [Firewall konfigurieren](#firewall-konfigurieren)
9. [Dienststart und Tests](#dienststart-und-tests)
10. [Troubleshooting](#troubleshooting)

---

## Einleitung

Ziel dieser Anleitung ist ein stabiler und sicherer FTP-Server, der speziell für Netzwerkscanner eingerichtet ist. Alle notwendigen Konfigurationsschritte, Tests und mögliche Fehlerlösungen werden beschrieben.

## Voraussetzungen

* Ubuntu Server (empfohlen: 24.04 LTS)
* Statische IP-Adresse empfohlen
* Installierte Pakete:

```bash
sudo apt update
sudo apt install vsftpd ufw ftp lftp -y
```

## Benutzeranlage

Erstelle den dedizierten Benutzer `scanner` ohne Shell-Zugriff:

```bash
sudo adduser --home /var/scan --shell /usr/sbin/nologin --disabled-login --gecos "" scanner
sudo passwd scanner
```

Überprüfung:

```bash
id scanner
```

## Verzeichnis- und Berechtigungskonfiguration

Erstelle und berechtige das Scan-Verzeichnis:

```bash
sudo mkdir -p /var/scan
sudo chown scanner:scanner /var/scan
sudo chmod 750 /var/scan
```

Testen:

```bash
sudo -u scanner ls -ld /var/scan
```

## Installation und Grundkonfiguration von vsftpd

Backup der Originalkonfiguration:

```bash
sudo mv /etc/vsftpd.conf /etc/vsftpd.conf.bak
```

Neue Konfiguration erstellen (ersetze `<PASV_ADDRESS>` durch deine Server-IP, z.B. `192.168.178.201`):

```bash
sudo tee /etc/vsftpd.conf > /dev/null <<EOF
listen_ipv6=NO
listen=YES

anonymous_enable=NO
local_enable=YES
write_enable=YES
chroot_local_user=YES
allow_writeable_chroot=YES
check_shell=NO
pam_service_name=vsftpd

pasv_enable=YES
pasv_min_port=40000
pasv_max_port=40100
pasv_address=<PASV_ADDRESS>

xferlog_enable=YES
log_ftp_protocol=YES
xferlog_file=/var/log/vsftpd.log
syslog_enable=YES
EOF
```

Prüfung der Konfiguration:

```bash
sudo /usr/sbin/vsftpd /etc/vsftpd.conf 2>&1 | grep -i oops
```

## Passive Mode konfigurieren

Der passive Modus ist bereits in der obigen Konfiguration aktiviert:

```ini
pasv_enable=YES
pasv_min_port=40000
pasv_max_port=40100
pasv_address=<PASV_ADDRESS>
```

## Logging aktivieren

Log-Datei anlegen und schützen:

```bash
sudo touch /var/log/vsftpd.log
sudo chown root:root /var/log/vsftpd.log
sudo chmod 600 /var/log/vsftpd.log
```

Logs überwachen:

```bash
sudo tail -f /var/log/vsftpd.log
sudo journalctl -u vsftpd -f
```

## Firewall konfigurieren

Firewall-Einstellungen vornehmen:

```bash
sudo ufw allow 21/tcp comment "FTP control port"
sudo ufw allow 40000:40100/tcp comment "FTP passive ports"
sudo ufw reload
```

Überprüfung:

```bash
sudo ufw status verbose
```

## Dienststart und Tests

Starte oder starte vsftpd neu und führe Tests durch:

```bash
sudo systemctl restart vsftpd
sudo systemctl status vsftpd
sudo ss -tulpen | grep :21

ftp -p localhost
ftp> passive
ftp> ls
ftp> quit
```

Von einem externen Gerät testen (ersetze `<PASV_ADDRESS>`):

```bash
ftp -p <PASV_ADDRESS>
```

## Troubleshooting

| Fehler                                 | Ursache                             | Lösung                                     |
| -------------------------------------- | ----------------------------------- | ------------------------------------------ |
| `500 OOPS: unrecognised variable`      | Tippfehler in Config                | Parameter prüfen                           |
| `530 Login incorrect`                  | Passwort falsch oder Shell ungültig | Passwort neu setzen, Shell prüfen          |
| `Connection refused`                   | Dienst aus oder Firewall blockiert  | `systemctl status vsftpd`, Firewall prüfen |
| `could not bind listening IPv4 socket` | Port belegt                         | Dienst stoppen, Port prüfen                |
| `writable root inside chroot()`        | Jail-Berechtigungen falsch          | `allow_writeable_chroot=YES` setzen        |