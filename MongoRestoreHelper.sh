#!/usr/bin/env bash
set -euo pipefail
# Minimal restore helper: imports all *.jsonl.gz in a backup folder.
# Prereq: mongoimport CLI (free, part of MongoDB Database Tools)
#
# Usage:
#   ./scripts/mongo_restore_small.sh "mongodb://localhost:27017/dbname" "./backups/turbonursey_20250101_120000"

URI="${1:-mongodb://127.0.0.1:27017/turbonursey}"
DIR="${2:-}"

if [ -z "$DIR" ] || [ ! -d "$DIR" ]; then
  echo "Provide backup dir path: ./scripts/mongo_restore_small.sh \"$URI\" \"./backups/<db>_<timestamp>\""
  exit 1
fi

shopt -s nullglob
for f in "$DIR"/*.jsonl.gz; do
  coll="$(basename "$f" .jsonl.gz)"
  echo "Importing $coll from $f"
  gunzip -c "$f" | mongoimport --uri "$URI" --collection "$coll" --drop --type json --mode=upsert --upsertFields _id
done

echo "Restore complete."
