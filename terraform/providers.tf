terraform {
  required_version = ">= 1.5.0"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "docker" {
  # Supports Docker and Podman (via DOCKER_HOST or explicit docker_host variable)
  host = var.docker_host
}

provider "kubernetes" {
  # Generic Kubernetes config; used only when deployment_target == "kubernetes"
  config_path       = coalesce(var.kubeconfig_path, pathexpand("~/.kube/config"))
  config_context    = var.kubeconfig_context
  config_context_auth_info = null
}

provider "helm" {
  kubernetes {
    config_path    = coalesce(var.kubeconfig_path, pathexpand("~/.kube/config"))
    config_context = var.kubeconfig_context
  }
}

# Cloud providers are configured by their respective modules when enabled.
# No other root-level cloud provider configuration is required for local-only usage.



