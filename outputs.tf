output "cluster_name" {
  value = digitalocean_kubernetes_cluster.techpreta.name
}

output "cluster_id" {
  value = digitalocean_kubernetes_cluster.techpreta.id
}

output "endpoint" {
  value = digitalocean_kubernetes_cluster.techpreta.endpoint
}

output "kubeconfig" {
  description = "The kubeconfig file content for the Kubernetes cluster"
  value       = digitalocean_kubernetes_cluster.techpreta.kube_config[0].raw_config
  sensitive   = true
}
