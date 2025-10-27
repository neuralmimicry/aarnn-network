############################################
# Kubernetes Monitoring via Helm
# - Installs kube-prometheus-stack (Prometheus, Alertmanager, Grafana)
# - Optionally installs Loki stack (Loki + Promtail) for logs
# - Respects provided namespace and service types
############################################

locals {
  release_name = "${var.project_name}-monitoring"
  grafana_pass = coalesce(var.grafana_admin_password, "admin")
}

resource "helm_release" "kube_prometheus_stack" {
  name       = local.release_name
  namespace  = var.namespace
  chart      = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  version    = "58.5.0"

  create_namespace = false

  values = [
    yamlencode({
      grafana = {
        adminUser = var.grafana_admin_user
        adminPassword = local.grafana_pass
        service = {
          type = var.service_type
        }
      }
      prometheus = {
        service = {
          type = var.service_type
        }
      }
      alertmanager = {
        service = {
          type = var.service_type
        }
      }
    })
  ]
}

# Optional logging stack (Loki + Promtail)
resource "helm_release" "loki_stack" {
  count      = var.enable_logging ? 1 : 0
  name       = "${var.project_name}-loki"
  namespace  = var.namespace
  chart      = "loki-stack"
  repository = "https://grafana.github.io/helm-charts"
  version    = "2.10.2"

  create_namespace = false

  values = [
    yamlencode({
      grafana = { enabled = false } # Grafana provided by kube-prometheus-stack
      promtail = {
        enabled = true
        service = { type = var.service_type }
      }
      loki = {
        isDefault = true
        service = { type = var.service_type }
      }
    })
  ]
}

output "grafana_service_name" {
  value       = helm_release.kube_prometheus_stack.name
  description = "Name of the kube-prometheus-stack release; Grafana service is typically <release>-grafana"
}

output "notes" {
  value = "Access Grafana via: kubectl -n ${var.namespace} port-forward svc/${local.release_name}-grafana 3000:80"
}
