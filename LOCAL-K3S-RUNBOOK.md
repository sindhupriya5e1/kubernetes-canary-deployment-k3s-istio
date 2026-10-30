# Local K3s + Istio live runbook

This runbook deploys the project to the K3s cluster already installed on your machine. Run the Linux commands in the same Linux/WSL environment that owns the K3s service and kubectl context.

## Prerequisites

- K3s is running and the current kubeconfig points to that cluster.
- Docker CLI/daemon is available in this Linux/WSL environment.
- Istio is already installed in the cluster, including its CRDs and ingress gateway.
- `kubectl`, `docker`, `k3s`, `sudo`, and `curl` are available.

Check the cluster first:

```bash
kubectl get nodes
kubectl get pods -n istio-system
kubectl get svc -n istio-system
```

If Istio is not installed, stop here and install a K3s-compatible Istio control plane before deploying this app. The project manifests do not install Istio itself.

## Deploy

From the repository root:

```bash
bash scripts/deploy-local-k3s.sh
```

The script builds both app images, imports them into K3s containerd, enables namespace sidecar injection, applies the Deployments/Services/Gateway, applies the Istio DestinationRule and 80/20 VirtualService, and waits for rollouts.

## Open the local app

Keep this command running in terminal 1:

```bash
kubectl -n istio-system port-forward svc/istio-ingressgateway 8080:80
```

If the ingress service has a different name, find it with `kubectl get svc -n istio-system` and substitute the correct service name.

In terminal 2:

```bash
curl http://127.0.0.1:8080/health
curl http://127.0.0.1:8080/
bash scripts/verify-canary.sh http://127.0.0.1:8080/ 100
```

The traffic test counts the `stable` and `canary` versions returned by the application. 80/20 is a routing probability, not a guarantee that every 100-request sample will be exactly 80 and 20.

## Roll back to stable

```bash
bash scripts/rollback-to-stable.sh
bash scripts/verify-canary.sh http://127.0.0.1:8080/ 30
```

Restore the experiment when needed:

```bash
kubectl apply -f istio/virtual-service-80-20.yaml
```

## Troubleshooting

| Symptom | Check |
|---|---|
| `ImagePullBackOff` | `sudo k3s ctr images list | grep canary-demo`; rebuild/import images |
| Pods have no sidecar | `kubectl get pods -n canary-demo`; confirm namespace injection label and restart pods |
| Pods not Ready | `kubectl describe pod -n canary-demo <pod-name>` and `kubectl logs -n canary-demo <pod-name> -c app` |
| Istio objects rejected | `kubectl get crd | grep networking.istio.io`; confirm Istio is installed |
| No ingress response | `kubectl get svc,pods -n istio-system`; confirm ingress gateway is ready and port-forward uses its actual service name |

## Local versus public URL

Port-forwarding exposes the app on your own computer at `http://127.0.0.1:8080` only while the command is running. It is not a public internet URL. To publish this app publicly, deploy it to a reachable cloud VM/Kubernetes cluster and configure DNS, firewall rules, and HTTPS. Do not expose the K3s API server publicly.
