############################################
# AWS ECR module variables
############################################

variable "project_name" {
  description = "Project name used to namespace repositories"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
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
