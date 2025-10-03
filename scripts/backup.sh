#!/usr/bin/env bash
set -euo pipefail
TS=$(date +%Y%m%d-%H%M%S)
OUT="/opt/backups/backup-$TS.tgz"

sudo mkdir -p /opt/backups
sudo tar -czf "$OUT" \
  /etc/nginx \
  /var/www/html \
  /opt/observability

echo "Backup created: $OUT"
echo "You can upload it to OCI Object Storage (S3-compat) with rclone or awscli configured to the compat endpoint."
