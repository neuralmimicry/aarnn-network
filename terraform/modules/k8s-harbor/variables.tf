############################################
# Kubernetes Harbor (Helm) module variables
############################################

variable "project_name" {
  description = "Project/namespace prefix for names"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace to install Harbor into"
  type        = string
  default     = "aarnn"
}

variable "service_type" {
  description = "Service type for Harbor services"
  type        = string
  default     = "ClusterIP"
}

variable "expose_ingress" {
  description = "Whether to expose Harbor via Ingress (requires ingress controller)"
  type        = bool
  default     = false
}

variable "hostname" {
  description = "External hostname to use when expose_ingress=true"
  type        = string
  default     = null
}

variable "storage_class" {
  description = "StorageClass for Harbor persistence (optional)"
  type        = string
  default     = null
}
