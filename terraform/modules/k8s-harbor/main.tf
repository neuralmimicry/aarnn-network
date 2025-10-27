############################################
# Harbor registry via Helm
# Useful for OpenStack/on-prem clusters to host/push multi-arch images
############################################

locals {
  release_name = "${var.project_name}-harbor"
}

resource "helm_release" "harbor" {
  name       = local.release_name
  namespace  = var.namespace
  chart      = "harbor"
  repository = "https://helm.goharbor.io"
  version    = "1.14.0"

  create_namespace = false

  values = [
    yamlencode({
      expose = {
        type = var.expose_ingress ? "ingress" : "clusterIP"
        ingress = {
          hosts = {
            core = var.hostname != null ? var.hostname : "harbor.local"
          }
        }
        tls = {
          enabled = false
        }
      }
      service = {
        type = var.service_type
      }
      persistence = {
        enabled = true
        persistentVolumeClaim = {
          registry = {
            storageClass = var.storage_class
          }
          chartmuseum = { storageClass = var.storage_class }
          jobservice  = { storageClass = var.storage_class }
          database    = { storageClass = var.storage_class }
          redis       = { storageClass = var.storage_class }
          trivy       = { storageClass = var.storage_class }
        }
      }
    })
  ]
}

output "harbor_release_name" {
  value       = helm_release.harbor.name
  description = "Helm release name for Harbor"
}

output "notes" {
  value = var.expose_ingress ? (
    var.hostname != null ? "Access Harbor at https://${var.hostname}" : "Set harbor_hostname to a valid DNS name and install an ingress controller"
  ) : "Access Harbor via service '${local.release_name}-harbor-core' (ClusterIP/NodePort depending on service_type). Use kubectl port-forward svc/${local.release_name}-harbor-core 8080:80 -n ${var.namespace}"
}
