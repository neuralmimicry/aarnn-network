# AARNN Network

Infrastructure-as-Code to build, run, and optionally publish container images for:
- Aeron (github.com/aeron-io/aeron)
- AARNN (github.com/neuralmimicry/aarnn)

Quick start
- See terraform/README.md for full instructions.
- For a full catalog of variables and how to supply credentials/secrets safely, see the sections "Variables and configuration (complete)" and "Credentials and secrets" in terraform/README.md.
- TL;DR:
  - cd terraform
  - terraform init
  - terraform apply -var-file=examples/local-only.tfvars

What you get
- Local Docker network and two sibling containers: Aeron Media Driver and AARNN
- Optional cloud registry provisioning for AWS ECR, GCP Artifact Registry, Azure ACR (disabled by default)

Notes
- This repository contains only Terraform and templates; no upstream code is vendored.
- Images are built from the specified Git refs at apply time.
