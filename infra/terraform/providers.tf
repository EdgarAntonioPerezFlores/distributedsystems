provider "flux" {
  kubernetes = { config_path = pathexpand(var.kubeconfig) }
  git        = { url = var.git_url, branch = var.git_branch, ssh = { username = "git", private_key = file(pathexpand(var.git_key_file)) } }
}
