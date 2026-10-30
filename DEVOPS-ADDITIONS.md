# DevOps additions

The main branch includes:
- GitHub Actions container build and GHCR publishing workflow: .github/workflows/container-ci.yml
- Helm and shell validation workflow: .github/workflows/deployment-validation.yml
- Helm chart: helm/canary-demo/
- Local K3s image build/import/deploy helper: scripts/deploy-local-k3s.sh
- Weighted traffic verification helper: scripts/verify-canary.sh
- Full local runbook: LOCAL-K3S-RUNBOOK.md

## CI/CD
The container workflow builds stable and canary variants. On pushes to main it publishes both to GHCR using the built-in GITHUB_TOKEN. No personal access token is required. Check the Actions tab for the latest workflow result.

## Local K3s deployment
Run bash scripts/deploy-local-k3s.sh from the repository root in the Linux/WSL environment that runs K3s. The script builds Docker images, imports them into K3s containerd, applies Kubernetes and Istio resources, and waits for rollout completion.

Istio itself must already be installed in the cluster. The script does not install or upgrade the Istio control plane.

## Validation
Port-forward the ingress gateway and run bash scripts/verify-canary.sh http://127.0.0.1:8080/ 100. Then run bash scripts/rollback-to-stable.sh and verify stable responses.

## Scope and limitations
GitHub Actions builds and publishes images; it does not connect to a personal laptop's K3s cluster. The local port-forward address is not a public internet URL. Public hosting requires a cloud host/cluster, DNS, firewall configuration and HTTPS. Do not describe local deployment or traffic tests as successful until they have actually been run and verified.