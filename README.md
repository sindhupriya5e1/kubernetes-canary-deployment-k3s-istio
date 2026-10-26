# Kubernetes-Based Canary Deployment with K3s and Istio

A hands-on learning project demonstrating two versions of a Node.js web app on Kubernetes with Istio weighted routing: 80% stable and 20% canary.

## Stack
- K3s / Kubernetes
- Docker
- Node.js
- Istio Gateway, DestinationRule and VirtualService
- Bash scripts

## Project structure
- `app/`: small HTTP app with version and health endpoints
- `docker/`: container image definition
- `k8s/`: namespace, deployments, services and gateway
- `istio/`: weighted routing and 100% stable rollback manifests
- `scripts/`: build, deploy, test and rollback helpers

## Prerequisites
Docker, kubectl, a working Kubernetes/K3s cluster, Istio installed in that cluster, and curl. Istio installation and gateway service names can differ by environment; follow the official Istio install guide for your cluster.

## 1. Build images
Run from repository root:
```bash
docker build -f docker/Dockerfile -t canary-demo:stable --build-arg APP_VERSION=stable .
docker build -f docker/Dockerfile -t canary-demo:canary --build-arg APP_VERSION=canary .
```
For local K3s, import images into its containerd store:
```bash
docker save canary-demo:stable -o canary-demo-stable.tar
docker save canary-demo:canary -o canary-demo-canary.tar
sudo k3s ctr images import canary-demo-stable.tar
sudo k3s ctr images import canary-demo-canary.tar
```
For a remote cluster, push images to a registry and update image names in the deployment YAML.

## 2. Deploy
Ensure Istio is installed first, then:
```bash
kubectl apply -f k8s/namespace.yaml
kubectl label namespace canary-demo istio-injection=enabled --overwrite
kubectl apply -f k8s/
kubectl apply -f istio/destination-rule.yaml
kubectl apply -f istio/virtual-service-80-20.yaml
kubectl rollout status deployment/stable-app -n canary-demo
kubectl rollout status deployment/canary-app -n canary-demo
```

## 3. Test
Check resources:
```bash
kubectl get pods,svc -n canary-demo
kubectl get gateway,virtualservice,destinationrule -n canary-demo
```
Port-forward the Istio ingress gateway (service name may vary):
```bash
kubectl -n istio-system port-forward svc/istio-ingressgateway 8080:80
```
In another terminal, send many requests:
```bash
bash scripts/test-traffic.sh http://127.0.0.1:8080/ 100
```
Responses include the selected app version. A 100-request sample should trend toward 80/20; small samples are not guaranteed to match exactly.

## 4. Roll back
```bash
bash scripts/rollback-to-stable.sh
```
To restore the canary experiment, reapply `istio/virtual-service-80-20.yaml`.

## Troubleshooting
- **ImagePullBackOff:** import images into the cluster runtime or use a registry.
- **No ingress traffic:** verify gateway service name, gateway selector and port-forward.
- **Istio resources missing:** confirm Istio CRDs are installed.
- **No sidecars:** enable injection and restart/recreate application pods.
- **Unexpected routing:** inspect resources and run `istioctl analyze -n canary-demo`.

## Portfolio evidence
Capture screenshots of pods/services, the 80/20 VirtualService, and sample responses from both versions. Only describe the deployment as completed after you run and validate it.

## Resume bullet (after successful testing)
Implemented a Kubernetes canary deployment using K3s and Istio, configured weighted traffic routing between stable and canary versions, and documented rollout validation and rollback procedures.
