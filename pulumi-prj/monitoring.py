import os

import pulumi
import pulumi_kubernetes as k8s
from pulumi_kubernetes.helm.v3 import Release, RepositoryOptsArgs

GRAFANA_ADMIN_USER = "admin"
GRAFANA_ADMIN_PASSWORD = "admin"
HELM_RELEASE = "kube-prometheus-stack"


def _service_monitor(name: str, app: str, port: str, namespace, depends_on):
    return k8s.apiextensions.CustomResource(
        f"{name}-servicemonitor",
        api_version="monitoring.coreos.com/v1",
        kind="ServiceMonitor",
        metadata={
            "name": name,
            "namespace": namespace,
            "labels": {"release": HELM_RELEASE},
        },
        spec={
            "namespaceSelector": {"matchNames": ["default"]},
            "selector": {"matchLabels": {"app": app}},
            "endpoints": [{"port": port, "path": "/metrics", "interval": "30s"}],
        },
        opts=pulumi.ResourceOptions(depends_on=[depends_on]),
    )


def deploy_monitoring(grafana_service_type: str = "LoadBalancer"):
    monitoring_ns = k8s.core.v1.Namespace("monitoring", metadata={"name": "monitoring"})

    prometheus_stack = Release(
        "kube-prometheus-stack",
        name=HELM_RELEASE,
        chart="kube-prometheus-stack",
        version="65.3.1",
        namespace=monitoring_ns.metadata["name"],
        timeout=900,
        repository_opts=RepositoryOptsArgs(
            repo="https://prometheus-community.github.io/helm-charts",
        ),
        values={
            "prometheus": {
                "prometheusSpec": {
                    "serviceMonitorSelectorNilUsesHelmValues": False,
                },
            },
            "grafana": {
                "adminPassword": GRAFANA_ADMIN_PASSWORD,
                "service": {"type": grafana_service_type},
                "sidecar": {
                    "dashboards": {"enabled": True, "label": "grafana_dashboard"},
                },
            },
        },
        opts=pulumi.ResourceOptions(depends_on=[monitoring_ns]),
    )

    _service_monitor("redis-leader", "redis-leader", "metrics", monitoring_ns.metadata["name"], prometheus_stack)
    _service_monitor("redis-replica", "redis-replica", "metrics", monitoring_ns.metadata["name"], prometheus_stack)

    dashboard_path = os.path.join(os.path.dirname(__file__), "dashboards", "guestbook-dashboard.json")
    with open(dashboard_path, encoding="utf-8") as f:
        dashboard_json = f.read()

    k8s.core.v1.ConfigMap(
        "guestbook-dashboard",
        metadata={
            "name": "guestbook-dashboard",
            "namespace": monitoring_ns.metadata["name"],
            "labels": {"grafana_dashboard": "1"},
        },
        data={"guestbook.json": dashboard_json},
        opts=pulumi.ResourceOptions(depends_on=[prometheus_stack]),
    )

    grafana_service_name = f"{HELM_RELEASE}-grafana"

    return {
        "grafana_service_name": grafana_service_name,
        "grafana_url": pulumi.Output.from_input(
            f"Run after deploy: kubectl get svc -n monitoring {grafana_service_name} "
            "-o jsonpath='http://{.status.loadBalancer.ingress[0].hostname}'"
        ),
        "grafana_admin_user": GRAFANA_ADMIN_USER,
        "grafana_admin_password": GRAFANA_ADMIN_PASSWORD,
    }
