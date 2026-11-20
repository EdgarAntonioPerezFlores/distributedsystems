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
