#!/usr/bin/env bash
set -euo pipefail
kubectl apply -f istio/virtual-service-100-0.yaml
echo "Applied 100% stable / 0% canary routing."
