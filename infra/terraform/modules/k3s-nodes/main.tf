terraform {
  required_version = ">= 1.10"
}
variable "servers" { type = list(string) }
variable "login" { type = string }
variable "version_k3s" { type = string }
variable "kubeconfig" { type = string }
resource "terraform_data" "install" {
  triggers_replace = [var.servers, var.version_k3s, var.kubeconfig, filesha256("${path.module}/install.sh")]
  provisioner "local-exec" {
    command = "bash \"${path.module}/install.sh\""
    environment = {
      SERVERS     = join(" ", var.servers)
      SSH_USER    = var.login
      K3S_VERSION = var.version_k3s
      KCFG        = var.kubeconfig
    }
  }
}
