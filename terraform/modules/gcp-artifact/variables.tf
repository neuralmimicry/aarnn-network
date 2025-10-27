############################################
# GCP Artifact Registry module variables
############################################

variable "project_name" {
  description = "Project name used to namespace repositories"
  type        = string
}

variable "gcp_project" {
  description = "GCP project ID"
  type        = string
}

variable "gcp_region" {
  description = "GCP region for Artifact Registry"
  type        = string
}

variable "aeron_image" {
  description = "Local Aeron image name to potentially tag/push (not pushed by default)"
  type        = string
}

variable "aarnn_image" {
  description = "Local AARNN image name to potentially tag/push (not pushed by default)"
  type        = string
}
