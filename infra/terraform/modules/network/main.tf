terraform {
  required_version = ">= 1.10"
}
variable "servers" { type = list(string) }
output "servers" { value = var.servers }
