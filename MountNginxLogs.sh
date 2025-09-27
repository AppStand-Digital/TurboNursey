#!/usr/bin/env bash
# Mount remote nginx logs into ./log/nginx via SSHFS
# Usage: ./mount_nginx_logs.sh [root@firebase.rubystand.io:/var/log/nginx] [./log/nginx]
set -euo pipefail

REMOTE="${1:-root@firebase.rubystand.io:/var/log/nginx}"
MOUNT_POINT="${2:-./log/nginx}"

# Ensure sshfs is installed (auto-install if missing)
if ! command -v sshfs >/dev/null 2>&1; then
  echo "sshfs not found. Installing with apt..."
  sudo apt-get update -y
  sudo apt-get install -y sshfs
fi

# Create mount point
mkdir -p "$MOUNT_POINT"

# If already mounted, unmount first
if mountpoint -q "$MOUNT_POINT"; then
  echo "Already mounted at $MOUNT_POINT. Unmounting..."
  fusermount -u "$MOUNT_POINT" || umount "$MOUNT_POINT" || true
fi

# Mount with useful options:
# -o reconnect,ServerAliveInterval/CountMax: auto-reconnect
# -o follow_symlinks: follow symlinks in remote dir
# -o allow_other (optional): allow other local users to read; needs user_allow_other in /etc/fuse.conf
OPTS=(
  -o reconnect
  -o ServerAliveInterval=15
  -o ServerAliveCountMax=3
  -o follow_symlinks
)
# Uncomment to allow other users locally:
# OPTS+=(-o allow_other)

# Use specific identity file if needed:
# OPTS+=(-o IdentityFile="$HOME/.ssh/id_rsa")

echo "Mounting $REMOTE -> $MOUNT_POINT ..."
sshfs "${OPTS[@]}" "$REMOTE" "$MOUNT_POINT"

echo "Mounted. Tail logs with:"
echo "  tail -f $MOUNT_POINT/access.log $MOUNT_POINT/error.log"
echo "To unmount:"
echo "  fusermount -u \"$MOUNT_POINT\"  # or: umount \"$MOUNT_POINT\""
