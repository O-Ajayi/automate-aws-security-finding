from typing import Optional, Sequence

import pulumi
from pulumi import ComponentResource, Output, ResourceOptions
from pulumi_kubernetes.apps.v1 import Deployment, DeploymentSpecArgs
from pulumi_kubernetes.core.v1 import (
    ContainerArgs,
    ContainerPortArgs,
    PodSpecArgs,
    PodTemplateSpecArgs,
    ResourceRequirementsArgs,
    Service,
    ServicePortArgs,
    ServiceSpecArgs,
)
from pulumi_kubernetes.meta.v1 import LabelSelectorArgs, ObjectMetaArgs


def _port_name(port: int) -> str:
    if port == 80:
        return "http"
    if port == 6379:
        return "redis"
    if port == 9121:
        return "metrics"
    return f"port-{port}"


class ServiceDeployment(ComponentResource):
    deployment: Deployment
    service: Service
    ip_address: Optional[Output[str]]

    def __init__(
        self,
        name: str,
        image: str,
        resources: Optional[ResourceRequirementsArgs] = None,
        replicas: Optional[int] = None,
        ports: Optional[Sequence[int]] = None,
        allocate_ip_address: Optional[bool] = None,
        is_minikube: Optional[bool] = None,
        redis_exporter: bool = False,
        opts: Optional[ResourceOptions] = None,
    ):
        super().__init__("k8sx:component:ServiceDeployment", name, {}, opts)

        labels = {"app": name}
        containers = [
            ContainerArgs(
                name=name,
                image=image,
                resources=resources
                or ResourceRequirementsArgs(
                    requests={"cpu": "100m", "memory": "100Mi"},
                ),
                ports=(
                    [ContainerPortArgs(container_port=p, name=_port_name(p)) for p in ports]
                    if ports
                    else None
                ),
            )
        ]

        service_ports = list(ports or [])
        pod_annotations = None

        if redis_exporter:
            containers.append(
                ContainerArgs(
                    name="redis-exporter",
                    image="oliver006/redis_exporter:v1.55.0",
                    args=["--redis.addr=redis://localhost:6379"],
                    ports=[ContainerPortArgs(container_port=9121, name="metrics")],
                )
            )
            service_ports.append(9121)
            pod_annotations = {
                "prometheus.io/scrape": "true",
                "prometheus.io/port": "9121",
                "prometheus.io/path": "/metrics",
            }

        self.deployment = Deployment(
            name,
            spec=DeploymentSpecArgs(
                selector=LabelSelectorArgs(match_labels=labels),
                replicas=replicas if replicas is not None else 1,
                template=PodTemplateSpecArgs(
                    metadata=ObjectMetaArgs(
                        labels=labels,
                        annotations=pod_annotations,
                    ),
                    spec=PodSpecArgs(containers=containers),
                ),
            ),
            opts=ResourceOptions(parent=self),
        )

        self.service = Service(
            name,
            metadata=ObjectMetaArgs(
                name=name,
                labels=self.deployment.metadata.apply(lambda m: m.labels),
            ),
            spec=ServiceSpecArgs(
                ports=(
                    [
                        ServicePortArgs(
                            name=_port_name(p),
                            port=p,
                            target_port=p,
                        )
                        for p in service_ports
                    ]
                    if service_ports
                    else None
                ),
                selector=self.deployment.spec.apply(lambda s: s.template.metadata.labels),
                type=(
                    ("ClusterIP" if is_minikube else "LoadBalancer")
                    if allocate_ip_address
                    else None
                ),
            ),
            opts=ResourceOptions(parent=self),
        )

        self.ip_address = None
        if allocate_ip_address:
            if is_minikube:
                self.ip_address = self.service.spec.apply(lambda s: s.cluster_ip)
            else:
                ingress = self.service.status.apply(lambda s: s.load_balancer.ingress[0])
                self.ip_address = ingress.apply(lambda i: i.ip or i.hostname or "")

        self.register_outputs({})
