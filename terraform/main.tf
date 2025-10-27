############################################
# Root module – orchestrates local build/run and optional cloud registries
############################################

locals {
  aeron_image_name = "aeron-local"
  aarnn_image_name = "aarnn-local"

  manifest_path = coalesce(var.manifest_path, "${path.module}/apps.manifest.yaml")
  manifest      = can(file(local.manifest_path)) ? yamldecode(file(local.manifest_path)) : {}

  manifest_apps = try(local.manifest["apps"], [])

  aeron_refs = [for a in local.manifest_apps : a["ref"] if try(lower(a["type"]), "") == "aeron"]
  aarnn_refs = [for a in local.manifest_apps : a["ref"] if try(lower(a["type"]), "") == "aarnn"]

  aeron_ref = coalesce(try(local.aeron_refs[0], null), var.aeron_git_ref)
  aarnn_ref = coalesce(try(local.aarnn_refs[0], null), var.aarnn_git_ref)

  extra_apps = [for a in local.manifest_apps : {
    name        = a["name"]
    repo        = a["repo"]
    ref         = a["ref"]
    port        = try(a["port"], null)
    cmd         = try(a["cmd"], null)
    env         = try(a["env"], null)
    health_path = try(a["health_path"], null)
    image       = try(a["image"], null)
    metrics_path = try(a["metrics_path"], null)
    type        = try(lower(a["type"]), null)
  } if try(lower(a["type"]), "generic") == "generic"]

  # For Kubernetes, only include extra apps that specify an image (since this module does not build images when targeting K8s)
  extra_apps_k8s = [for a in local.extra_apps : a if try(a.image != null && length(trim(a.image)) > 0, false)]
}

module "local_apps" {
  source = "./modules/local-apps"

  # Build and run locally when target is docker or podman
  enabled                  = var.enable_local_containers && var.deployment_target != "kubernetes"
  project_name             = var.project_name
  aeron_git_ref            = local.aeron_ref
  aarnn_git_ref            = local.aarnn_ref
  aeron_image_name         = local.aeron_image_name
  aarnn_image_name         = local.aarnn_image_name
  aeron_container_cpu      = var.aeron_container_cpu
  aeron_container_memory   = var.aeron_container_memory
  aarnn_container_cpu      = var.aarnn_container_cpu
  aarnn_container_memory   = var.aarnn_container_memory
  extra_apps               = local.extra_apps
  enable_gpu               = var.enable_gpu
  gpu_count                = var.gpu_count
  target_arch              = var.target_arch
}

# Local monitoring stack (Prometheus + Grafana) when using docker/podman
module "local_monitoring" {
  source = "./modules/local-monitoring"

  # Require the local app network to exist
  count                   = var.enable_monitoring && var.deployment_target != "kubernetes" && module.local_apps.network_name != null ? 1 : 0
  enabled                 = true
  project_name            = var.project_name
  network_name            = module.local_apps.network_name
  grafana_admin_user      = var.grafana_admin_user
  grafana_admin_password  = var.grafana_admin_password
  enable_logging          = var.enable_logging
  container_runtime       = coalesce(var.container_runtime, (var.deployment_target == "podman" || (try(length(var.docker_host),0) > 0 && can(regex("podman", var.docker_host)))) ? "podman" : "docker")
}

# If targeting Kubernetes, deploy using provided image refs or those built locally (if any)
module "k8s_apps" {
  source = "./modules/k8s-apps"
  count  = var.deployment_target == "kubernetes" ? 1 : 0

  project_name            = var.project_name
  namespace               = var.k8s_namespace
  service_type            = var.k8s_service_type
  aeron_image             = coalesce(var.aeron_image_override, module.local_apps.aeron_image_full, local.aeron_image_name)
  aarnn_image             = coalesce(var.aarnn_image_override, module.local_apps.aarnn_image_full, local.aarnn_image_name)
  aeron_container_cpu     = "250m"
  aeron_container_memory  = "512Mi"
  aarnn_container_cpu     = "250m"
  aarnn_container_memory  = "1Gi"

  # GPU and scheduling
  enable_gpu    = var.enable_gpu
  gpu_count     = var.gpu_count
  node_selector = var.node_selector
  tolerations   = var.tolerations

  # Generic apps for K8s (from manifest, only those with explicit image)
  extra_apps = local.extra_apps_k8s
}

# Kubernetes monitoring (Prometheus/Grafana via Helm) when target is kubernetes
module "k8s_monitoring" {
  source = "./modules/k8s-monitoring"
  count  = var.enable_monitoring && var.deployment_target == "kubernetes" ? 1 : 0

  project_name           = var.project_name
  namespace              = var.k8s_namespace
  service_type           = var.k8s_service_type
  grafana_admin_user     = var.grafana_admin_user
  grafana_admin_password = var.grafana_admin_password
  enable_logging         = var.enable_logging
}

# Optional Harbor registry on Kubernetes (useful on OpenStack/on-prem)
module "k8s_harbor" {
  source = "./modules/k8s-harbor"
  count  = var.enable_harbor && var.deployment_target == "kubernetes" ? 1 : 0

  project_name   = var.project_name
  namespace      = var.k8s_namespace
  service_type   = var.k8s_service_type
  expose_ingress = var.harbor_expose_ingress
  hostname       = var.harbor_hostname
  storage_class  = var.harbor_storage_class
}

