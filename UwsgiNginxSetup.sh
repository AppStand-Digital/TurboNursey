#!/usr/bin/env bash
set -euo pipefail

# Quick root-side setup for uWSGI + Nginx + socket dir
# Usage: sudo bash scripts/uwsgi_quick_root_setup.sh [APP_USER] [APP_DIR]
# Defaults: APP_USER from SUDO_USER/logname/whoami; APP_DIR=/var/www/TurboNursey/code

APP_USER_ARG="${1:-}"
APP_DIR="${2:-/var/www/TurboNursey/code}"

# Resolve app user
if [ -n "$APP_USER_ARG" ]; then
  APP_USER="$APP_USER_ARG"
else
  APP_USER="$(logname 2>/dev/null || true)"
  [ -z "$APP_USER" ] && APP_USER="${SUDO_USER:-}"
  [ -z "$APP_USER" ] && APP_USER="$(whoami)"
fi

echo "Using APP_USER=$APP_USER"
echo "Using APP_DIR=$APP_DIR"

# 1) Socket directory
mkdir -p /run/nhs
chown "$APP_USER:$APP_USER" /run/nhs
chmod 775 /run/nhs
rm -f /run/nhs/nhs.sock || true

# 2) Install uWSGI ini (system path) and enable site via rake
cd "$APP_DIR"
export UWSGI_UID="$APP_USER" UWSGI_GID="$APP_USER"

if ! command -v rake >/dev/null 2>&1; then
  echo "rake not found. Install Ruby/Bundler and run bundle install first." >&2
  exit 1
fi

echo "Installing uWSGI ini..."
rake uwsgi_install

echo "Installing Nginx site..."
rake nginx_install

echo "Root setup done. Next as $APP_USER:"
echo "  sudo -u \"$APP_USER\" -H bash -lc 'cd \"$APP_DIR\" && bundle install && rake start'"
echo "Then as root:"
echo "  nginx -t && service nginx reload"
