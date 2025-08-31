# Configuração para Ambiente de Desenvolvimento

Este exemplo mostra como configurar um cluster Kubernetes na DigitalOcean otimizado para desenvolvimento e testes.

## 🎯 Características do Ambiente de Desenvolvimento

- **Prioridade**: Agilidade e economia de custos
- **Downtime**: Aceitável durante upgrades
- **Recursos**: Mínimos necessários para desenvolvimento
- **Automação**: Máxima para reduzir overhead

## ⚙️ Configuração Completa

### Arquivo `environments/development/terraform.tfvars`

```hcl
# =============================================================================
# CONFIGURAÇÕES BÁSICAS
# =============================================================================

cluster_name        = "dev-k8s-cluster"
region             = "fra1"                    # Frankfurt (próximo da Europa)
kubernetes_version = "1.28.2-do.0"
environment        = "development"
project           = "meu-projeto"
cost_center       = "engineering"

# =============================================================================
# CONFIGURAÇÕES DE UPGRADE - DESENVOLVIMENTO
# =============================================================================

# Auto upgrade HABILITADO para ter sempre versões mais recentes
auto_upgrade_enabled  = true

# Surge upgrade DESABILITADO para economia de custos
surge_upgrade_enabled = false

# Manutenção flexível - qualquer dia, horário baixo
maintenance_policy = {
  start_time = "02:00"    # 2:00 AM
  day        = "any"      # Qualquer dia da semana
}

# =============================================================================
# NODE POOLS - CONFIGURAÇÃO ECONÔMICA
# =============================================================================

node_pools = {
  # Pool principal para desenvolvimento
  developers = {
    size       = "s-2vcpu-2gb"    # Pequeno e econômico
    node_count = 2                # Mínimo para HA básico
    min_nodes  = 1                # Pode reduzir para 1 se necessário
    max_nodes  = 4                # Pode escalar para picos de desenvolvimento
    auto_scale = true             # Auto scale habilitado
    tags       = ["development", "workers", "auto-scale"]
    labels = {
      role        = "worker"
      tier        = "development"
      workload    = "general"
      cost-opt    = "enabled"
    }
    taints = []                   # Sem taints para simplicidade
  }
}

# =============================================================================
# CONFIGURAÇÕES DE REDE - SIMPLES
# =============================================================================

# Cluster público para facilitar acesso durante desenvolvimento
enable_private_cluster = false
vpc_uuid              = null
service_subnet        = null
pod_subnet           = null

# =============================================================================
# TAGS ESPECÍFICAS DE DESENVOLVIMENTO
# =============================================================================

additional_tags = [
  "auto-shutdown:enabled",      # Permite shutdown automático
  "cost-optimization:aggressive", # Otimização agressiva de custos
  "monitoring:basic",           # Monitoramento básico
  "backup:not-required",        # Backup não crítico
  "environment:dev"
]
```

### Arquivo `environments/development/main.tf`

```hcl
# =============================================================================
# CONFIGURAÇÃO TERRAFORM PARA DESENVOLVIMENTO
# =============================================================================

terraform {
  required_version = ">= 1.0"
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.32"
    }
  }
  
  # Backend local para desenvolvimento (não usar em produção)
  backend "local" {
    path = "terraform.tfstate"
  }
}

# =============================================================================
# PROVIDER
# =============================================================================

provider "digitalocean" {
  # Token via variável de ambiente DIGITALOCEAN_TOKEN
}

# =============================================================================
# DATA SOURCES
# =============================================================================

data "digitalocean_kubernetes_versions" "dev" {
  version_prefix = "1.28."
}

data "digitalocean_sizes" "dev" {}

# =============================================================================
# LOCALS PARA DESENVOLVIMENTO
# =============================================================================

locals {
  # Tags padrão otimizadas para dev
  default_tags = [
    "environment:${var.environment}",
    "project:${var.project}",
    "managed-by:terraform",
    "auto-delete:enabled"        # Permite deleção automática
  ]
  
  all_tags = concat(local.default_tags, var.additional_tags)
  
  # Configuração específica para desenvolvimento
  dev_config = {
    auto_upgrade            = true    # Sempre habilitado em dev
    surge_upgrade          = false   # Desabilitado para economia
    enable_monitoring      = false   # Monitoramento básico
    backup_retention_days  = 1       # Backup mínimo
    log_retention_days     = 7       # Logs por 1 semana
  }
}

# =============================================================================
# CLUSTER KUBERNETES PARA DESENVOLVIMENTO
# =============================================================================

resource "digitalocean_kubernetes_cluster" "dev" {
  name     = var.cluster_name
  region   = var.region
  version  = var.kubernetes_version
  
  # Configurações de upgrade para desenvolvimento
  auto_upgrade  = local.dev_config.auto_upgrade
  surge_upgrade = local.dev_config.surge_upgrade
  
  # Política de manutenção flexível
  maintenance_policy {
    start_time = var.maintenance_policy.start_time
    day        = var.maintenance_policy.day
  }
  
  # Tags específicas
  tags = local.all_tags
  
  # Node pool temporário (será removido)
  node_pool {
    name       = "default-pool"
    size       = "s-1vcpu-2gb"
    node_count = 1
    tags       = concat(local.all_tags, ["temporary"])
  }
  
  # Destroy protection desabilitado para dev
  lifecycle {
    prevent_destroy = false
    ignore_changes = [node_pool]
  }
}

# =============================================================================
# NODE POOLS DEDICADOS
# =============================================================================

resource "digitalocean_kubernetes_node_pool" "dev_pools" {
  for_each = var.node_pools
  
  cluster_id = digitalocean_kubernetes_cluster.dev.id
  
  name       = each.key
  size       = each.value.size
  node_count = each.value.node_count
  
  # Auto scaling para otimização de custos
  auto_scale = each.value.auto_scale
  min_nodes  = each.value.auto_scale ? each.value.min_nodes : null
  max_nodes  = each.value.auto_scale ? each.value.max_nodes : null
  
  # Labels com informações de desenvolvimento
  labels = merge(
    each.value.labels,
    {
      "node-pool"     = each.key
      "cluster-name"  = var.cluster_name
      "auto-shutdown" = "enabled"
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
# CONFIGURAÇÕES DE DESENVOLVIMENTO ADICIONAIS
# =============================================================================

# Namespace para desenvolvimento
resource "kubernetes_namespace" "development" {
  depends_on = [digitalocean_kubernetes_cluster.dev]
  
  metadata {
    name = "development"
    
    labels = {
      environment = var.environment
      project     = var.project
      tier        = "development"
    }
  }
}

# ConfigMap com configurações de desenvolvimento
resource "kubernetes_config_map" "dev_config" {
  depends_on = [kubernetes_namespace.development]
  
  metadata {
    name      = "dev-cluster-config"
    namespace = "development"
  }
  
  data = {
    cluster_name    = var.cluster_name
    environment     = var.environment
    auto_upgrade    = tostring(local.dev_config.auto_upgrade)
    surge_upgrade   = tostring(local.dev_config.surge_upgrade)
    cost_optimization = "enabled"
    debug_mode      = "true"
  }
}

# =============================================================================
# OUTPUTS
# =============================================================================

output "cluster_info" {
  description = "Informações básicas do cluster de desenvolvimento"
  value = {
    id          = digitalocean_kubernetes_cluster.dev.id
    name        = digitalocean_kubernetes_cluster.dev.name
    region      = digitalocean_kubernetes_cluster.dev.region
    version     = digitalocean_kubernetes_cluster.dev.version
    endpoint    = digitalocean_kubernetes_cluster.dev.endpoint
    status      = digitalocean_kubernetes_cluster.dev.status
  }
}

output "cost_optimization" {
  description = "Informações de otimização de custos"
  value = {
    auto_upgrade     = local.dev_config.auto_upgrade
    surge_upgrade    = local.dev_config.surge_upgrade
    min_nodes_total  = sum([for pool in var.node_pools : pool.min_nodes])
    max_nodes_total  = sum([for pool in var.node_pools : pool.max_nodes])
    estimated_cost   = "~$48-96/mês (baseado em uso típico de dev)"
  }
}

output "kubeconfig_command" {
  description = "Comando para obter kubeconfig"
  value       = "doctl kubernetes cluster kubeconfig save ${digitalocean_kubernetes_cluster.dev.name}"
}

output "useful_commands" {
  description = "Comandos úteis para desenvolvimento"
  value = {
    get_nodes       = "kubectl get nodes -o wide"
    get_pods        = "kubectl get pods --all-namespaces"
    cluster_info    = "kubectl cluster-info"
    dev_namespace   = "kubectl config set-context --current --namespace=development"
  }
}
```

### Arquivo `environments/development/variables.tf`

```hcl
# Este arquivo inclui todas as variáveis do arquivo principal
# Veja configuration-guide.md para definições completas

variable "cluster_name" {
  description = "Nome do cluster Kubernetes"
  type        = string
}

variable "region" {
  description = "Região da DigitalOcean"
  type        = string
  default     = "fra1"
}

variable "kubernetes_version" {
  description = "Versão do Kubernetes"
  type        = string
  default     = "1.28.2-do.0"
}

variable "environment" {
  description = "Ambiente (development)"
  type        = string
  default     = "development"
}

variable "project" {
  description = "Nome do projeto"
  type        = string
}

variable "cost_center" {
  description = "Centro de custo"
  type        = string
  default     = "engineering"
}

variable "auto_upgrade_enabled" {
  description = "Habilita upgrade automático (true para dev)"
  type        = bool
  default     = true
}

variable "surge_upgrade_enabled" {
  description = "Habilita surge upgrade (false para dev - economia)"
  type        = bool
  default     = false
}

variable "maintenance_policy" {
  description = "Política de manutenção flexível para dev"
  type = object({
    start_time = string
    day        = string
  })
  default = {
    start_time = "02:00"
    day        = "any"
  }
}

variable "node_pools" {
  description = "Node pools otimizados para desenvolvimento"
  type = map(object({
    size           = string
    node_count     = number
    min_nodes      = number
    max_nodes      = number
    auto_scale     = bool
    tags           = list(string)
    labels         = map(string)
    taints         = list(object({
      key    = string
      value  = string
      effect = string
    }))
  }))
}

variable "enable_private_cluster" {
  description = "Cluster privado (false para dev - facilitar acesso)"
  type        = bool
  default     = false
}

variable "vpc_uuid" {
  description = "VPC UUID (null para dev - usar default)"
  type        = string
  default     = null
}

variable "service_subnet" {
  description = "Service subnet (null para dev)"
  type        = string
  default     = null
}

variable "pod_subnet" {
  description = "Pod subnet (null para dev)"
  type        = string
  default     = null
}

variable "additional_tags" {
  description = "Tags adicionais específicas para desenvolvimento"
  type        = list(string)
  default     = []
}
```

## 🚀 Como Usar

### 1. Preparação

```bash
# Clone o repositório
git clone <repo-url>
cd terraform/environments/development

# Configure credenciais da DigitalOcean
export DIGITALOCEAN_TOKEN="seu-token-aqui"
```

### 2. Customização

Edite o arquivo `terraform.tfvars`:

```hcl
# Personalize estas variáveis
cluster_name = "meu-dev-cluster"
project     = "meu-projeto"
region      = "fra1"  # ou sua região preferida

# Opcionalmente, ajuste os node pools
node_pools = {
  developers = {
    size       = "s-2vcpu-2gb"  # ou "s-1vcpu-2gb" para economia máxima
    node_count = 2
    min_nodes  = 1
    max_nodes  = 3              # Ajuste conforme sua equipe
    auto_scale = true
    tags       = ["development", "team-backend"]  # Personalize tags
    labels = {
      role = "worker"
      team = "backend"          # Adicione labels da sua equipe
    }
    taints = []
  }
}
```

### 3. Deploy

```bash
# Inicializar Terraform
terraform init

# Planejar mudanças
terraform plan

# Aplicar (confirmando)
terraform apply

# Obter kubeconfig
doctl kubernetes cluster kubeconfig save meu-dev-cluster
```

### 4. Verificação

```bash
# Verificar cluster
kubectl cluster-info
kubectl get nodes -o wide

# Verificar namespace de desenvolvimento
kubectl get namespaces
kubectl config set-context --current --namespace=development

# Verificar configurações
kubectl get configmap dev-cluster-config -o yaml
```

## 💰 Estimativa de Custos

### Configuração Básica (recomendada)

```
2x s-2vcpu-2gb nodes = 2 × $24/mês = $48/mês
Load Balancer = $12/mês
Total estimado: ~$60/mês
```

### Configuração Mínima (economia máxima)

```
1x s-1vcpu-2gb node = $18/mês
Load Balancer = $12/mês
Total estimado: ~$30/mês
```

### Durante Picos de Desenvolvimento

```
Auto scale para 3-4 nodes = $72-96/mês temporariamente
Volta ao mínimo automaticamente
```

## 🔧 Otimizações para Desenvolvimento

### 1. Auto Shutdown (Economia)

Configure shutdown automático para fins de semana:

```bash
# Script para parar cluster em fins de semana
# Adicione ao cron da sua máquina de DevOps
0 18 * * 5 doctl kubernetes cluster delete meu-dev-cluster --force
0 8 * * 1 terraform apply -auto-approve
```

### 2. Resource Quotas (Controle)

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: dev-quota
  namespace: development
spec:
  hard:
    requests.cpu: "4"
    requests.memory: "8Gi"
    limits.cpu: "8"
    limits.memory: "16Gi"
    pods: "20"
```

### 3. Network Policies (Segurança Básica)

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: dev-network-policy
  namespace: development
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: development
  egress:
  - {}  # Permite todo tráfego de saída
```

## 🛠️ Desenvolvimento Day-to-Day

### Comandos Úteis

```bash
# Status rápido do cluster
kubectl get nodes,pods --all-namespaces

# Logs de aplicações
kubectl logs -f deployment/minha-app -n development

# Port forward para debugging
kubectl port-forward service/minha-app 8080:80 -n development

# Executar comandos dentro de pods
kubectl exec -it deployment/minha-app -- /bin/bash

# Aplicar manifests de desenvolvimento
kubectl apply -f manifests/ -n development
```

### Hot Reload e Desenvolvimento

```yaml
# Deployment otimizado para desenvolvimento
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dev-app
  namespace: development
spec:
  replicas: 1                    # Apenas 1 réplica para dev
  strategy:
    type: Recreate              # Recreate é mais rápido para dev
  template:
    spec:
      containers:
      - name: app
        image: minha-app:dev
        env:
        - name: ENV
          value: "development"
        - name: DEBUG
          value: "true"
        resources:
          requests:
            cpu: "100m"           # Requests mínimos
            memory: "128Mi"
          limits:
            cpu: "500m"           # Limits permissivos para dev
            memory: "512Mi"
        volumeMounts:
        - name: code
          mountPath: /app         # Mount de código para hot reload
      volumes:
      - name: code
        hostPath:
          path: /local/code       # Código local (se usando local dev)
```

## 📚 Próximos Passos

1. 🧪 **Teste a configuração**: Deploy uma aplicação simples
2. 📊 **Configure monitoramento básico**: Prometheus ou similar
3. 🔄 **Teste upgrades**: Force um upgrade para verificar comportamento
4. 📈 **Monitore custos**: Configure alertas de billing na DigitalOcean
5. 🚀 **Evolua para staging**: Use como base para ambiente de staging

## 🔗 Links Relacionados

- [Configuração de Staging](staging.md)
- [Configuração de Produção](production.md)
- [Guia de Configuração Completo](../configuration-guide.md)
- [FAQ](../faq.md)

---

**Dica**: Este ambiente é otimizado para agilidade e economia. Para ambientes críticos, veja as configurações de [produção](production.md).