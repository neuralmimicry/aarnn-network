############################################
# GCP Artifact Registry – creates a Docker repo and outputs info
############################################

resource "google_artifact_registry_repository" "docker" {
  location      = var.gcp_region
  repository_id = replace("${var.project_name}-repo", "/[^a-z0-9-]/", "-")
  description   = "Artifact Registry for ${var.project_name} images"
  format        = "DOCKER"
}

output "repository" {
  value = google_artifact_registry_repository.docker.name
}

output "repo_location" {
  value = google_artifact_registry_repository.docker.location
}
