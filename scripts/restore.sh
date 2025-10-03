#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 /path/to/backup-<timestamp>.tgz" >&2
  exit 2
fi
ARCHIVE="$1"
sudo tar -xzf "$ARCHIVE" -C /
sudo systemctl restart nginx || true
# Restart observability stack
if [[ -f /opt/observability/docker-compose.yml ]]; then
  (cd /opt/observability && docker compose up -d)
fi
echo "Restore completed."
