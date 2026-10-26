#!/usr/bin/env bash
set -euo pipefail
kubectl apply -f k8s/namespace.yaml
kubectl label namespace canary-demo istio-injection=enabled --overwrite
kubectl apply -f k8s/
kubectl apply -f istio/destination-rule.yaml
kubectl apply -f istio/virtual-service-80-20.yaml
kubectl rollout status deployment/stable-app -n canary-demo
kubectl rollout status deployment/canary-app -n canary-demo
kubectl get pods,svc -n canary-demo
