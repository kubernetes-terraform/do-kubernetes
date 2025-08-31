resource "digitalocean_kubernetes_cluster" "techpreta" {
  name    = var.cluster_name
  region  = var.region
  version = var.k8s_version

  node_pool {
    name       = var.node_pool_name
    size       = var.node_pool_size
    auto_scale = var.node_pool_auto_scale
    min_nodes  = var.node_pool_min_nodes
    max_nodes  = var.node_pool_max_nodes
  }
}
