############################################
# Kubernetes Monitoring (Helm) module variables
############################################

variable "project_name" {
  description = "Project/namespace prefix for names"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace to install monitoring stack into"
  type        = string
}

variable "service_type" {
  description = "Service type for Grafana and Prometheus Services"
  type        = string
  default     = "ClusterIP"
}

variable "grafana_admin_user" {
  description = "Grafana admin username"
  type        = string
  default     = "admin"
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  default     = null
  sensitive   = true
}

variable "enable_logging" {
  description = "Install Loki+Promtail logging stack via Helm"
  type        = bool
  default     = false
}
