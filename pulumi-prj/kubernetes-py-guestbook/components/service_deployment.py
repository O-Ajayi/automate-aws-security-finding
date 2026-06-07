from typing import Sequence

import pulumi
from pulumi import ResourceOptions, ComponentResource, Output
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


class ServiceDeployment(ComponentResource):
    deployment: Deployment
    service: Service
    ip_address: Output[str]

    def __init__(
        self,
        name: str,
        image: str,
        resources: ResourceRequirementsArgs = None,
        replicas: int = None,
        ports: Sequence[int] = None,
        allocate_ip_address: bool = None,
        is_minikube: bool = None,
        opts: ResourceOptions = None,
    ):
        super().__init__("k8sx:component:ServiceDeployment", name, {}, opts)

        labels = {"app": name}
        container = ContainerArgs(
            name=name,
            image=image,
            resources=resources
            or ResourceRequirementsArgs(
                requests={"cpu": "100m", "memory": "100Mi"},
            ),
            ports=([ContainerPortArgs(container_port=p) for p in ports] if ports else None),
        )
        self.deployment = Deployment(
            name,
            spec=DeploymentSpecArgs(
                selector=LabelSelectorArgs(match_labels=labels),
                replicas=replicas if replicas is not None else 1,
                template=PodTemplateSpecArgs(
                    metadata=ObjectMetaArgs(labels=labels),
                    spec=PodSpecArgs(containers=[container]),
                ),
            ),
            opts=pulumi.ResourceOptions(parent=self),
        )
        self.service = Service(
            name,
            metadata=ObjectMetaArgs(
                name=name,
                labels=self.deployment.metadata.apply(lambda m: m.labels),
            ),
            spec=ServiceSpecArgs(
                ports=([ServicePortArgs(port=p, target_port=p) for p in ports] if ports else None),
                selector=self.deployment.spec.apply(lambda s: s.template.metadata.labels),
                type=(
                    ("ClusterIP" if is_minikube else "LoadBalancer")
                    if allocate_ip_address
                    else None
                ),
            ),
            opts=pulumi.ResourceOptions(parent=self),
        )
        if allocate_ip_address:
            if is_minikube:
                self.ip_address = self.service.spec.apply(lambda s: s.cluster_ip)
            else:
                ingress = self.service.status.apply(lambda s: s.load_balancer.ingress[0])
                self.ip_address = ingress.apply(lambda i: i.ip or i.hostname or "")
        self.register_outputs({})
