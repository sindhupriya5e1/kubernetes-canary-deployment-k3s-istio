# Automatic canary promotion and rollback

This project includes a staged promotion script that checks the canary application health endpoint before increasing traffic.

## What it does

1. Waits for the stable and canary Deployments to become Ready.
2. Sets Istio traffic to 80% stable / 20% canary.
3. Sends repeated health requests directly to the canary Service.
4. If healthy, increases traffic to 50/50 and checks again.
5. If still healthy, promotes canary to 100% traffic.
6. If any health request fails, patches the VirtualService to 100% stable / 0% canary and exits with an error.

The probe runs from the in-cluster test-client pod against the canary-app Service health endpoint. It uses the canary-demo VirtualService and its stable/canary DestinationRule subsets.

## Run on local K3s

Run from the repository root:

```bash
KUBECTL_CMD="sudo k3s kubectl" bash scripts/auto-promote-canary.sh
```

Optional settings:

```bash
KUBECTL_CMD="sudo k3s kubectl" CHECKS_PER_STAGE=10 SLEEP_SECONDS=3 bash scripts/auto-promote-canary.sh
```

## Verify the result

```bash
sudo k3s kubectl get virtualservice canary-demo -n canary-demo -o yaml
sudo k3s kubectl exec test-client -n canary-demo -- curl -fsS http://canary-app.canary-demo.svc.cluster.local/health
```

After successful promotion, the VirtualService should show stable weight 0 and canary weight 100.

## Test rollback safely

Only test this in a disposable local environment. Point the health probe at an invalid path; the app responds with HTTP 404, causing the script to restore 100% stable traffic:

```bash
KUBECTL_CMD="sudo k3s kubectl" CANARY_HEALTH_URL="http://canary-app.canary-demo.svc.cluster.local/not-a-health-endpoint" bash scripts/auto-promote-canary.sh
```

Confirm the VirtualService weights afterwards.

## Scope and production note

This is a one-shot, health-endpoint-based promotion script. It does not continuously monitor Prometheus error rates, latency, or business metrics. Production-grade progressive delivery should use a controller such as Argo Rollouts with metric analysis and explicit approval/rollback policies.
