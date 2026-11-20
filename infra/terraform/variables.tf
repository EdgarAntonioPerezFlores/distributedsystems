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
variable "k3s_version" {
  type    = string
  default = "v1.33.5+k3s1"
}
