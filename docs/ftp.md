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

In diesem Leitfaden beschreiben wir die vollständige Einrichtung eines passiven FTP-Servers auf einem Ubuntu-Server in einer Proxmox-Umgebung. Ziel ist es, einen dedizierten Scanner-User zu konfigurieren und den Dienst so zu betreiben, dass ein Kyocera Ecosys M5521cdn Netzwerkscanner Dokumente automatisch in das Verzeichnis `/var/scan` hochlädt. Jede Konfigurations­option und jeder Testschritt wird dabei erklärt, um Fehlerquellen frühzeitig zu erkennen und zu beheben.

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

Für den FTP-Zugriff durch den Netzwerkscanner legen wir einen dedizierten Systemuser **`scanner`** an, der **keinen Shell-Zugriff** erhält. Der Home-Ordner wird auf `/var/scan` festgelegt.

1. **User anlegen**

   ```bash
   sudo adduser --home /var/scan --shell /usr/sbin/nologin --disabled-login --gecos "" scanner
   ```

   * `--home /var/scan` definiert das Scan-Verzeichnis als Home.
   * `--shell /usr/sbin/nologin` verhindert Shell-Logins.
   * `--disabled-login` deaktiviert interaktives Login.
   * `--gecos ""` vermeidet die Abfrage von User-Informationen.

2. **Passwort setzen**

   ```bash
   sudo passwd scanner
   ```

   Wähle ein sicheres Passwort und notiere es für die Scanner-Konfiguration.

3. **Überprüfung**

   Stelle sicher, dass der User korrekt angelegt ist:

   ```bash
   id scanner
   ```

   Die Ausgabe sollte etwa lauten:

   ```text
   uid=1001(scanner) gid=1001(scanner) groups=1001(scanner)
   ```

## Verzeichnis- und Berechtigungskonfiguration

Nachdem der Benutzer `scanner` angelegt wurde, richten wir das Scan-Verzeichnis ein und vergeben die notwendigen Berechtigungen.

1. **Verzeichnis anlegen**

   Falls noch nicht vorhanden, erstelle das Verzeichnis `/var/scan`:

   ```bash
   sudo mkdir -p /var/scan
   ```

2. **Eigentümer und Gruppe setzen**

   Setze den Besitz des Verzeichnisses auf den `scanner`-User:

   ```bash
   sudo chown scanner:scanner /var/scan
   ```

3. **Zugriffsrechte festlegen**

   Erlaube dem User Lese-, Schreib- und Ausführungsrechte und beschränke den Zugriff für andere:

   ```bash
   sudo chmod 750 /var/scan
   ```

   * `7` (rwx) für den Eigentümer `scanner`
   * `5` (r-x) für die Gruppe (in der Regel `scanner`)
   * `0` (---) für alle anderen

4. **Testen der Berechtigungen**

   Wechsle zum `scanner`-User und überprüfe den Zugriff:

   ```bash
   sudo -u scanner ls -ld /var/scan
   ```

   Die Ausgabe sollte das Verzeichnis mit Eigentümer `scanner` und den gesetzten Rechten zeigen:

   ```text
   drwxr-x--- 2 scanner scanner 4096 Jun 25 09:30 /var/scan
   ```

## vsftpd Installation und Grundkonfiguration

Um sicherzustellen, dass keine Reste der Standardkonfiguration verbleiben, sichern wir zuerst die mitgelieferte Datei und legen eine komplett neue an.

1. **Backup der Standard‑Config**

   ```bash
   sudo mv /etc/vsftpd.conf /etc/vsftpd.conf.bak
   ```

2. **Neue vsftpd.conf erstellen**

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

   # Passiver Mode
   pasv_enable=YES
   pasv_min_port=40000
   pasv_max_port=40100
   pasv_address=<PASV_ADDRESS>

   # Log-Datei
   xferlog_enable=YES
   log_ftp_protocol=YES
   xferlog_file=/var/log/vsftpd.log
   syslog_enable=YES
   EOF
   ```

3. **Erläuterung der Basis-Parameter**

   * `listen_ipv6=NO` deaktiviert IPv6, um Adresskonflikte zu vermeiden.
   * `listen=YES` aktiviert den Stand-alone-Modus auf IPv4.
   * `anonymous_enable=NO` schaltet anonymen Zugriff aus.
   * `local_enable=YES` erlaubt lokalen Benutzern (z.B. `scanner`) den Login.
   * `write_enable=YES` gewährt Schreibrechte (PUT/STOR).
   * `chroot_local_user=YES` sperrt lokale User in ihr Home-Verzeichnis.
   * `allow_writeable_chroot=YES` erlaubt das Schreiben im Jail.
   * `check_shell=NO` umgeht die Abfrage gültiger Shell in `/etc/shells`.
   * `pam_service_name=vsftpd` stellt sicher, dass die PAM-Regeln geladen werden.
   * `pasv_enable=YES` aktiviert den passiven FTP-Modus.
   * `pasv_min_port` und `pasv_max_port` definieren den Portbereich für Datenverbindungen.
   * `pasv_address` legt die öffentliche Adresse des Servers fest (Platzhalter `<PASV_ADDRESS>`).
   * `xferlog_enable=YES` aktiviert das alte Transfer-Log (`xferlog`).
   * `log_ftp_protocol=YES` protokolliert alle FTP-Kommandos detailliert.
   * `xferlog_file` definiert den Speicherort für das Transfer-Log.
   * `syslog_enable=YES` leitet Meldungen zusätzlich an das System-Journal weiter.

4. **vsftpd installieren**

   ```bash
   sudo apt update
   sudo apt install vsftpd -y
   ```

5. **Konfiguration auf Syntax prüfen**

   ```bash
   sudo /usr/sbin/vsftpd /etc/vsftpd.conf 2>&1 | grep -i oops
   ```

   Es sollten **keine** Meldungen erscheinen. Falls doch, auf ungültige Direktiven prüfen.

## Passive Mode Einstellungen

Im passiven FTP-Modus initiiert der Client die Datenverbindung, was bei Netzwerkscannern hinter NAT oder Firewalls notwendig ist. Wir konfigurieren:

1. **Aktivieren**

   ```ini
   pasv_enable=YES
   ```

2. **Portbereich definieren**

   ```ini
   pasv_min_port=40000
   pasv_max_port=40100
   ```

   * Scanner fordert Datenverbindung an einer Portnummer zwischen 40000 und 40100 an.

3. **Server-Adresse setzen**

   ```ini
   pasv_address=<PASV_ADDRESS>
   ```

   * `<PASV_ADDRESS>` muss die IP oder den Hostnamen sein, unter dem der Scanner den Server erreichen kann.

4. **Firewall öffnen**

   ```bash
   sudo ufw allow 21/tcp
   sudo ufw allow 40000:40100/tcp
   ```

   (oder äquivalente iptables-Befehle)

5. **Testen des passiven Modus**

   * Mit dem klassischen FTP-Client:

     ```bash
     ftp -p <PASV_ADDRESS>
     Name: scanner
     Password: *****
     ftp> passive
     Passive mode on.
     ftp> ls
     ```
   * Mit lftp:

     ```bash
     lftp -u scanner,***** -e "set ftp:passive-mode on; ls; bye" <PASV_ADDRESS>
     ```

Die Logs (siehe Abschnitt Logging aktivieren) zeigen das Kommando `PASV` und darauf folgende `227 Entering Passive Mode (...)`-Antworten.

Um FTP-Transfers und Authentifizierungsmeldungen detailliert zu protokollieren, konfigurieren wir:

1. **Transfer-Log (xferlog) aktivieren**

   ```ini
   xferlog_enable=YES
   xferlog_file=/var/log/vsftpd.log
   ```

2. **Detaillierte FTP-Protokolle**

   ```ini
   log_ftp_protocol=YES
   syslog_enable=YES
   ```

3. **Log-Datei erstellen und Berechtigungen setzen**

   ```bash
   sudo touch /var/log/vsftpd.log
   sudo chown root:root /var/log/vsftpd.log
   sudo chmod 600 /var/log/vsftpd.log
   ```

4. **Echtzeit-Log-Überwachung**

   * **Transfer-Log:**

     ```bash
     sudo tail -f /var/log/vsftpd.log
     ```
   * **Systemd-Journal:**

     ```bash
     sudo journalctl -u vsftpd -f
     ```

5. **Authentifizierungs-Log (PAM)**

   ```bash
   sudo journalctl _COMM=vsftpd -f
   ```

## Firewall-Konfiguration

Damit eingehende FTP-Verbindungen (Port 21) und der passive Port-Bereich (40000–40100) vom Netzwerkscanner zugelassen werden, passen wir die Firewall entsprechend an.

1. **Status prüfen**  
   ```bash
   sudo ufw status verbose
   ```

2. **FTP-Port freigeben**
    ```bash
    sudo ufw allow 21/tcp comment "FTP control port"
    ```

3. **Passiven Port-Bereich freigeben**
    ```bash
    sudo ufw allow 40000:40100/tcp comment "FTP passive ports"
    ```

4. **Änderungen übernehmen**
    ```bash
    sudo ufw reload
    ```

5. **Erneut Status prüfen**
    ```bash
    sudo ufw status numbered
    ```

### iptables (Fallback)
Falls keine UFW verwendet wird, kann man die Regeln auch direkt mit `iptables` setzen:
```bash
# Erlaube FTP-Kontroll-Verkehr
sudo iptables -A INPUT -p tcp --dport 21 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT

# Erlaube passiven Datenverkehr
sudo iptables -A INPUT -p tcp --dport 40000:40100 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT

# Erlaube Antwortverkehr
sudo iptables -A OUTPUT -p tcp --sport 21 -m conntrack --ctstate ESTABLISHED -j ACCEPT
sudo iptables -A OUTPUT -p tcp --sport 40000:40100 -m conntrack --ctstate ESTABLISHED -j ACCEPT
 ```

> [!NOTE]
>
> Um die Regeln nach einem Neustart beizubehalten, nutzt man z. B. iptables-persistent:
```bash
sudo apt install iptables-persistent
sudo netfilter-persistent save
```

### Test der Firewall-Einstellungen
1. **Lokaler Test**
    ```bash
    sudo ss -tulpen | grep :21
    sudo ss -tulpen | grep 40000
    ```
2. **Remote Port-Scan** (von der Scanner-IP)
    ```bash
    nc -vz 192.168.178.201 21
    nc -vz 192.168.178.201 40000
    ```
3. **FTP-Verbindung testen**
    ```bash
    ftp -p 192.168.178.201
    # oder mit lftp:
    lftp -u scanner,<PASSWORT> -e "set ftp:passive-mode on; ls; bye" 192.168.178.201
    ```
Mit dieser Konfiguration kann der Scanner sowohl den Steuer­kanal über Port 21 als auch den passiven Daten­kanal im Port­bereich 40000–40100 erfolgreich nutzen.

## Dienststart und Tests

*Abschnitt zu `systemctl restart vsftpd`, `ss`, `nc` und `ftp` Tests.*

## Troubleshooting bekannter Fehler

| Fehlermeldung                                          | Ursache                                                             | Lösung                                                                                                                                         |
|--------------------------------------------------------|---------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------|
| `500 OOPS: unrecognised variable in config file: X`    | Ungültige Direktive in `/etc/vsftpd.conf`                           | Konfigurationsdatei auf Tippfehler prüfen und nur unterstützte Parameter verwenden (siehe offizielle Doku).                                      |
| `500 OOPS: both local and anonymous access disabled!`  | `anonymous_enable=NO` und `local_enable=NO`                         | `local_enable=YES` in vsftpd.conf setzen, damit lokale User (z. B. `scanner`) sich anmelden dürfen.                                              |
| `530 Login incorrect.`                                 | Falsches Passwort oder PAM/Shell-Check                              | Passwort für `scanner` neu setzen; `check_shell=NO` aktivieren oder `/usr/sbin/nologin` zu `/etc/shells` hinzufügen; PAM-Service-Name prüfen.    |
| `Connection refused`                                   | vsftpd nicht aktiv oder Port blockiert                              | `systemctl status vsftpd` prüfen; mit `ss -tulpen | grep :21` sicherstellen, dass Port 21 lauscht; Firewall-Regeln für Port 21 und 40000–40100 prüfen. |
| Keine Logging-Einträge in `/var/log/vsftpd.log`        | Logging-Optionen nicht aktiviert                                    | `xferlog_enable=YES`, `log_ftp_protocol=YES` und `syslog_enable=YES` in vsftpd.conf setzen; Logfile anlegen und mit `chmod 600` schützen.        |
| `500 OOPS: could not bind listening IPv4 socket`       | Port 21 bereits belegt (z. B. durch Test-Dienst)                    | Dienst stoppen (`systemctl stop vsftpd`), Debug-Modus beenden oder anderen Port verwenden; danach `systemctl start vsftpd` erneut.               |
| `530 Refusing to run with writable root inside chroot()`| `chroot_local_user=YES` ohne sichere Jail-Berechtigungen            | `allow_writeable_chroot=YES` setzen oder Home-Verzeichnis für `scanner` außerhalb von `/` anlegen.                                               |

