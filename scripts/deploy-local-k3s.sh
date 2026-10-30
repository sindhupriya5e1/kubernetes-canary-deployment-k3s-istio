#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

for cmd in docker kubectl; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "ERROR: $cmd is required and must be on PATH."; exit 1; }
done
command -v k3s >/dev/null 2>&1 || { echo "ERROR: k3s CLI not found. Run this script inside the Linux/WSL environment where K3s is installed."; exit 1; }

echo "[1/6] Checking Kubernetes cluster"
kubectl get nodes

echo "[2/6] Building stable and canary Docker images"
docker build -f docker/Dockerfile -t canary-demo:stable --build-arg APP_VERSION=stable .
docker build -f docker/Dockerfile -t canary-demo:canary --build-arg APP_VERSION=canary .

echo "[3/6] Importing images into the K3s containerd image store"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
docker save canary-demo:stable -o "$TMP_DIR/stable.tar"
docker save canary-demo:canary -o "$TMP_DIR/canary.tar"
sudo k3s ctr images import "$TMP_DIR/stable.tar"
sudo k3s ctr images import "$TMP_DIR/canary.tar"

echo "[4/6] Enabling Istio sidecar injection and applying Kubernetes resources"
kubectl apply -f k8s/namespace.yaml
kubectl label namespace canary-demo istio-injection=enabled --overwrite
kubectl apply -f k8s/
kubectl rollout restart deployment/stable-app deployment/canary-app -n canary-demo

echo "[5/6] Applying Istio 80/20 traffic routing"
kubectl apply -f istio/destination-rule.yaml
kubectl apply -f istio/virtual-service-80-20.yaml

echo "[6/6] Waiting for application pods"
kubectl rollout status deployment/stable-app -n canary-demo --timeout=180s
kubectl rollout status deployment/canary-app -n canary-demo --timeout=180s
kubectl get pods,svc -n canary-demo
kubectl get gateway,virtualservice,destinationrule -n canary-demo

echo
echo "Deployment applied. Next, run:"
echo "  kubectl -n istio-system port-forward svc/istio-ingressgateway 8080:80"
echo "Then in another terminal:"
echo "  bash scripts/verify-canary.sh http://127.0.0.1:8080/ 100"
