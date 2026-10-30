# Prometheus + Grafana monitoring

This setup uses the Prometheus Community `kube-prometheus-stack` Helm chart. It installs Prometheus, Grafana, Alertmanager, and the Kubernetes monitoring components into the `monitoring` namespace.

## 1. Install the monitoring stack

Run from the Linux/WSL terminal that has access to your K3s cluster:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false
```

Wait until the pods are ready:

```bash
kubectl get pods -n monitoring
```

## 2. Rebuild and deploy the app with its metrics endpoint

The Node.js app exposes Prometheus counters at `/metrics`. Rebuild the local images and apply the Kubernetes manifests:

```bash
bash scripts/deploy-local-k3s.sh
```

Check one app metrics endpoint (the service may route to either version):

```bash
kubectl -n canary-demo port-forward svc/stable-app 3000:80
curl http://127.0.0.1:3000/metrics
```

Generate some traffic in another terminal:

```bash
for i in $(seq 1 50); do curl -s http://127.0.0.1:3000/ >/dev/null; done
curl -s http://127.0.0.1:3000/metrics
```

## 3. Register the app with Prometheus and provision the dashboard

```bash
kubectl apply -f monitoring/canary-service-monitor.yaml
kubectl apply -f monitoring/grafana-dashboard.yaml
```

Prometheus discovers the stable and canary Services in the `canary-demo` namespace through the ServiceMonitor. The app exposes request counters with version, method, and status labels.

## 4. Open Grafana

```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3001:80
```

Open http://127.0.0.1:3001. The default chart credentials are username `admin` and password `prom-operator` unless changed during installation. Change the password before exposing Grafana beyond localhost.

Open **Dashboards → K3s Istio Canary Demo**. It includes:
- HTTP requests per second by stable/canary version
- Total requests by version
- HTTP 4xx/5xx response rates

## 5. Check Prometheus target health

```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090:9090
```

Open http://127.0.0.1:9090/targets and confirm the `canary-demo` ServiceMonitor targets are UP.

## Notes

- The request counters are in-memory and reset when an app pod restarts; they are for this demo, not durable business analytics.
- The dashboard shows observed request counts, not a guarantee that every short sample is exactly 80/20. Istio weighted routing is probabilistic.
- This monitoring stack is not installed on your laptop by committing these files. You must run the Helm and kubectl commands above against your K3s cluster.
- Keep Grafana and Prometheus bound to localhost via port-forward for local practice. Do not expose unauthenticated monitoring endpoints publicly.
