terraform {
  required_version = ">= 1.10"
  required_providers {
    flux = { source = "fluxcd/flux", version = "~> 1.5.0" }
  }
  backend "s3" {}
}
variable "servers" {
  type = list(string)
  validation {
    condition     = length(distinct(var.servers)) == 3 && length(var.servers) == 3 && alltrue([for ip in var.servers : can(cidrnetmask("${ip}/32"))])
    error_message = "Introduce tres IPv4 distintas en el orden inicial, segundo y tercero."
  }
}
variable "ssh_user" { type = string }
variable "kubeconfig" { type = string }
variable "git_url" { type = string }
variable "git_branch" { type = string }
variable "git_key_file" { type = string }
variable "environment" {
  type = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "Usar dev o prod."
  }
}
variable "k3s_version" { default = "v1.33.5+k3s1" }
provider "flux" {
  kubernetes = { config_path = pathexpand(var.kubeconfig) }
  git        = { url = var.git_url, branch = var.git_branch, ssh = { username = "git", private_key = file(pathexpand(var.git_key_file)) } }
}
module "network" {
  source  = "./modules/network"
  servers = var.servers
}
module "nodes" {
  source      = "./modules/k3s-nodes"
  servers     = module.network.servers
  login       = var.ssh_user
  version_k3s = var.k3s_version
  kubeconfig  = pathexpand(var.kubeconfig)
}
module "storage" {
  source     = "./modules/storage"
  depends_on = [module.nodes]
  kubeconfig = pathexpand(var.kubeconfig)
}
module "flux_bootstrap" {
  source      = "./modules/flux-bootstrap"
  environment = var.environment
  depends_on  = [module.storage]
}
