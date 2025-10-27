############################################
# Local Apps Module
# - Builds Aeron and AARNN images with multi-stage Dockerfiles
# - Creates a dedicated Docker network
# - Runs containers with healthchecks and restart policies
############################################

locals {
  network_name = "${var.project_name}-net"

  extra_map = { for a in var.extra_apps : a["name"] => a }
}

# Create isolated network for inter-container communication
resource "docker_network" "app" {
  count = var.enabled ? 1 : 0
  name  = local.network_name
}

# Aeron image build context using a generated Dockerfile
resource "local_file" "aeron_dockerfile" {
  count    = var.enabled ? 1 : 0
  filename = "${path.module}/.generated/Dockerfile.aeron"
  content  = templatefile("${path.module}/templates/Dockerfile.aeron.tftpl", {
    aeron_git_ref = var.aeron_git_ref
  })
}

resource "docker_image" "aeron" {
  count = var.enabled ? 1 : 0

  name = var.aeron_image_name

  build {
    context     = path.module
    dockerfile  = local_file.aeron_dockerfile[0].filename
    no_cache    = false
    pull_parent = true
    platform    = var.target_arch != null ? "linux/${var.target_arch}" : ""
  }

  # Retry pulls/builds in case of transient issues
  timeouts {
    create = "30m"
  }
}

# AARNN image build context
resource "local_file" "aarnn_dockerfile" {
  count    = var.enabled ? 1 : 0
  filename = "${path.module}/.generated/Dockerfile.aarnn"
  content  = templatefile("${path.module}/templates/Dockerfile.aarnn.tftpl", {
    aarnn_git_ref = var.aarnn_git_ref
  })
}

resource "docker_image" "aarnn" {
  count = var.enabled ? 1 : 0

  name = var.aarnn_image_name

  build {
    context     = path.module
    dockerfile  = local_file.aarnn_dockerfile[0].filename
    no_cache    = false
    build_args  = {}
    pull_parent = true
    platform    = var.target_arch != null ? "linux/${var.target_arch}" : ""
  }

  timeouts {
    create = "45m"
  }
}

# Aeron container
resource "docker_container" "aeron" {
  count = var.enabled ? 1 : 0

  name  = "${var.project_name}-aeron"
  image = docker_image.aeron[0].name

  networks_advanced {
    name = docker_network.app[0].name
  }

  # Healthcheck: basic Java process up (Aeron samples or media driver)
  healthcheck {
    test         = ["CMD-SHELL", "ps aux | grep -v grep | grep -q java"]
    interval     = "15s"
    timeout      = "5s"
    retries      = 10
    start_period = "20s"
  }

  restart = "unless-stopped"

  # Resource limits (best-effort, platform dependent)
  cpu_shares = var.aeron_container_cpu
  memory     = var.aeron_container_memory * 1024 * 1024

  labels {
    label = "project"
    value = var.project_name
  }
  labels {
    label = "app"
    value = "aeron"
  }

  # Command/Entrypoint: run Media Driver in background and keep container alive with a sleep loop
  # Add JVM module export to allow Agrona to access jdk.internal.misc.Unsafe on JDK 17+ (Java modules)
  entrypoint = ["/bin/sh", "-lc"]
  command    = ["java --add-exports=java.base/jdk.internal.misc=ALL-UNNAMED -cp /aeron/aeron-all.jar io.aeron.driver.MediaDriver & while true; do sleep 600; done"]
}

# AARNN container
resource "docker_container" "aarnn" {
  count = var.enabled ? 1 : 0

  name  = "${var.project_name}-aarnn"
  image = docker_image.aarnn[0].name

  networks_advanced {
    name = docker_network.app[0].name
  }

  env = flatten([
    ["AERON_DIR=/aeron", "AERON_MEDIA_DRIVER_ENDPOINT=${docker_container.aeron[0].name}:40123"],
    var.enable_gpu ? ["NVIDIA_VISIBLE_DEVICES=all", "NVIDIA_DRIVER_CAPABILITIES=compute,utility"] : []
  ])

  healthcheck {
    test         = ["CMD", "/bin/sh", "-lc", "curl -fsS http://localhost:8080/health || exit 1"]
    interval     = "15s"
    timeout      = "5s"
    retries      = 30
    start_period = "45s"
  }

  restart = "unless-stopped"

  cpu_shares = var.aarnn_container_cpu
  memory     = var.aarnn_container_memory * 1024 * 1024

  labels {
    label = "project"
    value = var.project_name
  }
  labels {
    label = "app"
    value = "aarnn"
  }

  # Expose AARNN service port
  ports {
    internal = 8080
    external = 8080
    protocol = "tcp"
  }
}

# Generic apps – Dockerfile generation, image builds, and containers
resource "local_file" "generic_dockerfile" {
  for_each = var.enabled ? local.extra_map : {}

  filename = "${path.module}/.generated/Dockerfile.${each.key}"
  content  = templatefile("${path.module}/templates/Dockerfile.generic.tftpl", {
    BASE_IMAGE = "python:3.11-slim"
  })
}

resource "docker_image" "extra" {
  for_each = var.enabled ? local.extra_map : {}

  name = "${each.key}-local"

  build {
    context     = path.module
    dockerfile  = local_file.generic_dockerfile[each.key].filename
    no_cache    = false
    pull_parent = true
    build_args = {
      REPO_URL = each.value["repo"]
      GIT_REF  = each.value["ref"]
    }
  }

  timeouts { create = "30m" }
}

locals {
  extra_env_lists = { for k, v in local.extra_map : k => [for ek, ev in try(v["env"], {}) : "${ek}=${ev}"] }
  extra_health_paths = { for k, v in local.extra_map : k => coalesce(try(v["health_path"], null), "/health") }
}

resource "docker_container" "extra" {
  for_each = var.enabled ? local.extra_map : {}

  name  = "${var.project_name}-${each.key}"
  image = docker_image.extra[each.key].name

  networks_advanced { name = docker_network.app[0].name }

  env = flatten([
    try(local.extra_env_lists[each.key], []),
    var.enable_gpu ? ["NVIDIA_VISIBLE_DEVICES=all", "NVIDIA_DRIVER_CAPABILITIES=compute,utility"] : []
  ])

  dynamic "ports" {
    for_each = try(each.value["port"], null) != null ? [1] : []
    content {
      internal = tonumber(tostring(each.value["port"]))
      external = tonumber(tostring(each.value["port"]))
      protocol = "tcp"
    }
  }

  dynamic "healthcheck" {
    for_each = try(each.value["port"], null) != null ? [1] : []
    content {
      test         = ["CMD", "bash", "-lc", "curl -fsS http://localhost:${each.value["port"]}${local.extra_health_paths[each.key]} || exit 1"]
      interval     = "15s"
      timeout      = "5s"
      retries      = 10
      start_period = "20s"
    }
  }

  restart = "unless-stopped"

  labels {
    label = "project"
    value = var.project_name
  }
  labels {
    label = "app"
    value = each.key
  }

  # If no cmd provided, fall back to generic Dockerfile CMD
  command = try(each.value["cmd"], ["bash", "-lc", "python /app/.health/health_app.py"])
}

output "aeron_image_full" {
  value       = var.enabled ? docker_image.aeron[0].name : null
  description = "Built Aeron image name"
}

output "aarnn_image_full" {
  value       = var.enabled ? docker_image.aarnn[0].name : null
  description = "Built AARNN image name"
}

output "extra_images" {
  value       = var.enabled ? { for k, v in docker_image.extra : k => v.name } : {}
  description = "Map of extra app image names"
}

output "extra_containers" {
  value       = var.enabled ? { for k, v in docker_container.extra : k => v.name } : {}
  description = "Map of extra app container names"
}

output "network_name" {
  value       = var.enabled ? docker_network.app[0].name : null
  description = "Docker network used by the application"
}
