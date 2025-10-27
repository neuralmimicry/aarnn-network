############################################
# Kubernetes Apps Module Variables
############################################

variable "project_name" {
  description = "Project name used for naming"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace to deploy into"
  type        = string
  default     = "aarnn"
}

variable "aeron_image" {
  description = "Container image for Aeron"
  type        = string
}

variable "aarnn_image" {
  description = "Container image for AARNN"
  type        = string
}

variable "service_type" {
  description = "Kubernetes Service type for the AARNN service"
  type        = string
  default     = "ClusterIP"
}

variable "aeron_container_cpu" {
  description = "CPU request for Aeron container"
  type        = string
  default     = "250m"
}

variable "aeron_container_memory" {
  description = "Memory request for Aeron container"
  type        = string
  default     = "512Mi"
}

variable "aarnn_container_cpu" {
  description = "CPU request for AARNN container"
  type        = string
  default     = "250m"
}

variable "aarnn_container_memory" {
  description = "Memory request for AARNN container"
  type        = string
  default     = "1Gi"
}

variable "enable_gpu" {
  description = "Enable GPU requests for GPU-capable workloads"
  type        = bool
  default     = false
}

variable "gpu_count" {
  description = "Number of GPUs to request (nvidia.com/gpu)"
  type        = number
  default     = 1
}

variable "node_selector" {
  description = "Optional nodeSelector map applied to pods"
  type        = map(string)
  default     = {}
}

variable "tolerations" {
  description = "Optional list of tolerations for pods"
  type        = list(object({
    key = string
    operator = optional(string)
    value = optional(string)
    effect = optional(string)
  }))
  default     = []
}

# Additional generic apps for Kubernetes from manifest
# items: { name, image (optional), env (map), port (number|null), health_path (string|null), cmd (list(string)|null) }
variable "extra_apps" {
  description = "List of additional generic apps to deploy on Kubernetes"
  type        = list(any)
  default     = []
}
