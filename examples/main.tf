module "do_kubernetes" {
  source                = "./.."
  cluster_name          = var.cluster_name
  region                = var.region
  k8s_version           = var.k8s_version
  node_pool_name        = var.node_pool_name
  node_pool_size        = var.node_pool_size
  node_pool_auto_scale  = var.node_pool_auto_scale
  node_pool_min_nodes   = var.node_pool_min_nodes
  node_pool_max_nodes   = var.node_pool_max_nodes
  cloudflare_api_token  = var.cloudflare_api_token
  r2_access_key         = var.r2_access_key
  r2_access_secret      = var.r2_access_secret
  do_pat                = var.do_pat
  cloudflare_account_id = var.cloudflare_account_id
}
