variable "cluster_name" {
  description = "The name of the Kubernetes cluster"
  type        = string
  default     = "techpreta"
}

variable "region" {
  description = "The region where the Kubernetes cluster will be deployed"
  type        = string
  default     = "nyc1"
}

variable "k8s_version" {
  description = "The version of Kubernetes to deploy"
  type        = string
  default     = "1.33.1-do.3"
}

variable "node_pool_name" {
  description = "The name of the node pool"
  type        = string
  default     = "techpreta-nodepool"
}

variable "node_pool_size" {
  description = "The size of the node pool"
  type        = string
  default     = "s-2vcpu-2gb"
}

variable "node_pool_auto_scale" {
  description = "Whether to enable auto-scaling for the node pool"
  type        = bool
  default     = true
}

variable "node_pool_min_nodes" {
  description = "The minimum number of nodes in the node pool"
  type        = number
  default     = 3
}

variable "node_pool_max_nodes" {
  description = "The maximum number of nodes in the node pool"
  type        = number
  default     = 5
}

variable "cloudflare_api_token" {
  description = "Token de API da Cloudflare"
  type        = string
  sensitive   = true
}

variable "r2_access_key" {
  type        = string
  sensitive   = true
  description = "ID da chave de acesso R2"
}

variable "r2_access_secret" {
  type        = string
  sensitive   = true
  description = "Segredo da chave de acesso R2"
}

variable "cloudflare_account_id" {
  description = "ID da conta Cloudflare"
  type        = string
  default     = "4839c9636a58fa9490bbe3d2e686ad98"
}

variable "do_pat" {
  description = "DigitalOcean Personal Access Token"
  type        = string
  sensitive   = true
}
