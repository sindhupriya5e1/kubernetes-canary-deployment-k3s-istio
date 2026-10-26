#!/usr/bin/env bash
set -euo pipefail
URL="${1:-http://127.0.0.1:8080/}"
COUNT="${2:-100}"
for _ in $(seq 1 "$COUNT"); do
  curl -fsS "$URL"
  printf '\n'
done
