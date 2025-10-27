############################################
# Kubernetes deployment for Aeron and AARNN
############################################

locals {
  labels = {
    project = var.project_name
  }
  extra_map = { for a in var.extra_apps : a["name"] => a }
}

resource "kubernetes_namespace" "ns" {
  metadata {
    name = var.namespace
    labels = local.labels
  }
}

# Aeron Deployment (media driver)
resource "kubernetes_deployment" "aeron" {
  metadata {
    name      = "${var.project_name}-aeron"
    namespace = kubernetes_namespace.ns.metadata[0].name
    labels    = merge(local.labels, { app = "aeron" })
  }
  spec {
    replicas = 1
    selector {
      match_labels = { app = "aeron" }
    }
    template {
      metadata {
        labels = merge(local.labels, { app = "aeron" })
      }
      spec {
        node_selector = var.node_selector

        dynamic "toleration" {
          for_each = var.tolerations
          content {
            key      = toleration.value.key
            operator = try(toleration.value.operator, null)
            value    = try(toleration.value.value, null)
            effect   = try(toleration.value.effect, null)
          }
        }

        container {
          name  = "aeron"
          image = var.aeron_image
          image_pull_policy = "IfNotPresent"

          resources {
            requests = {
              cpu    = var.aeron_container_cpu
              memory = var.aeron_container_memory
            }
            limits = var.enable_gpu ? { "nvidia.com/gpu" = tostring(var.gpu_count) } : null
          }

          liveness_probe {
            exec {
              command = ["/bin/sh", "-lc", "ps aux | grep -v grep | grep -q java"]
            }
            initial_delay_seconds = 20
            period_seconds        = 15
            timeout_seconds       = 5
            failure_threshold     = 6
          }

          command = ["bash", "-lc", "java --add-exports=java.base/jdk.internal.misc=ALL-UNNAMED -cp /aeron/aeron-all.jar io.aeron.driver.MediaDriver"]
        }
      }
    }
  }
}

# AARNN Deployment
resource "kubernetes_deployment" "aarnn" {
  metadata {
    name      = "${var.project_name}-aarnn"
    namespace = kubernetes_namespace.ns.metadata[0].name
    labels    = merge(local.labels, { app = "aarnn" })
  }
  spec {
    replicas = 1
    selector {
      match_labels = { app = "aarnn" }
    }
    template {
      metadata {
        labels = merge(local.labels, { app = "aarnn" })
      }
      spec {
        node_selector = var.node_selector

        dynamic "toleration" {
          for_each = var.tolerations
          content {
            key      = toleration.value.key
            operator = try(toleration.value.operator, null)
            value    = try(toleration.value.value, null)
            effect   = try(toleration.value.effect, null)
          }
        }

        container {
          name  = "aarnn"
          image = var.aarnn_image
          image_pull_policy = "IfNotPresent"

          env {
            name  = "AERON_DIR"
            value = "/aeron"
          }

          env {
            name  = "AERON_MEDIA_DRIVER_ENDPOINT"
            value = "${var.project_name}-aeron:40123"
          }

          port {
            name           = "http"
            container_port = 8080
            protocol       = "TCP"
          }

          resources {
            requests = {
              cpu    = var.aarnn_container_cpu
              memory = var.aarnn_container_memory
            }
            limits = var.enable_gpu ? { "nvidia.com/gpu" = var.gpu_count } : null
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 8080
            }
            initial_delay_seconds = 30
            period_seconds        = 15
            timeout_seconds       = 5
            failure_threshold     = 6
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 8080
            }
            initial_delay_seconds = 10
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 6
          }
        }
      }
    }
  }
}

# Service for AARNN
resource "kubernetes_service" "aarnn" {
  metadata {
    name      = "${var.project_name}-aarnn"
    namespace = kubernetes_namespace.ns.metadata[0].name
    labels    = merge(local.labels, { app = "aarnn" })
  }
  spec {
    selector = { app = "aarnn" }
    port {
      name        = "http"
      port        = 8080
      target_port = 8080
      protocol    = "TCP"
    }
    type = var.service_type
  }
}

output "namespace" {
  value       = kubernetes_namespace.ns.metadata[0].name
  description = "Namespace where resources were created"
}

output "aarnn_service_name" {
  value       = kubernetes_service.aarnn.metadata[0].name
  description = "Service name for AARNN"
}

############################################
# Generic apps from manifest
############################################

locals {
  extra_health_paths = { for k, v in local.extra_map : k => coalesce(try(v["health_path"], null), "/health") }
}

resource "kubernetes_deployment" "extra" {
  for_each = local.extra_map

  metadata {
    name      = "${var.project_name}-${each.key}"
    namespace = kubernetes_namespace.ns.metadata[0].name
    labels    = merge(local.labels, { app = each.key })
  }
  spec {
    replicas = 1
    selector {
      match_labels = { app = each.key }
    }
    template {
      metadata {
        labels = merge(local.labels, { app = each.key })
      }
      spec {
        node_selector = var.node_selector

        dynamic "toleration" {
          for_each = var.tolerations
          content {
            key      = toleration.value.key
            operator = try(toleration.value.operator, null)
            value    = try(toleration.value.value, null)
            effect   = try(toleration.value.effect, null)
          }
        }

        container {
          name  = each.key
          image = coalesce(try(each.value["image"], null), "")
          image_pull_policy = "IfNotPresent"

          dynamic "env" {
            for_each = try(each.value["env"], {})
            content {
              name  = env.key
              value = env.value
            }
          }

          dynamic "port" {
            for_each = try(each.value["port"], null) != null ? [1] : []
            content {
              name           = "http"
              container_port = tonumber(tostring(each.value["port"]))
              protocol       = "TCP"
            }
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "256Mi"
            }
            limits = var.enable_gpu ? { "nvidia.com/gpu" = var.gpu_count } : null
          }

          dynamic "liveness_probe" {
            for_each = try(each.value["port"], null) != null ? [1] : []
            content {
              http_get {
                path = local.extra_health_paths[each.key]
                port = tonumber(tostring(each.value["port"]))
              }
              initial_delay_seconds = 20
              period_seconds        = 15
              timeout_seconds       = 5
              failure_threshold     = 6
            }
          }

          dynamic "readiness_probe" {
            for_each = try(each.value["port"], null) != null ? [1] : []
            content {
              http_get {
                path = local.extra_health_paths[each.key]
                port = tonumber(tostring(each.value["port"]))
              }
              initial_delay_seconds = 10
              period_seconds        = 10
              timeout_seconds       = 5
              failure_threshold     = 6
            }
          }

          command = try(each.value["cmd"], null)
        }
      }
    }
  }
}

resource "kubernetes_service" "extra" {
  for_each = { for k, v in local.extra_map : k => v if try(v["port"], null) != null }

  metadata {
    name      = "${var.project_name}-${each.key}"
    namespace = kubernetes_namespace.ns.metadata[0].name
    labels    = merge(local.labels, { app = each.key })
  }
  spec {
    selector = { app = each.key }
    port {
      name        = "http"
      port        = tonumber(tostring(each.value["port"]))
      target_port = tonumber(tostring(each.value["port"]))
      protocol    = "TCP"
    }
    type = var.service_type
  }
}

output "extra_service_names" {
  value       = { for k, v in kubernetes_service.extra : k => v.metadata[0].name }
  description = "Service names for extra generic apps (only those with ports)"
}
