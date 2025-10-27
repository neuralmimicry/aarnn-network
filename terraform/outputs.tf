output "aeron_image" {
  description = "Local Aeron image tag"
  value       = module.local_apps.aeron_image_full
}

output "aarnn_image" {
  description = "Local AARNN image tag"
  value       = module.local_apps.aarnn_image_full
}

output "docker_network" {
  description = "Docker network used by the app"
  value       = module.local_apps.network_name
}

# Extra apps (local docker/podman only)
output "extra_app_images" {
  description = "Map of extra app images built locally (from manifest)."
  value       = var.deployment_target != "kubernetes" ? module.local_apps.extra_images : {}
}

output "extra_app_containers" {
  description = "Map of extra app container names running locally (from manifest)."
  value       = var.deployment_target != "kubernetes" ? module.local_apps.extra_containers : {}
}


output "k8s_namespace" {
  description = "Kubernetes namespace where resources are created (when deployment_target is kubernetes)"
  value       = var.deployment_target == "kubernetes" ? module.k8s_apps[0].namespace : null
}

output "k8s_aarnn_service_name" {
  description = "Kubernetes Service name for AARNN (when deployment_target is kubernetes)"
  value       = var.deployment_target == "kubernetes" ? module.k8s_apps[0].aarnn_service_name : null
}

output "k8s_extra_service_names" {
  description = "Map of K8s Service names for extra manifest apps with ports (when target is kubernetes)"
  value       = var.deployment_target == "kubernetes" ? module.k8s_apps[0].extra_service_names : {}
}

output "harbor_notes" {
  description = "How to access the Harbor registry when enabled"
  value       = var.deployment_target == "kubernetes" && var.enable_harbor ? module.k8s_harbor[0].notes : null
}

# Monitoring outputs – local (Docker/Podman)
output "monitoring_prometheus_url" {
  description = "Prometheus URL when running locally (docker/podman)"
  value       = var.enable_monitoring && var.deployment_target != "kubernetes" ? module.local_monitoring[0].prometheus_url : null
}

output "monitoring_grafana_url" {
  description = "Grafana URL when running locally (docker/podman)"
  value       = var.enable_monitoring && var.deployment_target != "kubernetes" ? module.local_monitoring[0].grafana_url : null
}

output "monitoring_grafana_admin_user" {
  description = "Grafana admin user (local)"
  value       = var.enable_monitoring && var.deployment_target != "kubernetes" ? module.local_monitoring[0].grafana_admin_user : null
}

output "monitoring_grafana_admin_password" {
  description = "Grafana admin password (local)"
  value       = var.enable_monitoring && var.deployment_target != "kubernetes" ? module.local_monitoring[0].grafana_admin_password : null
  sensitive   = true
}

# Monitoring outputs – Kubernetes
output "k8s_grafana_service_name" {
  description = "Grafana service name when deployed to Kubernetes"
  value       = var.enable_monitoring && var.deployment_target == "kubernetes" ? module.k8s_monitoring[0].grafana_service_name : null
}

output "k8s_monitoring_notes" {
  description = "How to access Grafana in Kubernetes"
  value       = var.enable_monitoring && var.deployment_target == "kubernetes" ? module.k8s_monitoring[0].notes : null
}

# Optional local Loki (when logging enabled)
output "monitoring_loki_internal_url" {
  description = "Internal URL for Loki (reachable from Grafana) when logging enabled locally"
  value       = var.enable_monitoring && var.deployment_target != "kubernetes" && var.enable_logging ? module.local_monitoring[0].loki_internal_url : null
}
