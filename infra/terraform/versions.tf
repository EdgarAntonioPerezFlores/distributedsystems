terraform {
  required_version = ">= 1.10"
  required_providers {
    flux = { source = "fluxcd/flux", version = "~> 1.5.0" }
  }
  backend "s3" {}
}
