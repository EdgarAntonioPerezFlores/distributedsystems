terraform {
  required_providers {
    flux = { source = "fluxcd/flux" }
  }
}
variable "environment" { type = string }
resource "flux_bootstrap_git" "cluster" {
  path             = "clusters/${var.environment}"
  components_extra = ["image-reflector-controller", "image-automation-controller"]
}
