# Guestbook with Prometheus & Grafana Monitoring

Extends the [Pulumi Python Guestbook (components)](https://github.com/pulumi/examples/tree/master/kubernetes-py-guestbook/components) with Prometheus and Grafana.

**Estimated time: ~1 hour**

## What gets deployed

| Component | Source |
|-----------|--------|
| Guestbook app | Same as upstream components example (`frontend`, `redis-leader`, `redis-replica`) |
| Prometheus + Grafana | `kube-prometheus-stack` Helm chart |
| Backend metrics | `redis_exporter` sidecar + `ServiceMonitor` on redis services |
| Frontend metrics | Pod CPU/memory (built-in, no custom image needed) |
| Grafana dashboard | Basic dashboard for CPU, memory, and Redis health |

## Prerequisites

- Pulumi, Python 3.9+, kubectl
- A Kubernetes cluster with `kubectl` configured

## Deploy (~15 min setup + ~10 min `pulumi up`)

```bash
cd eks-guestbook-monitoring
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

pulumi stack init dev

# Set true only if using minikube
pulumi config set isMinikube false

pulumi up
```

## Access the app

```bash
# Guestbook UI
pulumi stack output frontend_ip

# macOS
open $(pulumi stack output frontend_ip)
```

**minikube:** `kubectl port-forward svc/frontend 8080:80` then open http://localhost:8080

## Grafana access URL and admin credentials

| | Value |
|--|-------|
| **URL** | See command below (LoadBalancer hostname after deploy) |
| **Username** | `admin` |
| **Password** | `admin` |

```bash
# Get Grafana URL after deploy (wait ~1 min for LoadBalancer)
kubectl get svc -n monitoring kube-prometheus-stack-grafana \
  -o jsonpath='http://{.status.loadBalancer.ingress[0].hostname}'
echo ""

pulumi stack output grafana_admin_user
pulumi stack output grafana_admin_password
```

## Verify metrics are being scraped

### 1. Check pods and ServiceMonitors

```bash
kubectl get pods -n monitoring
kubectl get servicemonitor -n monitoring
kubectl get pods -l app=redis-leader
kubectl get pods -l app=frontend
```

### 2. Open Prometheus and check targets

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
```

Open http://localhost:9090/targets — confirm **redis-leader** and **redis-replica** targets are **UP**.

### 3. Query metrics

In Prometheus (**Graph** tab):

```promql
# Backend (Redis) — scraped via ServiceMonitor
redis_up

# Frontend resource usage — collected automatically by Prometheus
rate(container_cpu_usage_seconds_total{pod=~"frontend-.*", container="frontend"}[5m])
container_memory_working_set_bytes{pod=~"frontend-.*", container="frontend"}
```

### 4. View Grafana dashboard (stretch goal)

1. Open Grafana URL, login with `admin` / `admin`
2. Go to **Dashboards** → **Guestbook Monitoring**
3. Confirm CPU, memory, and Redis panels show data

## Project files

```
├── __main__.py              # Guestbook + monitoring (entry point)
├── service_deployment.py    # Components-based ServiceDeployment
├── monitoring.py              # Helm chart + ServiceMonitors + dashboard
├── dashboards/                # Grafana dashboard JSON
├── Pulumi.yaml
└── requirements.txt
```

## Cleanup

```bash
pulumi destroy
```

## References

- [Pulumi Python Guestbook (components)](https://github.com/pulumi/examples/tree/master/kubernetes-py-guestbook/components)
- [kube-prometheus-stack Helm chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)



  <!-- [Pulumi Neo] Would you like help with these diagnostics?
    https://app.pulumi.com/o-ajayi2k1-gmail-com/eks-guestbook-monitoring/dev/updates/2?explainFailure
    Or run `pulumi neo` for an interactive agent in your terminal.

Outputs:
    frontend_ip           : "aa935387c541f45c289de21e88a0768c-1511400733.us-east-1.elb.amazonaws.com"
    grafana_admin_password: "admin"
    grafana_admin_user    : "admin"
    grafana_service_name  : "kube-prometheus-stack-grafana"
    grafana_url           : "Run after deploy: kubectl get svc -n monitoring kube-prometheus-stack-grafana -o jsonpath='http://{.status.loadBalancer.ingress[0].hostname}'" -->