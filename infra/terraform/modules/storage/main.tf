terraform {
  required_version = ">= 1.10"
}
variable "kubeconfig" { type = string }
resource "terraform_data" "storage" {
  provisioner "local-exec" {
    command     = "kubectl get storageclass local-path"
    environment = { KUBECONFIG = var.kubeconfig }
  }
}
