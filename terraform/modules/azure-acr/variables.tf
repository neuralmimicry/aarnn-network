############################################
# Azure ACR module variables
############################################

variable "project_name" {
  description = "Project name used to namespace repositories"
  type        = string
}

variable "location" {
  description = "Azure location"
  type        = string
}

variable "resource_group" {
  description = "Azure Resource Group name (created if does not exist)"
  type        = string
  default     = null
}

variable "aeron_image" {
  description = "Local Aeron image name to potentially tag/push (not pushed by default)"
  type        = string
}

variable "aarnn_image" {
  description = "Local AARNN image name to potentially tag/push (not pushed by default)"
  type        = string
}
