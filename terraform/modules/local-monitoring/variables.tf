############################################
# Local Monitoring (Docker/Podman) module variables
############################################

variable "enabled" {
  description = "Whether to deploy local monitoring stack (Prometheus, Grafana, cAdvisor)"
  type        = bool
  default     = true
}

variable "project_name" {
  description = "Project/namespace used for naming resources"
  type        = string
}

variable "network_name" {
  description = "Docker network to attach monitoring containers to (should be the same as app network)"
  type        = string
}

variable "prometheus_image" {
  description = "Base Prometheus image to use"
  type        = string
  default     = "prom/prometheus:v2.53.0"
}

variable "grafana_image" {
  description = "Grafana image to use"
  type        = string
  default     = "grafana/grafana:11.2.0"
}

variable "cadvisor_image" {
  description = "cAdvisor image to use"
  type        = string
  default     = "gcr.io/cadvisor/cadvisor:v0.47.2"
}

variable "grafana_admin_user" {
  description = "Grafana admin username"
  type        = string
  default     = "admin"
}

variable "grafana_admin_password" {
  description = "Grafana admin password (stored in state). If null, defaults to 'admin'"
  type        = string
  default     = null
  sensitive   = true
}

variable "enable_logging" {
  description = "Enable Loki + Promtail logging stack locally"
  type        = bool
  default     = false
}

# Indicates which container runtime the Docker provider targets: docker or podman
variable "container_runtime" {
  description = "Container runtime in use (docker or podman). Affects cAdvisor/Promtail support."
  type        = string
  default     = "docker"
  validation {
    condition     = contains(["docker", "podman"], var.container_runtime)
    error_message = "container_runtime must be 'docker' or 'podman'"
  }
}

variable "loki_image" {
  description = "Loki image"
  type        = string
  default     = "grafana/loki:2.9.8"
}

variable "promtail_image" {
  description = "Promtail image"
  type        = string
  default     = "grafana/promtail:2.9.8"
}
