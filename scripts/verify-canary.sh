#!/usr/bin/env bash
set -euo pipefail

URL="${1:-http://127.0.0.1:8080/}"
COUNT="${2:-100}"
STABLE=0
CANARY=0
UNKNOWN=0

if ! [[ "$COUNT" =~ ^[1-9][0-9]*$ ]]; then
  echo "Usage: $0 [URL] [positive-request-count]"
  exit 2
fi

echo "Sending $COUNT requests to $URL"
for _ in $(seq 1 "$COUNT"); do
  BODY="$(curl --connect-timeout 3 --max-time 10 -fsS "$URL")" || {
    echo "Request failed. Check the ingress port-forward and pod status."
    exit 1
  }
  if grep -q '"version":"stable"' <<<"$BODY"; then
    STABLE=$((STABLE + 1))
  elif grep -q '"version":"canary"' <<<"$BODY"; then
    CANARY=$((CANARY + 1))
  else
    UNKNOWN=$((UNKNOWN + 1))
  fi
done

echo "Stable: $STABLE / $COUNT ($((STABLE * 100 / COUNT))%)"
echo "Canary: $CANARY / $COUNT ($((CANARY * 100 / COUNT))%)"
if [ "$UNKNOWN" -gt 0 ]; then
  echo "Unknown responses: $UNKNOWN"
fi
echo "Note: weighted routing is probabilistic; a small sample may not be exactly 80/20."
