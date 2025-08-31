# Guia de Configuração - Kubernetes DigitalOcean

Este guia fornece instruções detalhadas sobre como configurar as variáveis do Terraform para upgrades de Kubernetes na DigitalOcean.

## 🎯 Visão Geral

Este guia aborda:
- Como configurar variáveis no Terraform
- Exemplos para diferentes cenários (dev, staging, prod)
- Considerações de segurança e performance
- Troubleshooting comum

## 📁 Estrutura de Arquivos Terraform

### Organização Recomendada

```
terraform/
├── environments/
│   ├── development/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── terraform.tfvars
│   ├── staging/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── terraform.tfvars
│   └── production/
│       ├── main.tf
│       ├── variables.tf
│       └── terraform.tfvars
├── modules/
│   └── do-kubernetes/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── shared/
    ├── versions.tf
    └── providers.tf
```

## 🔧 Configuração de Variáveis

### 1. Arquivo `variables.tf`

```hcl
# =============================================================================
# CONFIGURAÇÕES GERAIS DO CLUSTER
# =============================================================================

variable "cluster_name" {
  description = "Nome do cluster Kubernetes"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.cluster_name))
    error_message = "O nome do cluster deve conter apenas letras minúsculas, números e hífens."
  }
}

variable "region" {
  description = "Região da DigitalOcean para o cluster"
  type        = string
  default     = "nyc1"
  validation {
    condition = contains([
      "nyc1", "nyc3", "ams3", "fra1", "lon1", 
      "sfo3", "sgp1", "tor1", "blr1", "syd1"
    ], var.region)
    error_message = "Região deve ser uma região válida da DigitalOcean."
  }
}

variable "kubernetes_version" {
  description = "Versão do Kubernetes"
  type        = string
  default     = "1.28.2-do.0"
  validation {
    condition     = can(regex("^\\d+\\.\\d+\\.\\d+-do\\.\\d+$", var.kubernetes_version))
    error_message = "Versão deve seguir o formato: x.y.z-do.n"
  }
}

# =============================================================================
# CONFIGURAÇÕES DE UPGRADE
# =============================================================================

variable "auto_upgrade_enabled" {
  description = "Habilita upgrade automático do control plane"
  type        = bool
  default     = false
}

variable "surge_upgrade_enabled" {
  description = "Habilita surge upgrade para zero downtime"
  type        = bool
  default     = false
}

variable "maintenance_policy" {
  description = "Política de manutenção para upgrades automáticos"
  type = object({
    start_time = string
    day        = string
  })
  default = {
    start_time = "04:00"
    day        = "sunday"
  }
  validation {
    condition = contains([
      "monday", "tuesday", "wednesday", "thursday",
      "friday", "saturday", "sunday", "any"
    ], var.maintenance_policy.day)
    error_message = "Dia deve ser um dia da semana válido ou 'any'."
  }
  validation {
    condition     = can(regex("^([01]?[0-9]|2[0-3]):[0-5][0-9]$", var.maintenance_policy.start_time))
    error_message = "Horário deve estar no formato HH:MM (24h)."
  }
}

variable "surge_config" {
  description = "Configurações detalhadas do surge upgrade"
  type = object({
    max_surge       = string
    max_unavailable = string
  })
  default = {
    max_surge       = "1"
    max_unavailable = "0"
  }
}

# =============================================================================
# CONFIGURAÇÕES DE NODE POOL
# =============================================================================

variable "node_pools" {
  description = "Configuração dos node pools"
  type = map(object({
    size           = string
    node_count     = number
    min_nodes      = number
    max_nodes      = number
    auto_scale     = bool
    tags           = list(string)
    labels         = map(string)
    taints = list(object({
      key    = string
      value  = string
      effect = string
    }))
  }))
  default = {
    primary = {
      size       = "s-2vcpu-2gb"
      node_count = 3
      min_nodes  = 3
      max_nodes  = 5
      auto_scale = true
      tags       = ["primary", "worker"]
      labels     = { role = "worker" }
      taints     = []
    }
  }
}

# =============================================================================
# CONFIGURAÇÕES DE SEGURANÇA
# =============================================================================

variable "enable_private_cluster" {
  description = "Habilita cluster privado (nodes sem IP público)"
  type        = bool
  default     = false
}

variable "vpc_uuid" {
  description = "UUID da VPC para o cluster (opcional)"
  type        = string
  default     = null
}

variable "service_subnet" {
  description = "Subnet CIDR para services (opcional)"
  type        = string
  default     = null
  validation {
    condition     = var.service_subnet == null || can(cidrhost(var.service_subnet, 0))
    error_message = "service_subnet deve ser um CIDR válido."
  }
}

variable "pod_subnet" {
  description = "Subnet CIDR para pods (opcional)"
  type        = string
  default     = null
  validation {
    condition     = var.pod_subnet == null || can(cidrhost(var.pod_subnet, 0))
    error_message = "pod_subnet deve ser um CIDR válido."
  }
}

# =============================================================================
# TAGS E METADADOS
# =============================================================================

variable "environment" {
  description = "Ambiente (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "development", "staging", "prod", "production"], var.environment)
    error_message = "Ambiente deve ser: dev, development, staging, prod, ou production."
  }
}

variable "project" {
  description = "Nome do projeto"
  type        = string
  default     = "default"
}

variable "cost_center" {
  description = "Centro de custo para billing"
  type        = string
  default     = "engineering"
}

variable "additional_tags" {
  description = "Tags adicionais para recursos"
  type        = list(string)
  default     = []
}
```

### 2. Arquivo Principal `main.tf`

```hcl
# =============================================================================
# PROVEDOR E VERSÕES
# =============================================================================

terraform {
  required_version = ">= 1.0"
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.32"
    }
  }
}

# =============================================================================
# DATA SOURCES
# =============================================================================

data "digitalocean_kubernetes_versions" "current" {
  version_prefix = "1.28."
}

data "digitalocean_vpc" "main" {
  count = var.vpc_uuid != null ? 1 : 0
  id    = var.vpc_uuid
}

# =============================================================================
# LOCALS
# =============================================================================

locals {
  # Tags padrão para todos os recursos
  default_tags = [
    "environment:${var.environment}",
    "project:${var.project}",
    "cost-center:${var.cost_center}",
    "managed-by:terraform"
  ]
  
  # Combina tags padrão com tags adicionais
  all_tags = concat(local.default_tags, var.additional_tags)
  
  # Configuração condicional baseada no ambiente
  upgrade_config = {
    development = {
      auto_upgrade  = true
      surge_upgrade = false
    }
    staging = {
      auto_upgrade  = true
      surge_upgrade = true
    }
    production = {
      auto_upgrade  = var.auto_upgrade_enabled
      surge_upgrade = var.surge_upgrade_enabled
    }
  }
  
  # Seleciona configuração baseada no ambiente
  current_config = local.upgrade_config[var.environment] != null ? 
    local.upgrade_config[var.environment] : 
    local.upgrade_config["production"]
}

# =============================================================================
# CLUSTER KUBERNETES
# =============================================================================

resource "digitalocean_kubernetes_cluster" "main" {
  name     = var.cluster_name
  region   = var.region
  version  = var.kubernetes_version
  
  # Configurações de upgrade
  auto_upgrade  = local.current_config.auto_upgrade
  surge_upgrade = local.current_config.surge_upgrade
  
  # Política de manutenção (aplicada apenas se auto_upgrade = true)
  dynamic "maintenance_policy" {
    for_each = local.current_config.auto_upgrade ? [1] : []
    content {
      start_time = var.maintenance_policy.start_time
      day        = var.maintenance_policy.day
    }
  }
  
  # Configurações de rede
  vpc_uuid = var.vpc_uuid
  
  # Tags
  tags = local.all_tags
  
  # Node pool padrão (será removido após criação de pools dedicados)
  node_pool {
    name       = "default-pool"
    size       = "s-1vcpu-2gb"
    node_count = 1
    
    tags = concat(local.all_tags, ["default-pool", "temporary"])
  }
  
  # Lifecycle para evitar recriação desnecessária
  lifecycle {
    ignore_changes = [
      node_pool  # Ignorar mudanças no pool padrão
    ]
  }
}

# =============================================================================
# NODE POOLS DEDICADOS
# =============================================================================

resource "digitalocean_kubernetes_node_pool" "pools" {
  for_each = var.node_pools
  
  cluster_id = digitalocean_kubernetes_cluster.main.id
  
  name       = each.key
  size       = each.value.size
  node_count = each.value.node_count
  
  # Auto scaling
  auto_scale = each.value.auto_scale
  min_nodes  = each.value.auto_scale ? each.value.min_nodes : null
  max_nodes  = each.value.auto_scale ? each.value.max_nodes : null
  
  # Labels personalizados
  labels = merge(
    each.value.labels,
    {
      "node-pool"   = each.key
      "environment" = var.environment
      "project"     = var.project
    }
  )
  
  # Taints
  dynamic "taint" {
    for_each = each.value.taints
    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }
  
  # Tags
  tags = concat(
    local.all_tags,
    each.value.tags,
    ["node-pool:${each.key}"]
  )
}

# =============================================================================
# OUTPUTS
# =============================================================================

output "cluster_id" {
  description = "ID do cluster Kubernetes"
  value       = digitalocean_kubernetes_cluster.main.id
}

output "cluster_name" {
  description = "Nome do cluster Kubernetes"
  value       = digitalocean_kubernetes_cluster.main.name
}

output "cluster_endpoint" {
  description = "Endpoint da API do cluster"
  value       = digitalocean_kubernetes_cluster.main.endpoint
}

output "cluster_status" {
  description = "Status do cluster"
  value       = digitalocean_kubernetes_cluster.main.status
}

output "cluster_version" {
  description = "Versão do Kubernetes do cluster"
  value       = digitalocean_kubernetes_cluster.main.version
}

output "node_pools" {
  description = "Informações dos node pools"
  value = {
    for k, v in digitalocean_kubernetes_node_pool.pools : k => {
      id         = v.id
      name       = v.name
      size       = v.size
      node_count = v.node_count
      nodes      = v.nodes
    }
  }
}

output "kubeconfig" {
  description = "Kubeconfig para acesso ao cluster"
  value       = digitalocean_kubernetes_cluster.main.kube_config[0].raw_config
  sensitive   = true
}
```

## 🌍 Configurações por Ambiente

### Desenvolvimento (`environments/development/terraform.tfvars`)

```hcl
# =============================================================================
# CONFIGURAÇÕES DE DESENVOLVIMENTO
# =============================================================================

cluster_name        = "dev-k8s-cluster"
region             = "fra1"
kubernetes_version = "1.28.2-do.0"
environment        = "development"
project           = "meu-projeto"

# Upgrades: Auto habilitado para testing, surge desabilitado para economia
auto_upgrade_enabled  = true
surge_upgrade_enabled = false

# Manutenção pode ser em qualquer dia (ambiente de dev)
maintenance_policy = {
  start_time = "02:00"
  day        = "any"
}

# Node pools menores para desenvolvimento
node_pools = {
  workers = {
    size       = "s-2vcpu-2gb"
    node_count = 2
    min_nodes  = 1
    max_nodes  = 3
    auto_scale = true
    tags       = ["development", "workers"]
    labels     = { role = "worker", tier = "development" }
    taints     = []
  }
}

# Tags específicas de desenvolvimento
additional_tags = [
  "auto-shutdown:enabled",
  "cost-optimization:aggressive"
]
```

### Staging (`environments/staging/terraform.tfvars`)

```hcl
# =============================================================================
# CONFIGURAÇÕES DE STAGING
# =============================================================================

cluster_name        = "staging-k8s-cluster"
region             = "fra1"
kubernetes_version = "1.28.2-do.0"
environment        = "staging"
project           = "meu-projeto"

# Upgrades: Ambos habilitados para simular produção
auto_upgrade_enabled  = true
surge_upgrade_enabled = true

# Manutenção antes do horário de produção
maintenance_policy = {
  start_time = "01:00"
  day        = "saturday"
}

# Configuração de surge mais conservadora
surge_config = {
  max_surge       = "1"
  max_unavailable = "0"
}

# Node pools similares à produção mas menores
node_pools = {
  workers = {
    size       = "s-2vcpu-4gb"
    node_count = 3
    min_nodes  = 2
    max_nodes  = 5
    auto_scale = true
    tags       = ["staging", "workers"]
    labels     = { role = "worker", tier = "staging" }
    taints     = []
  }
  
  # Pool adicional para teste de workloads específicos
  specialized = {
    size       = "s-4vcpu-8gb"
    node_count = 1
    min_nodes  = 0
    max_nodes  = 2
    auto_scale = true
    tags       = ["staging", "specialized"]
    labels     = { role = "worker", tier = "staging", workload = "specialized" }
    taints = [
      {
        key    = "workload-type"
        value  = "specialized"
        effect = "NoSchedule"
      }
    ]
  }
}

# Tags de staging
additional_tags = [
  "testing:enabled",
  "pre-production:true"
]
```

### Produção (`environments/production/terraform.tfvars`)

```hcl
# =============================================================================
# CONFIGURAÇÕES DE PRODUÇÃO
# =============================================================================

cluster_name        = "prod-k8s-cluster"
region             = "fra1"
kubernetes_version = "1.28.2-do.0"
environment        = "production"
project           = "meu-projeto"

# Upgrades: Controlados manualmente em produção
auto_upgrade_enabled  = false  # Controle manual para produção
surge_upgrade_enabled = true   # Zero downtime é crítico

# Manutenção em horário de menor tráfego
maintenance_policy = {
  start_time = "04:00"
  day        = "sunday"
}

# Configuração conservadora de surge
surge_config = {
  max_surge       = "25%"  # Surge mais controlado
  max_unavailable = "0"    # Zero indisponibilidade
}

# Node pools robustos para produção
node_pools = {
  # Pool principal para workloads gerais
  general = {
    size       = "s-4vcpu-8gb"
    node_count = 5
    min_nodes  = 5
    max_nodes  = 10
    auto_scale = true
    tags       = ["production", "general", "primary"]
    labels     = { 
      role = "worker"
      tier = "production"
      workload = "general"
    }
    taints = []
  }
  
  # Pool para workloads de alta performance
  compute = {
    size       = "c-8vcpu-16gb"
    node_count = 3
    min_nodes  = 2
    max_nodes  = 8
    auto_scale = true
    tags       = ["production", "compute", "high-performance"]
    labels     = {
      role = "worker"
      tier = "production"
      workload = "compute-intensive"
    }
    taints = [
      {
        key    = "workload-type"
        value  = "compute-intensive"
        effect = "NoSchedule"
      }
    ]
  }
  
  # Pool para workloads de alta memória
  memory = {
    size       = "m-4vcpu-32gb"
    node_count = 2
    min_nodes  = 1
    max_nodes  = 5
    auto_scale = true
    tags       = ["production", "memory", "high-memory"]
    labels     = {
      role = "worker"
      tier = "production"
      workload = "memory-intensive"
    }
    taints = [
      {
        key    = "workload-type"
        value  = "memory-intensive"
        effect = "NoSchedule"
      }
    ]
  }
}

# Configurações de rede para produção
enable_private_cluster = true
vpc_uuid              = "your-vpc-uuid-here"
service_subnet        = "10.244.0.0/16"
pod_subnet           = "10.244.64.0/18"

# Tags de produção
additional_tags = [
  "backup:required",
  "monitoring:enhanced",
  "sla:high",
  "disaster-recovery:enabled"
]
```

## 🔐 Considerações de Segurança

### 1. Gerenciamento de Credenciais

```hcl
# providers.tf
provider "digitalocean" {
  # Nunca hardcode tokens!
  # Use variáveis de ambiente: DIGITALOCEAN_TOKEN
  # Ou configure via terraform cloud/enterprise
}

# Para CI/CD, use service accounts com permissões mínimas
variable "do_token" {
  description = "DigitalOcean API Token"
  type        = string
  sensitive   = true
}
```

### 2. Network Security

```hcl
# Configuração para cluster privado
resource "digitalocean_vpc" "main" {
  name   = "${var.project}-${var.environment}-vpc"
  region = var.region
  
  ip_range = "10.10.0.0/16"
  
  tags = local.all_tags
}

# Firewall para nodes do cluster
resource "digitalocean_firewall" "cluster" {
  name = "${var.cluster_name}-firewall"
  
  tags = [digitalocean_kubernetes_cluster.main.node_pool[0].tags[0]]
  
  # Regras de entrada restritivas
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["your-office-ip/32"]  # SSH apenas do escritório
  }
  
  inbound_rule {
    protocol         = "tcp"
    port_range       = "80"
    source_addresses = ["0.0.0.0/0", "::/0"]  # HTTP público
  }
  
  inbound_rule {
    protocol         = "tcp"
    port_range       = "443"
    source_addresses = ["0.0.0.0/0", "::/0"]  # HTTPS público
  }
  
  # Permitir tráfego interno do cluster
  inbound_rule {
    protocol    = "tcp"
    port_range  = "1-65535"
    source_tags = [digitalocean_kubernetes_cluster.main.node_pool[0].tags[0]]
  }
  
  # Regras de saída (permitir tudo por padrão)
  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
  
  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}
```

### 3. RBAC e Pod Security

```yaml
# rbac.yaml - Exemplo de configuração RBAC
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: limited-cluster-reader
rules:
- apiGroups: [""]
  resources: ["nodes", "pods"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch"]

---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: monitoring-sa
  namespace: monitoring

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: monitoring-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: limited-cluster-reader
subjects:
- kind: ServiceAccount
  name: monitoring-sa
  namespace: monitoring
```

## ⚡ Considerações de Performance

### 1. Sizing Apropriado

```hcl
# Tabela de referência para sizing de nodes
locals {
  node_sizes = {
    # Para desenvolvimento e testes
    "small" = {
      size        = "s-2vcpu-2gb"
      max_pods    = 30
      recommended = "desenvolvimento, testes leves"
    }
    
    # Para workloads gerais
    "medium" = {
      size        = "s-4vcpu-8gb"
      max_pods    = 55
      recommended = "aplicações web, APIs"
    }
    
    # Para workloads intensivos
    "large" = {
      size        = "s-8vcpu-16gb"
      max_pods    = 110
      recommended = "databases, processamento"
    }
    
    # Para workloads especializados
    "compute_optimized" = {
      size        = "c-8vcpu-16gb"
      max_pods    = 110
      recommended = "CPU intensivo, builds"
    }
    
    "memory_optimized" = {
      size        = "m-4vcpu-32gb"
      max_pods    = 55
      recommended = "cache, in-memory DBs"
    }
  }
}
```

### 2. Auto Scaling Inteligente

```hcl
# Configuração de auto scaling baseada em métricas
variable "autoscaling_config" {
  description = "Configuração avançada de auto scaling"
  type = object({
    scale_up_threshold   = number
    scale_down_threshold = number
    scale_up_cooldown    = string
    scale_down_cooldown  = string
  })
  default = {
    scale_up_threshold   = 80  # CPU > 80%
    scale_down_threshold = 20  # CPU < 20%
    scale_up_cooldown    = "3m"
    scale_down_cooldown  = "5m"
  }
}
```

## 🔍 Troubleshooting Comum

### 1. Problemas de Configuração

#### Erro: "Invalid cluster configuration"

```bash
# Validar configuração do Terraform
terraform validate

# Verificar plano antes de aplicar
terraform plan -detailed-exitcode

# Aplicar com logs detalhados
TF_LOG=DEBUG terraform apply
```

#### Erro: "Node pool creation failed"

```bash
# Verificar quotas da conta
doctl account get

# Verificar disponibilidade da região
doctl kubernetes options regions

# Verificar tamanhos disponíveis
doctl kubernetes options sizes
```

### 2. Problemas de Upgrade

#### Auto Upgrade não está funcionando

```hcl
# Verificar se a manutenção está configurada corretamente
resource "digitalocean_kubernetes_cluster" "main" {
  auto_upgrade = true
  
  maintenance_policy {
    start_time = "04:00"
    day        = "sunday"
  }
}
```

#### Surge Upgrade causando custos altos

```hcl
# Reduzir o max_surge para controlar custos
surge_config = {
  max_surge       = "1"      # Apenas 1 node extra por vez
  max_unavailable = "0"      # Sem indisponibilidade
}
```

### 3. Comandos Úteis para Debug

```bash
# Verificar status do cluster
doctl kubernetes cluster get <cluster-name>

# Obter kubeconfig
doctl kubernetes cluster kubeconfig save <cluster-name>

# Verificar nodes
kubectl get nodes -o wide

# Verificar eventos do cluster
kubectl get events --sort-by='.metadata.creationTimestamp'

# Verificar estado dos pods
kubectl get pods --all-namespaces -o wide

# Logs do sistema
kubectl logs -n kube-system -l k8s-app=kube-proxy

# Métricas de recursos
kubectl top nodes
kubectl top pods --all-namespaces
```

### 4. Monitoramento e Alertas

```hcl
# Configuração de alertas básicos
resource "digitalocean_monitoring_alert_policy" "high_cpu" {
  alerts {
    email = ["devops@empresa.com"]
    slack {
      channel = "#alerts"
      url     = var.slack_webhook_url
    }
  }
  
  description = "CPU alta nos nodes do cluster"
  type        = "v1/insights/droplet/cpu"
  compare     = "GreaterThan"
  value       = 80
  window      = "5m"
  
  entities = [for pool in digitalocean_kubernetes_node_pool.pools : pool.id]
}

resource "digitalocean_monitoring_alert_policy" "high_memory" {
  alerts {
    email = ["devops@empresa.com"]
  }
  
  description = "Memória alta nos nodes do cluster"
  type        = "v1/insights/droplet/memory_utilization_percent"
  compare     = "GreaterThan"
  value       = 85
  window      = "5m"
  
  entities = [for pool in digitalocean_kubernetes_node_pool.pools : pool.id]
}
```

## 🚀 Próximos Passos

1. 📋 Escolha a configuração apropriada para seu ambiente
2. 🔧 Customize as variáveis conforme suas necessidades
3. 🧪 Teste em ambiente de desenvolvimento primeiro
4. 📊 Configure monitoramento adequado
5. 📚 Consulte os [exemplos específicos](examples/) para mais detalhes

## 📖 Links Úteis

- [Documentação DigitalOcean Kubernetes](https://docs.digitalocean.com/products/kubernetes/)
- [Terraform DigitalOcean Provider](https://registry.terraform.io/providers/digitalocean/digitalocean/latest/docs)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)

---

**Importante**: Sempre revise as configurações em ambiente de teste antes de aplicar em produção.