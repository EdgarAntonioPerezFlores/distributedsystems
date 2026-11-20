terraform {
  required_version = ">= 1.10"
  required_providers {
    flux = { source = "fluxcd/flux", version = "~> 1.5.0" }
  }
}
variable "environment" { type = string }
resource "flux_bootstrap_git" "cluster" {
  path             = "clusters/${var.environment}"
  components_extra = ["image-reflector-controller", "image-automation-controller"]
}
