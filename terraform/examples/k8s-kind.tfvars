# Example: Deploy to a local kind cluster
# Prereqs:
# - kind installed and a cluster created: kind create cluster --name aarnn
# - Ensure your kubeconfig is set (usually ~/.kube/config)
# - To use locally built images with kind, you must load them into the cluster:
#   After terraform apply (or before), run:
#   kind load docker-image aeron-local:latest --name aarnn
#   kind load docker-image aarnn-local:latest --name aarnn

project_name = "aarnn-net"

aeron_git_ref = "master"
aarnn_git_ref = "main"

deployment_target = "kubernetes"

kubeconfig_path    = "~/.kube/config"
kubeconfig_context = null

k8s_namespace     = "aarnn"
k8s_service_type  = "ClusterIP"

enable_monitoring = true
enable_logging    = true

# If you push images to a registry, set overrides to reference them
# aeron_image_override = "registry.example.com/aarnn/aeron:latest"
# aarnn_image_override = "registry.example.com/aarnn/aarnn:latest"
