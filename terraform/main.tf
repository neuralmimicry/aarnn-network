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

# Optional: build local images for Kubernetes and load into kind
# This enables a registry-less workflow when using kind. Requires Docker daemon.
resource "local_file" "aeron_dockerfile_k8s" {
  count    = var.deployment_target == "kubernetes" && var.build_k8s_local_images ? 1 : 0
  filename = "${path.module}/.generated/Dockerfile.aeron.k8s"
  content  = templatefile("${path.module}/modules/local-apps/templates/Dockerfile.aeron.tftpl", {
    aeron_git_ref = local.aeron_ref
  })
}

resource "local_file" "aarnn_dockerfile_k8s" {
  count    = var.deployment_target == "kubernetes" && var.build_k8s_local_images ? 1 : 0
  filename = "${path.module}/.generated/Dockerfile.aarnn.k8s"
  content  = templatefile("${path.module}/modules/local-apps/templates/Dockerfile.aarnn.k8s.tftpl", {
    aarnn_git_ref = local.aarnn_ref
  })
}

resource "docker_image" "aeron_k8s" {
  count = var.deployment_target == "kubernetes" && var.build_k8s_local_images ? 1 : 0
  name  = local.aeron_image_name
  build {
    context     = path.module
    dockerfile  = local_file.aeron_dockerfile_k8s[0].filename
    pull_parent = true
    no_cache    = false
    platform    = var.target_arch != null ? "linux/${var.target_arch}" : ""
  }
  timeouts { create = "30m" }
}

resource "docker_image" "aarnn_k8s" {
  count = var.deployment_target == "kubernetes" && var.build_k8s_local_images ? 1 : 0
  name  = local.aarnn_image_name
  build {
    context     = path.module
    dockerfile  = local_file.aarnn_dockerfile_k8s[0].filename
    pull_parent = true
    no_cache    = false
    platform    = var.target_arch != null ? "linux/${var.target_arch}" : ""
  }
  timeouts { create = "45m" }
}

# Attempt to auto-load local images into kind when targeting Kubernetes with a kind-* context and no image overrides
resource "null_resource" "kind_load_images" {
  # Ensure images are built first when we opted to build locally for K8s
  # depends_on must be a static list of references; referencing resources with count=0 is allowed
  depends_on = [
    docker_image.aeron_k8s,
    docker_image.aarnn_k8s
  ]

  # Use triggers to ensure this re-evaluates when relevant inputs change
  triggers = {
    deployment_target   = var.deployment_target
    kubeconfig_context  = var.kubeconfig_context != null ? var.kubeconfig_context : ""
    aeron_override      = var.aeron_image_override != null ? var.aeron_image_override : ""
    aarnn_override      = var.aarnn_image_override != null ? var.aarnn_image_override : ""
    aeron_local_image   = local.aeron_image_name
    aarnn_local_image   = local.aarnn_image_name
  }

  provisioner "local-exec" {
    when    = create
    command = <<-EOC
      set -e
      # Only act for Kubernetes target with a kind-* context and when no image overrides are set
      if [ "$DEPLOYMENT_TARGET" = "kubernetes" ] && echo "$KUBECONTEXT" | grep -q '^kind-'; then
        if [ -z "$AERON_OVERRIDE" ] && [ -z "$AARNN_OVERRIDE" ]; then
          KIND_NAME="$${KUBECONTEXT#kind-}"
          echo "Attempting to load local images into kind cluster '$${KIND_NAME}'..."
          # Load Aeron image if available in Docker
          kind load docker-image ${local.aeron_image_name}:latest --name "$KIND_NAME" || echo "Note: could not load ${local.aeron_image_name}:latest into kind (image may be missing in Docker daemon)."
          # Load AARNN image if available in Docker
          kind load docker-image ${local.aarnn_image_name}:latest --name "$KIND_NAME" || echo "Note: could not load ${local.aarnn_image_name}:latest into kind (image may be missing in Docker daemon)."
        else
          echo "Image overrides provided; skipping kind image load."
        fi
      else
        echo "Not a kind Kubernetes target or context not set; skipping kind image load."
      fi
    EOC
    interpreter = ["/bin/sh", "-c"]
    environment = {
      DEPLOYMENT_TARGET = var.deployment_target
      KUBECONTEXT       = var.kubeconfig_context != null ? var.kubeconfig_context : ""
      AERON_OVERRIDE    = var.aeron_image_override != null ? var.aeron_image_override : ""
      AARNN_OVERRIDE    = var.aarnn_image_override != null ? var.aarnn_image_override : ""
    }
  }
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
  depends_on = [
    null_resource.kind_load_images
  ]

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

