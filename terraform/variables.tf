############################################
# Global variables and defaults
############################################

variable "project_name" {
  description = "A short name used to namespace resources"
  type        = string
  default     = "aarnn-net"
}

# Path to the single apps manifest file (YAML) that declares repositories to build/deploy
variable "manifest_path" {
  description = "Path to apps manifest YAML file. If null, defaults to apps.manifest.yaml in this module."
  type        = string
  default     = null
}

variable "default_tags" {
  description = "Default tags/labels applied to supported providers"
  type        = map(string)
  default = {
    project = "aarnn-network"
    managed = "terraform"
  }
}

############################################
# Docker provider vars
############################################

variable "docker_host" {
  description = "Docker daemon host. Leave empty to use local default (env DOCKER_HOST or local socket)"
  type        = string
  default     = null
}

# Optional explicit container runtime override for local stacks.
# When null, the system auto-detects based on deployment_target and docker_host.
variable "container_runtime" {
  description = "Container runtime to target for local stacks: docker or podman. Null = auto-detect."
  type        = string
  default     = null
  validation {
    condition     = var.container_runtime == null || try(contains(["docker", "podman"], var.container_runtime), false)
    error_message = "container_runtime must be one of: docker, podman, or null."
  }
}

variable "docker_registry_address" {
  description = "Optional registry to auth to (e.g. index.docker.io, <acct>.dkr.ecr.<region>.amazonaws.com)"
  type        = string
  default     = null
}

variable "docker_registry_username" {
  description = "Optional registry username for auth"
  type        = string
  default     = null
  sensitive   = true
}

variable "docker_registry_password" {
  description = "Optional registry password/token for auth"
  type        = string
  default     = null
  sensitive   = true
}

############################################
# Cloud provider vars
############################################

variable "aws_region" {
  description = "AWS region for optional ECR resources"
  type        = string
  default     = "us-east-1"
}

variable "gcp_project" {
  description = "GCP project ID for optional Artifact Registry resources"
  type        = string
  default     = null
}

variable "gcp_region" {
  description = "GCP region for optional Artifact Registry resources"
  type        = string
  default     = "us-central1"
}

variable "azure_location" {
  description = "Azure location for optional ACR resources"
  type        = string
  default     = "eastus"
}

variable "azure_resource_group" {
  description = "Azure Resource Group name to host ACR (created if missing)"
  type        = string
  default     = null
}

############################################
# Deployment target and feature flags
############################################

variable "deployment_target" {
  description = "Where to deploy/run the stack: one of 'docker', 'podman', 'kubernetes'"
  type        = string
  default     = "docker"
  validation {
    condition     = contains(["docker", "podman", "kubernetes"], var.deployment_target)
    error_message = "deployment_target must be one of: docker, podman, kubernetes."
  }
}

variable "enable_local_containers" {
  description = "Build and run local containers for Aeron and AARNN (used when deployment_target is docker or podman)"
  type        = bool
  default     = true
}

variable "enable_monitoring" {
  description = "Enable Prometheus/Grafana monitoring stack"
  type        = bool
  default     = true
}

variable "enable_logging" {
  description = "Enable logging stack (Loki/Promtail). For Kubernetes this is installed via Helm; for local this is not included in minimal setup."
  type        = bool
  default     = false
}

variable "enable_gpu" {
  description = "Enable GPU usage for containers/pods where supported"
  type        = bool
  default     = false
}

variable "gpu_count" {
  description = "Number of GPUs to request (Docker: device requests; Kubernetes: resource limits)"
  type        = number
  default     = 1
}

variable "grafana_admin_user" {
  description = "Grafana admin username (used for local monitoring and to override Helm chart values)"
  type        = string
  default     = "admin"
}

variable "grafana_admin_password" {
  description = "Grafana admin password. If null, defaults to 'admin' (not secure; for dev only)."
  type        = string
  default     = null
  sensitive   = true
}

variable "enable_aws_ecr" {
  description = "Create AWS ECR repos and optionally push images"
  type        = bool
  default     = false
}

variable "enable_gcp_artifact" {
  description = "Create GCP Artifact Registry repo and optionally push images"
  type        = bool
  default     = false
}

variable "enable_azure_acr" {
  description = "Create Azure Container Registry and optionally push images"
  type        = bool
  default     = false
}

variable "enable_harbor" {
  description = "Install Harbor registry in Kubernetes via Helm (useful for OpenStack and on-prem)"
  type        = bool
  default     = false
}

############################################
# Kubernetes options
############################################

variable "kubeconfig_path" {
  description = "Path to kubeconfig file used when deployment_target is 'kubernetes'"
  type        = string
  default     = null
}

variable "kubeconfig_context" {
  description = "Optional kubeconfig context name"
  type        = string
  default     = null
}

variable "k8s_namespace" {
  description = "Namespace to deploy resources into when using Kubernetes"
  type        = string
  default     = "aarnn"
}

variable "k8s_service_type" {
  description = "Kubernetes Service type for AARNN service (ClusterIP or NodePort)"
  type        = string
  default     = "ClusterIP"
  validation {
    condition     = contains(["ClusterIP", "NodePort", "LoadBalancer"], var.k8s_service_type)
    error_message = "k8s_service_type must be ClusterIP, NodePort, or LoadBalancer."
  }
}

variable "node_selector" {
  description = "Kubernetes nodeSelector applied to app pods (for GPU or arch placement)"
  type        = map(string)
  default     = {}
}

variable "tolerations" {
  description = "Kubernetes tolerations applied to app pods"
  type        = list(object({
    key = string
    operator = optional(string)
    value = optional(string)
    effect = optional(string)
  }))
  default     = []
}

variable "aeron_image_override" {
  description = "When deploying to Kubernetes, image reference to use for Aeron (e.g., registry/repo:tag). If null, falls back to local image name."
  type        = string
  default     = null
}

variable "aarnn_image_override" {
  description = "When deploying to Kubernetes, image reference to use for AARNN (e.g., registry/repo:tag). If null, falls back to local image name."
  type        = string
  default     = null
}

# Harbor options (Kubernetes-based registry useful in OpenStack/on-prem)
variable "harbor_expose_ingress" {
  description = "Expose Harbor via Ingress (requires ingress controller)"
  type        = bool
  default     = false
}

variable "harbor_hostname" {
  description = "Ingress hostname for Harbor when expose_ingress=true"
  type        = string
  default     = null
}

variable "harbor_storage_class" {
  description = "StorageClass name to use for Harbor persistence (optional)"
  type        = string
  default     = null
}

############################################
# App build options
############################################

variable "target_arch" {
  description = "Target architecture for local image builds (amd64 or arm64). Null uses host arch."
  type        = string
  default     = null
  validation {
    condition     = var.target_arch == null || try(contains(["amd64", "arm64"], var.target_arch), false)
    error_message = "target_arch must be one of: amd64, arm64, or null."
  }
}

variable "aeron_git_ref" {
  description = "Git ref (branch, tag, or commit) to build for Aeron"
  type        = string
  default     = "master"
}

variable "aarnn_git_ref" {
  description = "Git ref (branch, tag, or commit) to build for AARNN"
  type        = string
  default     = "main"
}

variable "aeron_container_cpu" {
  description = "CPU shares for Aeron container"
  type        = number
  default     = 1024
}

variable "aeron_container_memory" {
  description = "Memory limit in MB for Aeron container"
  type        = number
  default     = 1024
}

variable "aarnn_container_cpu" {
  description = "CPU shares for AARNN container"
  type        = number
  default     = 1024
}

variable "aarnn_container_memory" {
  description = "Memory limit in MB for AARNN container"
  type        = number
  default     = 2048
}
