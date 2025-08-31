data "digitalocean_kubernetes_cluster" "primary" {
  name = digitalocean_kubernetes_cluster.techpreta.name
}

resource "local_file" "kubeconfig" {
  depends_on = [digitalocean_kubernetes_cluster.techpreta]
  count      = var.write_kubeconfig ? 1 : 0
  content    = data.digitalocean_kubernetes_cluster.primary.kube_config[0].raw_config
  filename   = "${path.root}/kubeconfig"
}
