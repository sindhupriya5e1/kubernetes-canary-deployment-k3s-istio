# Kubernetes-Based Canary Deployment with K3s and Istio

A hands-on DevOps project that deploys two versions of a Node.js application to Kubernetes and gradually routes traffic with Istio.

## Architecture
- Application: Node.js HTTP app with / and /health endpoints
- Containerization: Docker images for stable and canary versions
- Orchestration: K3s / Kubernetes Deployments and Services
- Service mesh: Istio Gateway, DestinationRule and VirtualService
- Progressive delivery: 80% stable / 20% canary weighted traffic
- Rollback: switch traffic to 100% stable
- CI/CD: GitHub Actions builds and publishes both images to GitHub Container Registry (GHCR)
- Packaging: Helm chart for repeatable workload installation

## Repository structure
| Path | Purpose |
|---|---|
| app/ | Node.js demo application and health endpoint |
| docker/ | Dockerfile for stable/canary images |
| k8s/ | Namespace, Deployments, Services and Istio Gateway |
| istio/ | DestinationRule and 80/20 + 100/0 VirtualServices |
| helm/canary-demo/ | Helm chart for stable and canary workloads |
| scripts/ | Build, deploy, traffic verification and rollback scripts |
| monitoring/ | Prometheus ServiceMonitor, Grafana dashboard and setup guide |
| .github/workflows/ | Container build/publish and Helm/shell validation workflows |
| LOCAL-K3S-RUNBOOK.md | Step-by-step local deployment guide |

## CI/CD pipeline
On pushes to main, GitHub Actions builds the stable and canary Docker images and publishes both tags to GHCR:
- ghcr.io/sindhupriya5e1/kubernetes-canary-deployment-k3s-istio:stable
- ghcr.io/sindhupriya5e1/kubernetes-canary-deployment-k3s-istio:canary

The deployment validation workflow checks Helm chart rendering and shell script syntax when deployment files change. Check [GitHub Actions runs](https://github.com/sindhupriya5e1/kubernetes-canary-deployment-k3s-istio/actions) for the latest result. GHCR packages may need to be made public in GitHub → Packages before a cluster can pull them without credentials.

## Run locally on K3s
The local deployment script builds images and imports them into K3s containerd, so it does not depend on GHCR:
```bash
bash scripts/deploy-local-k3s.sh
```

Requirements: K3s, Docker, kubectl, and an already-installed Istio control plane/ingress gateway. Run this script inside the Linux/WSL environment where K3s is installed.

Open the ingress gateway in terminal 1:
```bash
kubectl -n istio-system port-forward svc/istio-ingressgateway 8080:80
```

In terminal 2, check the app and sample the weighted traffic:
```bash
curl http://127.0.0.1:8080/health
curl http://127.0.0.1:8080/
bash scripts/verify-canary.sh http://127.0.0.1:8080/ 100
```

The sample should trend toward 80/20 over enough requests. Weighted routing is probabilistic, so an individual sample is not guaranteed to be exactly 80/20.

## Prometheus + Grafana monitoring

The app exposes Prometheus request metrics at `/metrics`. Install the monitoring stack and apply the ServiceMonitor and Grafana dashboard manifests by following [monitoring/README.md](monitoring/README.md). The dashboard tracks request rates, version split and HTTP errors for stable/canary.

## Rollback
```bash
bash scripts/rollback-to-stable.sh
bash scripts/verify-canary.sh http://127.0.0.1:8080/ 30
```

Restore the canary split:
```bash
kubectl apply -f istio/virtual-service-80-20.yaml
```

## Helm
Lint and render:
```bash
helm lint ./helm/canary-demo
helm template canary-demo ./helm/canary-demo
```

Install the workloads:
```bash
helm upgrade --install canary-demo ./helm/canary-demo --create-namespace
```

The chart installs the stable/canary workloads and their Services. Apply the Istio routing resources separately:
```bash
kubectl label namespace canary-demo istio-injection=enabled --overwrite
kubectl apply -f k8s/gateway.yaml
kubectl apply -f istio/destination-rule.yaml
kubectl apply -f istio/virtual-service-80-20.yaml
```

## Troubleshooting and full instructions
See [LOCAL-K3S-RUNBOOK.md](LOCAL-K3S-RUNBOOK.md) for prerequisites, commands, verification, rollback and troubleshooting.

## Important deployment note
The local port-forward URL http://127.0.0.1:8080 is accessible from your computer while port-forward is running. It is not a public website URL. A public URL requires a reachable cloud host/Kubernetes cluster, DNS, firewall configuration and HTTPS.

Do not claim a live deployment has been validated until the application has been deployed and traffic/rollback tests have been run against the target cluster.

## Resume bullet (after successful live validation)
Implemented a Kubernetes canary deployment using K3s and Istio, automated Docker image build and publishing with GitHub Actions, configured 80/20 weighted traffic routing, and documented health checks and rollback procedures.