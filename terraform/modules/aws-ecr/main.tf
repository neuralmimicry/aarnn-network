############################################
# AWS ECR module – creates repos and outputs their URLs
############################################

resource "aws_ecr_repository" "aeron" {
  name                 = "${var.project_name}/aeron"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "aarnn" {
  name                 = "${var.project_name}/aarnn"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
  image_scanning_configuration {
    scan_on_push = true
  }
}

output "aeron_repo_url" {
  value       = aws_ecr_repository.aeron.repository_url
  description = "ECR URL for Aeron image"
}

output "aarnn_repo_url" {
  value       = aws_ecr_repository.aarnn.repository_url
  description = "ECR URL for AARNN image"
}
