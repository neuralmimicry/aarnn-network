############################################
# Local Monitoring Stack (Docker/Podman)
# - cAdvisor for container/node metrics
# - Prometheus scraping cAdvisor and app endpoints
# - Grafana with pre-provisioned Prometheus datasource
# Notes:
# - Attaches to the provided Docker network so service discovery by name works
# - Exposes Prometheus at 9090 and Grafana at 3000 on localhost
############################################

locals {
  name_prefix        = var.project_name
  prometheus_cfg_dir = "${path.module}/.generated/prometheus"
  grafana_prov_dir   = "${path.module}/.generated/grafana-provisioning"
  grafana_user       = var.grafana_admin_user
  grafana_pass       = coalesce(var.grafana_admin_password, "admin")
}

# Ensure directories exist for generated configs
resource "null_resource" "mkdirs" {
  count = var.enabled ? 1 : 0

  provisioner "local-exec" {
    command = "mkdir -p ${local.prometheus_cfg_dir} ${local.grafana_prov_dir}/datasources ${path.module}/.generated/loki ${path.module}/.generated/promtail"
  }
}

# Generate Prometheus configuration
resource "local_file" "prometheus_yml" {
  count      = var.enabled ? 1 : 0
  filename   = "${local.prometheus_cfg_dir}/prometheus.yml"
  depends_on = [null_resource.mkdirs]
  content    = <<-YAML
    global:
      scrape_interval: 15s
      evaluation_interval: 15s

    scrape_configs:
      - job_name: 'prometheus'
        static_configs:
          - targets: ['${local.name_prefix}-prometheus:9090']
${var.container_runtime != "podman" ? "      - job_name: 'cadvisor'\n        static_configs:\n          - targets: ['${local.name_prefix}-cadvisor:8080']\n" : ""}
      - job_name: 'aarnn'
        metrics_path: /metrics
        static_configs:
          - targets: ['${local.name_prefix}-aarnn:8080']

      - job_name: 'aeron'
        static_configs:
          - targets: [] # Aeron does not expose Prometheus metrics by default
  YAML
}

# Grafana provisioning for Prometheus datasource
resource "local_file" "grafana_datasource" {
  count    = var.enabled ? 1 : 0
  filename = "${local.grafana_prov_dir}/datasources/prometheus.yml"
  content  = <<-YAML
    apiVersion: 1
    datasources:
      - name: Prometheus
        type: prometheus
        access: proxy
        url: http://${local.name_prefix}-prometheus:9090
        isDefault: true
        editable: true
  YAML
}

# Optional Grafana provisioning for Loki datasource
resource "local_file" "grafana_loki_datasource" {
  count    = var.enabled && var.enable_logging ? 1 : 0
  filename = "${local.grafana_prov_dir}/datasources/loki.yml"
  content  = <<-YAML
    apiVersion: 1
    datasources:
      - name: Loki
        type: loki
        access: proxy
        url: http://${local.name_prefix}-loki:3100
        isDefault: false
        editable: true
  YAML
}

# Loki config (single-process, filesystem storage)
resource "local_file" "loki_config" {
  count    = var.enabled && var.enable_logging ? 1 : 0
  filename = "${path.module}/.generated/loki/config.yml"
  content  = <<-YAML
    auth_enabled: false
    server:
      http_listen_port: 3100
    common:
      path_prefix: /loki
      storage:
        filesystem:
          chunks_directory: /loki/chunks
          rules_directory: /loki/rules
      replication_factor: 1
      ring:
        kvstore:
          store: inmemory
    schema_config:
      configs:
        - from: 2023-01-01
          store: boltdb-shipper
          object_store: filesystem
          schema: v13
          index:
            prefix: index_
            period: 24h
    storage_config:
      boltdb_shipper:
        active_index_directory: /loki/index
        cache_location: /loki/boltdb-cache
      filesystem:
        directory: /loki/chunks
    limits_config:
      reject_old_samples: true
      reject_old_samples_max_age: 168h
  YAML
}

# Promtail config to tail Docker container logs
resource "local_file" "promtail_config" {
  count    = var.enabled && var.enable_logging ? 1 : 0
  filename = "${path.module}/.generated/promtail/config.yml"
  content  = <<-YAML
    server:
      http_listen_port: 9080
      grpc_listen_port: 0
    clients:
      - url: http://${local.name_prefix}-loki:3100/loki/api/v1/push
    positions:
      filename: /tmp/positions.yaml
    scrape_configs:
      - job_name: docker-logs
        static_configs:
          - targets: ["localhost"]
            labels:
              job: "${var.project_name}-containers"
              __path__: /var/lib/docker/containers/*/*-json.log
  YAML
}

# cAdvisor – container metrics (not supported on rootless Podman)
resource "docker_container" "cadvisor" {
  count = var.enabled && var.container_runtime != "podman" ? 1 : 0

  name  = "${local.name_prefix}-cadvisor"
  image = var.cadvisor_image

  networks_advanced {
    name = var.network_name
  }

  # cAdvisor requires access to docker host paths; when using rootless podman, this may not work.
  # This setup targets standard Docker on Linux.
  mounts {
    target = "/rootfs"
    source = "/"
    type   = "bind"
    read_only = true
  }
  mounts {
    target    = "/var/run"
    source    = "/var/run"
    type      = "bind"
    read_only = false
  }
  mounts {
    target    = "/sys"
    source    = "/sys"
    type      = "bind"
    read_only = true
  }
  mounts {
    target    = "/var/lib/docker"
    source    = "/var/lib/docker"
    type      = "bind"
    read_only = true
  }

  command = [
    "--docker_only=true",
    "--housekeeping_interval=10s"
  ]

  healthcheck {
    test         = ["CMD", "wget", "-qO-", "http://localhost:8080/metrics"]
    interval     = "15s"
    timeout      = "5s"
    retries      = 10
    start_period = "10s"
  }

  restart = "unless-stopped"

  ports {
    internal = 8080
    external = 0 # not published by default; access via network
    protocol = "tcp"
  }

  labels {
    label = "project"
    value = var.project_name
  }
  labels {
    label = "app"
    value = "cadvisor"
  }
}

# Prometheus
resource "docker_container" "prometheus" {
  count = var.enabled ? 1 : 0

  name  = "${local.name_prefix}-prometheus"
  image = var.prometheus_image

  networks_advanced { name = var.network_name }

  mounts {
    target = "/etc/prometheus/prometheus.yml"
    source = abspath(local_file.prometheus_yml[0].filename)
    type   = "bind"
    read_only = true
  }

  command = [
    "--config.file=/etc/prometheus/prometheus.yml",
    "--web.enable-lifecycle"
  ]

  healthcheck {
    test         = ["CMD", "wget", "-qO-", "http://localhost:9090/-/ready"]
    interval     = "15s"
    timeout      = "5s"
    retries      = 10
    start_period = "10s"
  }

  restart = "unless-stopped"

  ports {
    internal = 9090
    external = 9090
    protocol = "tcp"
  }

  labels {
    label = "project"
    value = var.project_name
  }
  labels {
    label = "app"
    value = "prometheus"
  }
}

# Grafana
resource "docker_container" "grafana" {
  count = var.enabled ? 1 : 0

  name  = "${local.name_prefix}-grafana"
  image = var.grafana_image

  networks_advanced { name = var.network_name }

  env = [
    "GF_SECURITY_ADMIN_USER=${local.grafana_user}",
    "GF_SECURITY_ADMIN_PASSWORD=${local.grafana_pass}",
    "GF_PATHS_PROVISIONING=/etc/grafana/provisioning"
  ]

  mounts {
    target = "/etc/grafana/provisioning/datasources/prometheus.yml"
    source = abspath(local_file.grafana_datasource[0].filename)
    type   = "bind"
    read_only = true
  }

  dynamic "mounts" {
    for_each = var.enable_logging ? [1] : []
    content {
      target    = "/etc/grafana/provisioning/datasources/loki.yml"
      source    = abspath(local_file.grafana_loki_datasource[0].filename)
      type      = "bind"
      read_only = true
    }
  }

  healthcheck {
    test         = ["CMD", "wget", "-qO-", "http://localhost:3000/api/health"]
    interval     = "15s"
    timeout      = "5s"
    retries      = 20
    start_period = "20s"
  }

  restart = "unless-stopped"

  ports {
    internal = 3000
    external = 3000
    protocol = "tcp"
  }

  labels {
    label = "project"
    value = var.project_name
  }
  labels {
    label = "app"
    value = "grafana"
  }
}

# Loki service (optional)
resource "docker_container" "loki" {
  count = var.enabled && var.enable_logging ? 1 : 0

  name  = "${local.name_prefix}-loki"
  image = var.loki_image

  networks_advanced { name = var.network_name }

  mounts {
    target = "/etc/loki/config.yml"
    source = local_file.loki_config[0].filename
    type   = "bind"
    read_only = true
  }

  command = ["-config.file=/etc/loki/config.yml"]

  healthcheck {
    test         = ["CMD", "wget", "-qO-", "http://localhost:3100/ready"]
    interval     = "15s"
    timeout      = "5s"
    retries      = 20
    start_period = "10s"
  }

  restart = "unless-stopped"

  ports {
    internal = 3100
    external = 0
    protocol = "tcp"
  }

  labels {
    label = "project"
    value = var.project_name
  }
  labels {
    label = "app"
    value = "loki"
  }
}

# Promtail agent (optional)
resource "docker_container" "promtail" {
  count = var.enabled && var.enable_logging && var.container_runtime != "podman" ? 1 : 0

  name  = "${local.name_prefix}-promtail"
  image = var.promtail_image

  networks_advanced { name = var.network_name }

  mounts {
    target = "/etc/promtail/config.yml"
    source = local_file.promtail_config[0].filename
    type   = "bind"
    read_only = true
  }

  # Access to docker container logs (Linux Docker)
  mounts {
    target    = "/var/lib/docker/containers"
    source    = "/var/lib/docker/containers"
    type      = "bind"
    read_only = true
  }
  mounts {
    target    = "/var/run/docker.sock"
    source    = "/var/run/docker.sock"
    type      = "bind"
    read_only = true
  }

  command = ["-config.file=/etc/promtail/config.yml"]

  healthcheck {
    test         = ["CMD", "wget", "-qO-", "http://localhost:9080/metrics"]
    interval     = "15s"
    timeout      = "5s"
    retries      = 10
    start_period = "10s"
  }

  restart = "unless-stopped"

  labels {
    label = "project"
    value = var.project_name
  }
  labels {
    label = "app"
    value = "promtail"
  }
}

output "prometheus_url" {
  value       = var.enabled ? "http://localhost:9090" : null
  description = "URL for local Prometheus"
}

output "grafana_url" {
  value       = var.enabled ? "http://localhost:3000" : null
  description = "URL for local Grafana"
}

output "grafana_admin_user" {
  value       = var.enabled ? local.grafana_user : null
  description = "Grafana admin username"
}

output "grafana_admin_password" {
  value       = var.enabled ? local.grafana_pass : null
  description = "Grafana admin password"
  sensitive   = true
}

output "loki_internal_url" {
  value       = var.enabled && var.enable_logging ? "http://${local.name_prefix}-loki:3100" : null
  description = "Internal URL for Loki (from Grafana/network)"
}
