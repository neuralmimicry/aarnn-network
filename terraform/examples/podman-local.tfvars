# Example: Run locally with Podman
# Requirements:
# - Podman running with a Docker-compatible socket
#   Rootless example: systemctl --user enable --now podman.socket
#   DOCKER_HOST=unix:///run/user/1000/podman/podman.sock

project_name = "aarnn-net"

aeron_git_ref = "master"
aarnn_git_ref = "main"

deployment_target = "podman"

enable_monitoring = true
enable_logging    = false

# Point the Docker provider at the Podman socket
# Alternatively, export DOCKER_HOST in your environment
# On Linux rootless (UID may vary):
# export DOCKER_HOST=unix:///run/user/$(id -u)/podman/podman.sock

docker_host = "unix:///run/user/1000/podman/podman.sock"

# Optional registry auth if you need to pull/push private bases
# docker_registry_address  = null
# docker_registry_username = null
# docker_registry_password = null
