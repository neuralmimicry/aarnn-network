variable "enabled" {
  description = "Whether to build and run local containers"
  type        = bool
  default     = true
}

variable "project_name" {
  description = "Project/namespace for resource names"
  type        = string
}

variable "aeron_git_ref" {
  description = "Git ref for Aeron"
  type        = string
}

variable "aarnn_git_ref" {
  description = "Git ref for AARNN"
  type        = string
}

variable "aeron_image_name" {
  description = "Local image name for Aeron"
  type        = string
}

variable "aarnn_image_name" {
  description = "Local image name for AARNN"
  type        = string
}

variable "aeron_container_cpu" {
  description = "CPU shares for Aeron container"
  type        = number
  default     = 1024
}

variable "aeron_container_memory" {
  description = "Memory limit (MB) for Aeron container"
  type        = number
  default     = 1024
}

variable "aarnn_container_cpu" {
  description = "CPU shares for AARNN container"
  type        = number
  default     = 1024
}

variable "aarnn_container_memory" {
  description = "Memory limit (MB) for AARNN container"
  type        = number
  default     = 2048
}

variable "enable_gpu" {
  description = "Enable GPU device requests for containers (requires NVIDIA Container Toolkit)"
  type        = bool
  default     = false
}

variable "gpu_count" {
  description = "Number of GPUs to request for GPU-enabled containers"
  type        = number
  default     = 1
}

variable "target_arch" {
  description = "Target architecture for local image build (amd64 or arm64). If null, use host default."
  type        = string
  default     = null
}

# Additional apps defined via the manifest; each object keys:
# name (string), repo (string), ref (string), port (number|null), cmd (list(string)|null),
# env (map(string)|null), health_path (string|null), type (string|null)
variable "extra_apps" {
  description = "List of additional generic apps to build/run locally, derived from the manifest."
  type        = list(any)
  default     = []
}
