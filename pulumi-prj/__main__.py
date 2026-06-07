import pulumi
from monitoring import deploy_monitoring
from service_deployment import ServiceDeployment

# Guestbook components example:
# https://github.com/pulumi/examples/tree/master/kubernetes-py-guestbook/components
config = pulumi.Config()
is_minikube = config.get_bool("isMinikube")
grafana_service_type = config.get("grafanaServiceType") or "LoadBalancer"

ServiceDeployment("redis-leader", image="redis", ports=[6379], redis_exporter=True)
ServiceDeployment("redis-replica", image="pulumi/guestbook-redis-replica", ports=[6379], redis_exporter=True)

frontend = ServiceDeployment(
    "frontend",
    image="pulumi/guestbook-php-redis",
    replicas=3,
    ports=[80],
    allocate_ip_address=True,
    is_minikube=is_minikube,
)

monitoring = deploy_monitoring(grafana_service_type=grafana_service_type)

pulumi.export("frontend_ip", frontend.ip_address)
pulumi.export("grafana_url", monitoring["grafana_url"])
pulumi.export("grafana_service_name", monitoring["grafana_service_name"])
pulumi.export("grafana_admin_user", monitoring["grafana_admin_user"])
pulumi.export("grafana_admin_password", monitoring["grafana_admin_password"])
