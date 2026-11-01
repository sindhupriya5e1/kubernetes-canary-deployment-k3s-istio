#!/usr/bin/env bash
set -Eeuo pipefail

# Staged canary promotion with automatic rollback on failed health checks.
NAMESPACE="${NAMESPACE:-canary-demo}"
VIRTUAL_SERVICE="${VIRTUAL_SERVICE:-canary-demo}"
CLIENT_POD="${CLIENT_POD:-test-client}"
CANARY_HEALTH_URL="${CANARY_HEALTH_URL:-http://canary-app.${NAMESPACE}.svc.cluster.local/health}"
CHECKS_PER_STAGE="${CHECKS_PER_STAGE:-5}"
SLEEP_SECONDS="${SLEEP_SECONDS:-2}"

# Example: KUBECTL_CMD="sudo k3s kubectl" bash scripts/auto-promote-canary.sh
read -r -a KUBECTL <<< "${KUBECTL_CMD:-kubectl}"

if ! [[ "$CHECKS_PER_STAGE" =~ ^[1-9][0-9]*$ ]] || ! [[ "$SLEEP_SECONDS" =~ ^[0-9]+$ ]]; then
  echo "CHECKS_PER_STAGE must be positive and SLEEP_SECONDS must be zero or greater." >&2
  exit 2
fi

kubectl_cmd() { "${KUBECTL[@]}" "$@"; }

set_weights() {
  local stable_weight="$1" canary_weight="$2"
  echo "Setting traffic weights: stable=${stable_weight}% canary=${canary_weight}%"
  kubectl_cmd patch virtualservice "$VIRTUAL_SERVICE" -n "$NAMESPACE" --type=merge \
    -p "{\"spec\":{\"http\":[{\"route\":[{\"destination\":{\"host\":\"canary-demo.${NAMESPACE}.svc.cluster.local\",\"subset\":\"stable\"},\"weight\":${stable_weight}},{\"destination\":{\"host\":\"canary-demo.${NAMESPACE}.svc.cluster.local\",\"subset\":\"canary\"},\"weight\":${canary_weight}}]}]}}"
}

rollback() {
  echo "Health check failed. Rolling back to 100% stable..." >&2
  set_weights 100 0
  echo "Rollback complete: stable=100%, canary=0%." >&2
}

health_check() {
  local stage="$1" response
  echo "Checking canary health at stage ${stage}..."
  for attempt in $(seq 1 "$CHECKS_PER_STAGE"); do
    if ! response="$(kubectl_cmd exec "$CLIENT_POD" -n "$NAMESPACE" -- curl -fsS --connect-timeout 3 --max-time 5 "$CANARY_HEALTH_URL" 2>/dev/null)"; then
      echo "Health request ${attempt}/${CHECKS_PER_STAGE} failed." >&2
      return 1
    fi
    if ! grep -q '"status":"ok"' <<< "$response"; then
      echo "Unexpected canary health response: $response" >&2
      return 1
    fi
    echo "  Check ${attempt}/${CHECKS_PER_STAGE}: healthy"
    sleep "$SLEEP_SECONDS"
  done
}

echo "Starting staged canary promotion in namespace $NAMESPACE."
echo "Canary health endpoint: $CANARY_HEALTH_URL"

if ! kubectl_cmd rollout status deployment/stable-app -n "$NAMESPACE" --timeout=60s ||
   ! kubectl_cmd rollout status deployment/canary-app -n "$NAMESPACE" --timeout=60s; then
  rollback
  exit 1
fi

set_weights 80 20
if ! health_check "80/20"; then rollback; exit 1; fi
set_weights 50 50
if ! health_check "50/50"; then rollback; exit 1; fi
set_weights 0 100
if ! health_check "0/100"; then rollback; exit 1; fi

echo "Promotion successful: canary is now receiving 100% of traffic."
echo "This is a one-shot health-endpoint check, not a continuous metrics controller."
