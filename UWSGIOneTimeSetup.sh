#!/usr/bin/env bash
set -euo pipefail

# One-time uWSGI/Nginx prep for TurboNursey
# - Creates dedicated socket dir (/run/nhs)
# - Sets permissions/ownership
# - Installs uWSGI ini and Nginx site via rake tasks (run as root)
#
# Usage:
#   sudo bash scripts/uwsgi_one_time_setup.sh
#
# Optional env:
#   APP_DIR=/var/www/TurboNursey/code
#   UWSGI_UID=www-data
#   UWSGI_GID=www-data

APP_DIR="${APP_DIR:-/var/www/TurboNursey/code}"
UWSGI_UID="${UWSGI_UID:-$(id -un)}"
UWSGI_GID="${UWSGI_GID:-$(id -gn)}"

echo "[1/4] Ensuring socket directory"
mkdir -p /run/nhs
chown "${UWSGI_UID}:${UWSGI_GID}" /run/nhs
chmod 775 /run/nhs

echo "[2/4] Removing any stale socket"
rm -f /run/nhs/nhs.sock || true

echo "[3/4] Installing uWSGI ini (via rake)"
cd "$APP_DIR"
# Export desired uid/gid for the uWSGI ini
export UWSGI_UID UWSGI_GID
if ! command -v rake >/dev/null 2>&1; then
  echo "rake not found. Install Ruby/Bundler and run bundle install first."
  exit 1
fi
# Rake tasks write /etc/uwsgi/apps-available/nhs.ini and enable it
rake uwsgi_install

echo "[4/4] Installing Nginx site (via rake)"
rake nginx_install

echo "Done. Next steps (non-root):"
echo "  rake start"
echo "Then reload Nginx if needed (root):"
echo "  nginx -t && service nginx reload"
