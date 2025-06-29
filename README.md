# NGINX backup shell script

- NGINX configuration (`/etc/nginx`)
- Website files (`/var/www`)
- Let's Encrypt certificates (`/etc/letsencrypt`)

The archive is saved locally and optionally uploaded to a remote storage (e.g. Google Drive) via [rclone](https://rclone.org/). It includes backup rotation (local and remote) and retry mechanism.

---

## Requirements

- Bash (Linux)
- `tar`
- `rclone` properly configured
- Sufficient permissions to read NGINX and Let's Encrypt directories (use `sudo` or run as root)

---

## Features

- Archive of important NGINX files
- Backup rotation (keeps 7 most recent backups locally and remotely)
- Upload to rclone-compatible remote (e.g. Google Drive, S3)
- Fallback: retries upload after 10 minutes if it fails
- Timestamped logs

---

## Usage

```bash
chmod +x backup_nginx.sh
./backup_nginx.sh
