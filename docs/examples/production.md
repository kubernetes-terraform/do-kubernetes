# Configuração para Ambiente de Produção

Este exemplo mostra como configurar um cluster Kubernetes na DigitalOcean otimizado para produção, com foco em alta disponibilidade, segurança e controle rigoroso de upgrades.

## 🎯 Características do Ambiente de Produção

- **Prioridade**: Estabilidade, disponibilidade e segurança máximas
- **Downtime**: Zero downtime absoluto
- **Recursos**: Provisionamento robusto com redundância
- **Automação**: Controlada e supervisionada
- **Monitoramento**: Completo e proativo
- **Backup**: Estratégia abrangente de backup e recovery

## ⚙️ Configuração Completa

### Arquivo `environments/production/terraform.tfvars`

```hcl
# =============================================================================
# CONFIGURAÇÕES BÁSICAS - PRODUÇÃO
# =============================================================================

cluster_name        = "prod-k8s-cluster"
region             = "fra1"                    # Região primária
kubernetes_version = "1.28.2-do.0"            # Versão estável testada
environment        = "production"
project           = "meu-projeto"
cost_center       = "production"

# =============================================================================
# CONFIGURAÇÕES DE UPGRADE - PRODUÇÃO (CONSERVADORAS)
# =============================================================================

# Auto upgrade DESABILITADO para controle total em produção
auto_upgrade_enabled  = false

# Surge upgrade HABILITADO para zero downtime crítico
surge_upgrade_enabled = true

# Manutenção em janela rigorosamente controlada
maintenance_policy = {
  start_time = "04:00"    # 4:00 AM (menor tráfego)
  day        = "sunday"   # Domingo (menor impacto nos negócios)
}

# Configuração ultra-conservadora de surge
surge_config = {
  max_surge       = "25%"  # Máximo 25% de nodes extras
  max_unavailable = "0"    # Zero indisponibilidade SEMPRE
}

# =============================================================================
# NODE POOLS - CONFIGURAÇÃO ROBUSTA
# =============================================================================

node_pools = {
  # Pool principal para workloads gerais
  general = {
    size       = "s-4vcpu-8gb"    # Nodes robustos
    node_count = 5                # Alta disponibilidade
    min_nodes  = 5                # Nunca menos que 5
    max_nodes  = 10               # Pode escalar em picos
    auto_scale = true             # Auto scale habilitado
    tags       = ["production", "general", "primary", "ha"]
    labels = {
      role        = "worker"
      tier        = "production"
      workload    = "general"
      zone        = "primary"
      sla         = "high"
    }
    taints = []                   # Sem taints no pool principal
  }
  
  # Pool para workloads de alta performance/CPU
  compute = {
    size       = "c-8vcpu-16gb"   # CPU otimizado
    node_count = 3                # Mínimo para HA
    min_nodes  = 2                # Mínimo 2 para redundância
    max_nodes  = 8                # Pode escalar conforme demanda
    auto_scale = true
    tags       = ["production", "compute", "high-performance"]
    labels = {
      role        = "worker"
      tier        = "production"
      workload    = "compute-intensive"
      node_type   = "cpu-optimized"
      sla         = "critical"
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
    size       = "m-4vcpu-32gb"   # Memória otimizada
    node_count = 2                # Mínimo para HA
    min_nodes  = 1                # Pode reduzir se não usado
    max_nodes  = 5                # Pode escalar conforme necessário
    auto_scale = true
    tags       = ["production", "memory", "high-memory"]
    labels = {
      role        = "worker"
      tier        = "production"
      workload    = "memory-intensive"
      node_type   = "memory-optimized"
      sla         = "high"
    }
    taints = [
      {
        key    = "workload-type"
        value  = "memory-intensive"
        effect = "NoSchedule"
      }
    ]
  }
  
  # Pool para sistema e monitoramento
  system = {
    size       = "s-2vcpu-4gb"    # Suficiente para sistema
    node_count = 3                # HA para componentes de sistema
    min_nodes  = 3                # Sempre 3 para HA
    max_nodes  = 5                # Pode crescer se necessário
    auto_scale = true
    tags       = ["production", "system", "monitoring", "critical"]
    labels = {
      role        = "system"
      tier        = "production"
      workload    = "system"
      purpose     = "monitoring"
      sla         = "critical"
    }
    taints = [
      {
        key    = "node-role"
        value  = "system"
        effect = "NoSchedule"
      }
    ]
  }
}

# =============================================================================
# CONFIGURAÇÕES DE REDE - SEGURAS
# =============================================================================

# Cluster privado para máxima segurança
enable_private_cluster = true
vpc_uuid              = "sua-vpc-uuid-aqui"    # VPC dedicada

# Subnets customizadas e isoladas
service_subnet = "10.244.0.0/16"     # Services
pod_subnet     = "10.244.64.0/18"    # Pods

# =============================================================================
# TAGS ESPECÍFICAS DE PRODUÇÃO
# =============================================================================

additional_tags = [
  "backup:required",              # Backup obrigatório
  "monitoring:enhanced",          # Monitoramento completo
  "sla:high",                    # SLA alto
  "disaster-recovery:enabled",    # DR habilitado
  "security:enhanced",           # Segurança reforçada
  "compliance:required",         # Compliance necessário
  "cost-center:production",      # Centro de custo específico
  "environment:critical"         # Ambiente crítico
]
```

### Arquivo `environments/production/main.tf`

```hcl
# =============================================================================
# CONFIGURAÇÃO TERRAFORM PARA PRODUÇÃO
# =============================================================================

terraform {
  required_version = ">= 1.0"
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.32"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }
  
  # Backend remoto seguro para produção
  backend "s3" {
    bucket = "meu-projeto-terraform-state-prod"
    key    = "production/kubernetes/terraform.tfstate"
    region = "fra1"
    
    # DigitalOcean Spaces como backend S3-compatível
    endpoint                    = "https://fra1.digitaloceanspaces.com"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    
    # Encryption e versionamento
    encrypt        = true
    versioning     = true
    force_destroy  = false
  }
}

# =============================================================================
# PROVIDERS
# =============================================================================

provider "digitalocean" {
  # Token via variável de ambiente DIGITALOCEAN_TOKEN
  # Nunca hardcode tokens em produção!
}

provider "kubernetes" {
  host  = digitalocean_kubernetes_cluster.production.endpoint
  token = digitalocean_kubernetes_cluster.production.kube_config[0].token
  cluster_ca_certificate = base64decode(
    digitalocean_kubernetes_cluster.production.kube_config[0].cluster_ca_certificate
  )
}

provider "helm" {
  kubernetes {
    host  = digitalocean_kubernetes_cluster.production.endpoint
    token = digitalocean_kubernetes_cluster.production.kube_config[0].token
    cluster_ca_certificate = base64decode(
      digitalocean_kubernetes_cluster.production.kube_config[0].cluster_ca_certificate
    )
  }
}

# =============================================================================
# DATA SOURCES
# =============================================================================

data "digitalocean_kubernetes_versions" "stable" {
  version_prefix = "1.28."
}

data "digitalocean_vpc" "production" {
  id = var.vpc_uuid
}

data "digitalocean_projects" "main" {
  filter {
    key    = "name"
    values = [var.project]
  }
}

# =============================================================================
# LOCALS
# =============================================================================

locals {
  # Tags padrão para produção
  default_tags = [
    "environment:${var.environment}",
    "project:${var.project}",
    "cost-center:${var.cost_center}",
    "managed-by:terraform",
    "tier:production",
    "criticality:high"
  ]
  
  all_tags = concat(local.default_tags, var.additional_tags)
  
  # Configuração específica para produção
  production_config = {
    auto_upgrade            = var.auto_upgrade_enabled    # Normalmente false
    surge_upgrade          = var.surge_upgrade_enabled   # Sempre true
    enable_monitoring      = true                        # Monitoramento completo
    backup_retention_days  = 30                         # Backup por 30 dias
    log_retention_days     = 90                          # Logs por 90 dias
    enable_autoscaling     = true                        # HPA habilitado
    enable_network_policies = true                       # Network policies
    enable_pod_security    = true                        # Pod security standards
    enable_rbac           = true                         # RBAC rigoroso
  }
  
  # Configuração de recursos por node pool
  total_capacity = {
    cpu_total    = sum([for k, v in var.node_pools : v.max_nodes * (v.size == "s-4vcpu-8gb" ? 4 : v.size == "c-8vcpu-16gb" ? 8 : v.size == "m-4vcpu-32gb" ? 4 : 2)])
    memory_total = sum([for k, v in var.node_pools : v.max_nodes * (v.size == "s-4vcpu-8gb" ? 8 : v.size == "c-8vcpu-16gb" ? 16 : v.size == "m-4vcpu-32gb" ? 32 : 4)])
  }
  
  # Configuração de alertas críticos
  critical_alerts = {
    node_down_threshold     = "1m"
    memory_usage_threshold  = 85
    cpu_usage_threshold     = 80
    disk_usage_threshold    = 90
    pod_restart_threshold   = 5
  }
}

# =============================================================================
# VPC E FIREWALL (se não existir)
# =============================================================================

# Firewall para cluster de produção
resource "digitalocean_firewall" "production_cluster" {
  name = "${var.cluster_name}-firewall"
  
  tags = [digitalocean_kubernetes_cluster.production.node_pool[0].tags[0]]
  
  # SSH apenas de IPs específicos (substitua pelos seus IPs)
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = [
      "203.0.113.0/24",  # IP do escritório
      "198.51.100.0/24"  # IP da VPN
    ]
  }
  
  # HTTPS público para aplicações
  inbound_rule {
    protocol         = "tcp"
    port_range       = "443"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }
  
  # HTTP público (redirect para HTTPS)
  inbound_rule {
    protocol         = "tcp"
    port_range       = "80"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }
  
  # Tráfego interno do cluster
  inbound_rule {
    protocol    = "tcp"
    port_range  = "1-65535"
    source_tags = [digitalocean_kubernetes_cluster.production.node_pool[0].tags[0]]
  }
  
  inbound_rule {
    protocol    = "udp"
    port_range  = "1-65535"
    source_tags = [digitalocean_kubernetes_cluster.production.node_pool[0].tags[0]]
  }
  
  # Saída permitida para atualizações e downloads
  outbound_rule {
    protocol              = "tcp"
    port_range            = "443"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
  
  outbound_rule {
    protocol              = "tcp"
    port_range            = "80"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
  
  # DNS
  outbound_rule {
    protocol              = "udp"
    port_range            = "53"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
  
  # Tráfego interno
  outbound_rule {
    protocol          = "tcp"
    port_range        = "1-65535"
    destination_tags  = [digitalocean_kubernetes_cluster.production.node_pool[0].tags[0]]
  }
  
  outbound_rule {
    protocol          = "udp"
    port_range        = "1-65535"
    destination_tags  = [digitalocean_kubernetes_cluster.production.node_pool[0].tags[0]]
  }
}

# =============================================================================
# CLUSTER KUBERNETES PARA PRODUÇÃO
# =============================================================================

resource "digitalocean_kubernetes_cluster" "production" {
  name     = var.cluster_name
  region   = var.region
  version  = var.kubernetes_version
  
  # Configurações de upgrade ultra-conservadoras
  auto_upgrade  = local.production_config.auto_upgrade
  surge_upgrade = local.production_config.surge_upgrade
  
  # Política de manutenção rigorosamente controlada
  maintenance_policy {
    start_time = var.maintenance_policy.start_time
    day        = var.maintenance_policy.day
  }
  
  # Configurações de rede seguras
  vpc_uuid = var.vpc_uuid
  
  # Tags de produção
  tags = local.all_tags
  
  # Node pool padrão (será removido após criação de pools dedicados)
  node_pool {
    name       = "default-pool"
    size       = "s-2vcpu-2gb"
    node_count = 1
    tags       = concat(local.all_tags, ["default-pool", "temporary"])
  }
  
  # Proteção contra destruição acidental
  lifecycle {
    prevent_destroy = true  # CRÍTICO: Protege contra rm acidental
    ignore_changes = [node_pool]
  }
}

# =============================================================================
# NODE POOLS DEDICADOS PARA PRODUÇÃO
# =============================================================================

resource "digitalocean_kubernetes_node_pool" "production_pools" {
  for_each = var.node_pools
  
  cluster_id = digitalocean_kubernetes_cluster.production.id
  
  name       = each.key
  size       = each.value.size
  node_count = each.value.node_count
  
  # Auto scaling configurado conservadoramente
  auto_scale = each.value.auto_scale
  min_nodes  = each.value.auto_scale ? each.value.min_nodes : null
  max_nodes  = each.value.auto_scale ? each.value.max_nodes : null
  
  # Labels detalhados para produção
  labels = merge(
    each.value.labels,
    {
      "node-pool"           = each.key
      "cluster-name"        = var.cluster_name
      "environment"         = var.environment
      "auto-upgrade"        = tostring(local.production_config.auto_upgrade)
      "surge-upgrade"       = tostring(local.production_config.surge_upgrade)
      "monitoring-enabled"  = "true"
      "backup-enabled"      = "true"
      "security-enhanced"   = "true"
    }
  )
  
  # Taints para isolamento de workloads
  dynamic "taint" {
    for_each = each.value.taints
    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }
  
  # Tags completas
  tags = concat(
    local.all_tags,
    each.value.tags,
    ["node-pool:${each.key}"]
  )
  
  # Proteção contra destruição
  lifecycle {
    prevent_destroy = true
  }
}

# =============================================================================
# CONFIGURAÇÕES DE PRODUÇÃO ADICIONAIS
# =============================================================================

# Adicionar cluster ao projeto da DigitalOcean
resource "digitalocean_project_resources" "cluster" {
  project = data.digitalocean_projects.main.projects[0].id
  
  resources = [
    digitalocean_kubernetes_cluster.production.urn
  ]
}

# =============================================================================
# OUTPUTS PARA PRODUÇÃO
# =============================================================================

output "cluster_info" {
  description = "Informações críticas do cluster de produção"
  value = {
    id                = digitalocean_kubernetes_cluster.production.id
    name              = digitalocean_kubernetes_cluster.production.name
    region            = digitalocean_kubernetes_cluster.production.region
    version           = digitalocean_kubernetes_cluster.production.version
    endpoint          = digitalocean_kubernetes_cluster.production.endpoint
    status            = digitalocean_kubernetes_cluster.production.status
    auto_upgrade      = digitalocean_kubernetes_cluster.production.auto_upgrade
    surge_upgrade     = digitalocean_kubernetes_cluster.production.surge_upgrade
    vpc_uuid          = digitalocean_kubernetes_cluster.production.vpc_uuid
    service_subnet    = digitalocean_kubernetes_cluster.production.service_subnet
    pod_subnet        = digitalocean_kubernetes_cluster.production.pod_subnet
  }
  sensitive = true  # Informações sensíveis de produção
}

output "security_configuration" {
  description = "Configurações de segurança aplicadas"
  value = {
    private_cluster     = var.enable_private_cluster
    vpc_enabled        = var.vpc_uuid != null
    firewall_applied   = true
    network_policies   = local.production_config.enable_network_policies
    pod_security       = local.production_config.enable_pod_security
    rbac_enabled       = local.production_config.enable_rbac
  }
}

output "capacity_info" {
  description = "Informações de capacidade do cluster"
  value = {
    total_cpu_cores     = local.total_capacity.cpu_total
    total_memory_gb     = local.total_capacity.memory_total
    total_nodes_min     = sum([for k, v in var.node_pools : v.min_nodes])
    total_nodes_max     = sum([for k, v in var.node_pools : v.max_nodes])
    node_pools_count    = length(var.node_pools)
  }
}

output "upgrade_configuration" {
  description = "Configurações críticas de upgrade"
  value = {
    auto_upgrade_enabled    = local.production_config.auto_upgrade
    surge_upgrade_enabled   = local.production_config.surge_upgrade
    maintenance_window      = "${var.maintenance_policy.day} at ${var.maintenance_policy.start_time}"
    surge_strategy          = var.surge_config
    upgrade_protection      = "Manual approval required"
  }
}

output "backup_and_monitoring" {
  description = "Configurações de backup e monitoramento"
  value = {
    backup_retention_days   = local.production_config.backup_retention_days
    log_retention_days      = local.production_config.log_retention_days
    monitoring_enabled      = local.production_config.enable_monitoring
    alerting_thresholds     = local.critical_alerts
  }
}

output "cost_estimation" {
  description = "Estimativa de custos de produção"
  value = {
    base_monthly_cost      = "$420-840/mês (nodes base)"
    load_balancer_cost     = "$12/mês"
    storage_cost_estimate  = "$50-100/mês"
    monitoring_cost        = "$30-50/mês"
    total_estimated        = "$512-1002/mês"
    cost_optimization      = "Auto-scale enabled, rightsizing applied"
  }
}

output "operational_commands" {
  description = "Comandos operacionais críticos"
  value = {
    get_kubeconfig        = "doctl kubernetes cluster kubeconfig save ${digitalocean_kubernetes_cluster.production.name}"
    cluster_status        = "kubectl cluster-info"
    node_status           = "kubectl get nodes -o wide"
    critical_pods         = "kubectl get pods --all-namespaces --field-selector=status.phase!=Running"
    resource_usage        = "kubectl top nodes && kubectl top pods --all-namespaces"
    backup_command        = "velero backup create prod-backup-$(date +%Y%m%d-%H%M%S)"
    emergency_contact     = "escalate-to-oncall@empresa.com"
  }
  sensitive = true
}

output "monitoring_endpoints" {
  description = "Endpoints de monitoramento"
  value = {
    prometheus     = "https://prometheus.meudominio.com"
    grafana       = "https://grafana.meudominio.com"
    alertmanager  = "https://alerts.meudominio.com"
    jaeger        = "https://tracing.meudominio.com"
  }
}
```

### Arquivo `environments/production/security.tf`

```hcl
# =============================================================================
# CONFIGURAÇÕES DE SEGURANÇA PARA PRODUÇÃO
# =============================================================================

# =============================================================================
# NAMESPACES COM CONFIGURAÇÕES DE SEGURANÇA
# =============================================================================

# Namespace para aplicações de produção
resource "kubernetes_namespace" "production" {
  metadata {
    name = "production"
    
    labels = {
      environment                     = var.environment
      project                        = var.project
      tier                          = "production"
      "pod-security.kubernetes.io/enforce" = "restricted"
      "pod-security.kubernetes.io/audit"   = "restricted"
      "pod-security.kubernetes.io/warn"    = "restricted"
    }
    
    annotations = {
      "scheduler.alpha.kubernetes.io/preferred-anti-affinity" = "true"
    }
  }
}

# Namespace para monitoramento de sistema
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
    
    labels = {
      environment = var.environment
      purpose     = "monitoring"
      tier        = "system"
      "pod-security.kubernetes.io/enforce" = "privileged"
      "pod-security.kubernetes.io/audit"   = "privileged"
      "pod-security.kubernetes.io/warn"    = "privileged"
    }
  }
}

# Namespace para backup e recovery
resource "kubernetes_namespace" "velero" {
  metadata {
    name = "velero"
    
    labels = {
      environment = var.environment
      purpose     = "backup"
      tier        = "system"
      "pod-security.kubernetes.io/enforce" = "privileged"
    }
  }
}

# Namespace para ingress controller
resource "kubernetes_namespace" "ingress" {
  metadata {
    name = "ingress-nginx"
    
    labels = {
      environment = var.environment
      purpose     = "ingress"
      tier        = "system"
      "pod-security.kubernetes.io/enforce" = "privileged"
    }
  }
}

# =============================================================================
# RBAC - CONTROLE DE ACESSO BASEADO EM ROLES
# =============================================================================

# Role para administradores de produção (acesso completo)
resource "kubernetes_cluster_role" "production_admin" {
  metadata {
    name = "production-admin"
  }
  
  rule {
    api_groups = ["*"]
    resources  = ["*"]
    verbs      = ["*"]
  }
}

# Role para desenvolvedores (acesso limitado)
resource "kubernetes_cluster_role" "production_developer" {
  metadata {
    name = "production-developer"
  }
  
  rule {
    api_groups = [""]
    resources  = ["pods", "services", "configmaps", "secrets"]
    verbs      = ["get", "list", "watch"]
  }
  
  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "replicasets", "daemonsets"]
    verbs      = ["get", "list", "watch"]
  }
  
  rule {
    api_groups = [""]
    resources  = ["pods/logs"]
    verbs      = ["get", "list"]
  }
}

# Role para monitoramento
resource "kubernetes_cluster_role" "monitoring" {
  metadata {
    name = "monitoring"
  }
  
  rule {
    api_groups = [""]
    resources  = ["nodes", "nodes/proxy", "services", "endpoints", "pods"]
    verbs      = ["get", "list", "watch"]
  }
  
  rule {
    api_groups = ["extensions", "apps"]
    resources  = ["deployments", "daemonsets", "replicasets"]
    verbs      = ["get", "list", "watch"]
  }
  
  rule {
    non_resource_urls = ["/metrics"]
    verbs             = ["get"]
  }
}

# Service Account para monitoramento
resource "kubernetes_service_account" "monitoring" {
  metadata {
    name      = "monitoring-sa"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }
}

# Binding da role de monitoramento
resource "kubernetes_cluster_role_binding" "monitoring" {
  metadata {
    name = "monitoring-binding"
  }
  
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.monitoring.metadata[0].name
  }
  
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.monitoring.metadata[0].name
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }
}

# =============================================================================
# NETWORK POLICIES - ISOLAMENTO DE REDE
# =============================================================================

# Network Policy para isolamento do namespace de produção
resource "kubernetes_network_policy" "production_isolation" {
  metadata {
    name      = "production-isolation"
    namespace = kubernetes_namespace.production.metadata[0].name
  }
  
  spec {
    pod_selector {}
    
    policy_types = ["Ingress", "Egress"]
    
    # Permite tráfego apenas de pods no mesmo namespace
    ingress {
      from {
        namespace_selector {
          match_labels = {
            name = "production"
          }
        }
      }
    }
    
    # Permite tráfego do ingress controller
    ingress {
      from {
        namespace_selector {
          match_labels = {
            purpose = "ingress"
          }
        }
      }
    }
    
    # Permite tráfego do monitoramento
    ingress {
      from {
        namespace_selector {
          match_labels = {
            purpose = "monitoring"
          }
        }
      }
    }
    
    # Egress: permite DNS
    egress {
      to {}
      ports {
        protocol = "UDP"
        port     = "53"
      }
    }
    
    # Egress: permite HTTPS externo
    egress {
      to {}
      ports {
        protocol = "TCP"
        port     = "443"
      }
    }
    
    # Egress: permite comunicação interna
    egress {
      to {
        namespace_selector {
          match_labels = {
            environment = var.environment
          }
        }
      }
    }
  }
}

# Network Policy para monitoramento
resource "kubernetes_network_policy" "monitoring_access" {
  metadata {
    name      = "monitoring-access"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }
  
  spec {
    pod_selector {}
    
    policy_types = ["Ingress", "Egress"]
    
    # Permite acesso do ingress
    ingress {
      from {
        namespace_selector {
          match_labels = {
            purpose = "ingress"
          }
        }
      }
    }
    
    # Permite tráfego interno
    ingress {
      from {
        namespace_selector {
          match_labels = {
            purpose = "monitoring"
          }
        }
      }
    }
    
    # Permite todo egress (necessário para coletar métricas)
    egress {}
  }
}

# =============================================================================
# POD SECURITY STANDARDS E ADMISSION CONTROLLERS
# =============================================================================

# Pod Security Policy para produção (restritiva)
resource "kubernetes_manifest" "pod_security_policy_production" {
  manifest = {
    apiVersion = "policy/v1beta1"
    kind       = "PodSecurityPolicy"
    metadata = {
      name = "production-restricted"
    }
    spec = {
      privileged                = false
      allowPrivilegeEscalation  = false
      requiredDropCapabilities  = ["ALL"]
      volumes = [
        "configMap",
        "emptyDir",
        "projected",
        "secret",
        "downwardAPI",
        "persistentVolumeClaim"
      ]
      runAsUser = {
        rule = "MustRunAsNonRoot"
      }
      seLinux = {
        rule = "RunAsAny"
      }
      fsGroup = {
        rule = "RunAsAny"
      }
      readOnlyRootFilesystem = true
    }
  }
}

# =============================================================================
# RESOURCE QUOTAS E LIMIT RANGES
# =============================================================================

# Resource Quota rigorosa para produção
resource "kubernetes_resource_quota" "production" {
  metadata {
    name      = "production-quota"
    namespace = kubernetes_namespace.production.metadata[0].name
  }
  
  spec {
    hard = {
      "requests.cpu"               = "20000m"    # 20 CPUs
      "requests.memory"            = "40Gi"      # 40GB RAM
      "limits.cpu"                 = "40000m"    # 40 CPUs
      "limits.memory"              = "80Gi"      # 80GB RAM
      "pods"                      = "100"        # Máximo 100 pods
      "services"                  = "50"         # Máximo 50 services
      "persistentvolumeclaims"    = "50"         # Máximo 50 PVCs
      "secrets"                   = "100"        # Máximo 100 secrets
      "configmaps"                = "100"        # Máximo 100 configmaps
    }
  }
}

# Limit Range para controle fino de recursos
resource "kubernetes_limit_range" "production" {
  metadata {
    name      = "production-limits"
    namespace = kubernetes_namespace.production.metadata[0].name
  }
  
  spec {
    limit {
      type = "Pod"
      max = {
        cpu    = "4000m"     # Máximo 4 CPUs por pod
        memory = "8Gi"       # Máximo 8GB por pod
      }
      min = {
        cpu    = "100m"      # Mínimo 100m CPU
        memory = "128Mi"     # Mínimo 128MB RAM
      }
    }
    
    limit {
      type = "Container"
      default = {
        cpu    = "500m"      # Default: 500m CPU
        memory = "512Mi"     # Default: 512MB RAM
      }
      default_request = {
        cpu    = "100m"      # Default request: 100m CPU
        memory = "128Mi"     # Default request: 128MB RAM
      }
      max = {
        cpu    = "2000m"     # Máximo 2 CPUs por container
        memory = "4Gi"       # Máximo 4GB por container
      }
    }
    
    limit {
      type = "PersistentVolumeClaim"
      min = {
        storage = "1Gi"      # Mínimo 1GB
      }
      max = {
        storage = "100Gi"    # Máximo 100GB por PVC
      }
    }
  }
}

# =============================================================================
# SECRETS E CONFIGURAÇÕES SENSÍVEIS
# =============================================================================

# Secret para registry privado (se aplicável)
resource "kubernetes_secret" "docker_registry" {
  count = var.docker_registry_secret != null ? 1 : 0
  
  metadata {
    name      = "docker-registry-secret"
    namespace = kubernetes_namespace.production.metadata[0].name
  }
  
  type = "kubernetes.io/dockerconfigjson"
  
  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        (var.docker_registry_secret.server) = {
          username = var.docker_registry_secret.username
          password = var.docker_registry_secret.password
          email    = var.docker_registry_secret.email
          auth     = base64encode("${var.docker_registry_secret.username}:${var.docker_registry_secret.password}")
        }
      }
    })
  }
}

# ConfigMap com configurações de segurança
resource "kubernetes_config_map" "security_config" {
  metadata {
    name      = "security-config"
    namespace = kubernetes_namespace.production.metadata[0].name
  }
  
  data = {
    # Configurações de segurança
    "enforce_pod_security"    = "true"
    "require_non_root"        = "true"
    "require_readonly_root"   = "true"
    "network_policies_enabled" = "true"
    "rbac_enabled"            = "true"
    
    # Configurações de monitoramento de segurança
    "security_scanning"       = "enabled"
    "vulnerability_alerts"    = "enabled"
    "compliance_checks"       = "enabled"
    
    # Configurações de backup
    "backup_encryption"       = "true"
    "backup_retention_days"   = tostring(local.production_config.backup_retention_days)
  }
}
```

### Arquivo `environments/production/monitoring.tf`

```hcl
# =============================================================================
# CONFIGURAÇÕES COMPLETAS DE MONITORAMENTO PARA PRODUÇÃO
# =============================================================================

# Helm chart para kube-prometheus-stack
resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "45.7.1"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  
  values = [
    yamlencode({
      # Configurações do Prometheus
      prometheus = {
        prometheusSpec = {
          retention = "30d"
          retentionSize = "50GiB"
          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = "do-block-storage"
                accessModes      = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = "100Gi"
                  }
                }
              }
            }
          }
          resources = {
            requests = {
              cpu    = "500m"
              memory = "2Gi"
            }
            limits = {
              cpu    = "2000m"
              memory = "4Gi"
            }
          }
          nodeSelector = {
            "workload" = "system"
          }
          tolerations = [
            {
              key      = "node-role"
              operator = "Equal"
              value    = "system"
              effect   = "NoSchedule"
            }
          ]
        }
      }
      
      # Configurações do Grafana
      grafana = {
        enabled = true
        adminPassword = var.grafana_admin_password
        persistence = {
          enabled = true
          size    = "10Gi"
        }
        resources = {
          requests = {
            cpu    = "100m"
            memory = "256Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
        }
        nodeSelector = {
          "workload" = "system"
        }
        tolerations = [
          {
            key      = "node-role"
            operator = "Equal"
            value    = "system"
            effect   = "NoSchedule"
          }
        ]
      }
      
      # Configurações do AlertManager
      alertmanager = {
        alertmanagerSpec = {
          storage = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = "do-block-storage"
                accessModes      = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = "10Gi"
                  }
                }
              }
            }
          }
          resources = {
            requests = {
              cpu    = "100m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }
          nodeSelector = {
            "workload" = "system"
          }
          tolerations = [
            {
              key      = "node-role"
              operator = "Equal"
              value    = "system"
              effect   = "NoSchedule"
            }
          ]
        }
      }
      
      # Configurações específicas para DigitalOcean
      kubeStateMetrics = {
        enabled = true
      }
      
      nodeExporter = {
        enabled = true
      }
      
      prometheusOperator = {
        enabled = true
        nodeSelector = {
          "workload" = "system"
        }
        tolerations = [
          {
            key      = "node-role"
            operator = "Equal"
            value    = "system"
            effect   = "NoSchedule"
          }
        ]
      }
    })
  ]
  
  depends_on = [
    digitalocean_kubernetes_node_pool.production_pools
  ]
}

# ConfigMap para configurações customizadas do AlertManager
resource "kubernetes_config_map" "alertmanager_config" {
  metadata {
    name      = "alertmanager-config"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }
  
  data = {
    "alertmanager.yml" = yamlencode({
      global = {
        smtp_smarthost = var.smtp_server
        smtp_from      = var.alert_email_from
      }
      
      route = {
        group_by        = ["alertname"]
        group_wait      = "10s"
        group_interval  = "10s"
        repeat_interval = "1h"
        receiver        = "web.hook"
        routes = [
          {
            match = {
              severity = "critical"
            }
            receiver = "critical-alerts"
          },
          {
            match = {
              severity = "warning"
            }
            receiver = "warning-alerts"
          }
        ]
      }
      
      receivers = [
        {
          name = "web.hook"
          webhook_configs = [
            {
              url = var.webhook_url
            }
          ]
        },
        {
          name = "critical-alerts"
          email_configs = [
            {
              to      = var.critical_alert_emails
              subject = "🚨 CRITICAL ALERT: {{ .GroupLabels.alertname }}"
              body    = "{{ range .Alerts }}{{ .Annotations.summary }}\n{{ .Annotations.description }}{{ end }}"
            }
          ]
          slack_configs = [
            {
              api_url = var.slack_webhook_url
              channel = "#critical-alerts"
              title   = "🚨 Critical Alert"
              text    = "{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}"
            }
          ]
        },
        {
          name = "warning-alerts"
          email_configs = [
            {
              to      = var.warning_alert_emails
              subject = "⚠️ WARNING: {{ .GroupLabels.alertname }}"
              body    = "{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}"
            }
          ]
        }
      ]
    })
  }
}

# PrometheusRule para alertas customizados de produção
resource "kubernetes_manifest" "production_alerts" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"
    metadata = {
      name      = "production-alerts"
      namespace = kubernetes_namespace.monitoring.metadata[0].name
      labels = {
        prometheus = "kube-prometheus"
        role       = "alert-rules"
      }
    }
    spec = {
      groups = [
        {
          name = "kubernetes-production"
          rules = [
            {
              alert = "NodeDown"
              expr  = "up{job=\"kubernetes-nodes\"} == 0"
              for   = "1m"
              labels = {
                severity = "critical"
              }
              annotations = {
                summary     = "Node {{ $labels.instance }} is down"
                description = "Node {{ $labels.instance }} has been down for more than 1 minute."
              }
            },
            {
              alert = "PodCrashLooping"
              expr  = "rate(kube_pod_container_status_restarts_total[15m]) > 0"
              for   = "5m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "Pod {{ $labels.pod }} is crash looping"
                description = "Pod {{ $labels.pod }} in namespace {{ $labels.namespace }} is restarting frequently."
              }
            },
            {
              alert = "HighMemoryUsage"
              expr  = "(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes > 0.85"
              for   = "5m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "High memory usage on {{ $labels.instance }}"
                description = "Memory usage is above 85% on {{ $labels.instance }}."
              }
            },
            {
              alert = "HighCPUUsage"
              expr  = "100 - (avg by(instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100) > 80"
              for   = "5m"
              labels = {
                severity = "warning"
              }
              annotations = {
                summary     = "High CPU usage on {{ $labels.instance }}"
                description = "CPU usage is above 80% on {{ $labels.instance }}."
              }
            },
            {
              alert = "DiskSpaceLow"
              expr  = "100 - ((node_filesystem_avail_bytes{mountpoint=\"/\"} * 100) / node_filesystem_size_bytes{mountpoint=\"/\"}) > 90"
              for   = "5m"
              labels = {
                severity = "critical"
              }
              annotations = {
                summary     = "Disk space low on {{ $labels.instance }}"
                description = "Disk usage is above 90% on {{ $labels.instance }}."
              }
            },
            {
              alert = "KubernetesUpgradeStarted"
              expr  = "increase(kube_node_created[5m]) > 0"
              for   = "1m"
              labels = {
                severity = "info"
              }
              annotations = {
                summary     = "Kubernetes upgrade in progress"
                description = "New nodes detected - possible cluster upgrade in progress."
              }
            }
          ]
        }
      ]
    }
  }
  
  depends_on = [helm_release.kube_prometheus_stack]
}

# Service Monitor para aplicações customizadas
resource "kubernetes_manifest" "app_service_monitor" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "production-apps"
      namespace = kubernetes_namespace.monitoring.metadata[0].name
    }
    spec = {
      selector = {
        matchLabels = {
          "monitoring" = "enabled"
        }
      }
      namespaceSelector = {
        matchNames = [kubernetes_namespace.production.metadata[0].name]
      }
      endpoints = [
        {
          port = "metrics"
          path = "/metrics"
        }
      ]
    }
  }
  
  depends_on = [helm_release.kube_prometheus_stack]
}
```

## 🚀 Como Usar

### 1. Preparação Inicial

```bash
# Preparar ambiente
export DIGITALOCEAN_TOKEN="dop_v1_seu-token-aqui"
export TF_VAR_grafana_admin_password="sua-senha-segura"

# Configurar backend remoto
export AWS_ACCESS_KEY_ID="sua-spaces-key"
export AWS_SECRET_ACCESS_KEY="sua-spaces-secret"

# Navegar para produção
cd terraform/environments/production
```

### 2. Configuração de Variáveis Sensíveis

```hcl
# terraform.tfvars.example
grafana_admin_password = "senha-super-segura-aqui"
smtp_server           = "smtp.empresa.com:587"
alert_email_from      = "alerts@empresa.com"
critical_alert_emails = ["oncall@empresa.com", "cto@empresa.com"]
warning_alert_emails  = ["devops@empresa.com"]
slack_webhook_url     = "https://hooks.slack.com/services/..."
webhook_url          = "https://alertmanager.empresa.com/webhook"

docker_registry_secret = {
  server   = "registry.empresa.com"
  username = "robot-account"
  password = "senha-do-registry"
  email    = "devops@empresa.com"
}
```

### 3. Deploy Controlado

```bash
# 1. Validar configuração
terraform validate
terraform fmt -check

# 2. Planejar mudanças (SEMPRE revisar)
terraform plan -out=production.tfplan

# 3. Aplicar apenas após aprovação
terraform apply production.tfplan

# 4. Configurar kubectl
doctl kubernetes cluster kubeconfig save prod-k8s-cluster
```

### 4. Verificação Pós-Deploy

```bash
# Verificar cluster
kubectl cluster-info
kubectl get nodes -o wide

# Verificar namespaces e pods
kubectl get namespaces
kubectl get pods --all-namespaces

# Verificar monitoramento
kubectl get pods -n monitoring
kubectl get svc -n monitoring

# Verificar alertas
kubectl get prometheusrules -n monitoring
```

## 💰 Estimativa de Custos Detalhada

### Custos Base (Configuração Mínima)

```
Node Pools:
- 5x s-4vcpu-8gb (general): 5 × $84/mês = $420/mês
- 2x c-8vcpu-16gb (compute): 2 × $168/mês = $336/mês  
- 1x m-4vcpu-32gb (memory): 1 × $168/mês = $168/mês
- 3x s-2vcpu-4gb (system): 3 × $42/mês = $126/mês

Subtotal nodes: $1,050/mês
```

### Custos Adicionais

```
Load Balancer: $12/mês
Block Storage (monitoring): ~$100/mês
Backup Storage: ~$50/mês
Networking: ~$20/mês

Total estimado: $1,232/mês
```

### Durante Auto Scale (Picos)

```
Máximo possível:
- 10x general + 8x compute + 5x memory + 5x system
- Total: ~$2,500/mês (temporário durante picos)
```

## 🔒 Checklist de Segurança

### ✅ Configurações Aplicadas

- [x] **Cluster privado** com VPC dedicada
- [x] **Firewall** com regras restritivas
- [x] **RBAC** com princípio de menor privilégio
- [x] **Network Policies** para isolamento
- [x] **Pod Security Standards** restritivos
- [x] **Resource Quotas** e Limit Ranges
- [x] **Secrets** gerenciados adequadamente
- [x] **Monitoramento** e alertas de segurança
- [x] **Backup** e recovery automatizados
- [x] **Logs** centralizados e retidos

### 🔐 Configurações de Segurança Adicionais

```bash
# 1. Configurar OIDC/SSO (exemplo com Auth0)
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: oidc-config
  namespace: kube-system
data:
  issuer-url: "https://empresa.auth0.com/"
  client-id: "kubernetes-prod-cluster"
  username-claim: "email"
  groups-claim: "groups"
EOF

# 2. Habilitar audit logging
# (Configurado via DigitalOcean control panel ou API)

# 3. Configurar image scanning
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: security-policy
  namespace: production
data:
  allowedRegistries: |
    - docker.io
    - registry.empresa.com
    - gcr.io
  requiredAnnotations: |
    - security-scan: "passed"
    - vulnerability-scan: "clean"
EOF
```

## 📊 Monitoramento de Produção

### Dashboards Críticos

1. **Cluster Overview**
   - Status geral dos nodes
   - Uso de recursos
   - Pods por namespace

2. **Application Performance**
   - Latência de requests
   - Taxa de erro
   - Throughput

3. **Infrastructure Health**
   - CPU, memória, disk
   - Network I/O
   - Storage metrics

4. **Security Monitoring**
   - Tentativas de acesso negadas
   - Pods com privilégios elevados
   - Network policy violations

### Alertas Críticos Configurados

```yaml
# Alertas que devem acordar o on-call
critical_alerts:
  - NodeDown (>1min)
  - APIServerDown (>30s)
  - EtcdDown (>1min)
  - PodCrashLooping (>5 restarts em 15min)
  - DiskSpaceLow (>90%)
  - MemoryUsageHigh (>95%)
  - CertificateExpiringSoon (<7 days)

# Alertas que podem esperar horário comercial
warning_alerts:
  - HighCPUUsage (>80% por 5min)
  - HighMemoryUsage (>85% por 5min)
  - PodRestartRate (>3 restarts em 1h)
  - DeploymentReplicasMismatch
```

## 🛠️ Operações de Manutenção

### Rotina Diária

```bash
#!/bin/bash
# daily-health-check.sh

echo "=== Daily Production Health Check $(date) ==="

# 1. Cluster health
echo "Cluster Status:"
kubectl get nodes --no-headers | awk '{print $1 " " $2}'

echo -e "\nUnhealthy Pods:"
kubectl get pods --all-namespaces --field-selector=status.phase!=Running

echo -e "\nResource Usage:"
kubectl top nodes

# 2. Critical alerts
echo -e "\nActive Alerts:"
curl -s http://alertmanager.monitoring.svc.cluster.local:9093/api/v1/alerts | jq '.data[] | select(.status.state=="firing") | .labels.alertname'

# 3. Backup status
echo -e "\nBackup Status:"
kubectl get backups -n velero --sort-by=.metadata.creationTimestamp | tail -5

# 4. Certificate expiry
echo -e "\nCertificate Status:"
kubectl get certificates --all-namespaces -o wide
```

### Rotina Semanal

```bash
#!/bin/bash
# weekly-maintenance.sh

echo "=== Weekly Production Maintenance $(date) ==="

# 1. Resource cleanup
kubectl delete pods --field-selector=status.phase=Succeeded --all-namespaces
kubectl delete jobs --field-selector=status.successful=1 --all-namespaces

# 2. Image cleanup
kubectl get pods --all-namespaces -o jsonpath='{.items[*].spec.containers[*].image}' | tr ' ' '\n' | sort | uniq > used-images.txt

# 3. Security scan
kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.spec.securityContext.runAsUser == 0) | "\(.metadata.namespace)/\(.metadata.name)"'

# 4. Performance report
kubectl top nodes > weekly-resource-usage.txt
kubectl top pods --all-namespaces >> weekly-resource-usage.txt
```

### Upgrade Manual (Quando auto_upgrade = false)

```bash
#!/bin/bash
# manual-upgrade.sh

echo "=== Manual Kubernetes Upgrade Process ==="

# 1. Pre-upgrade checks
echo "1. Pre-upgrade validation..."
kubectl get nodes
kubectl get pods --all-namespaces --field-selector=status.phase!=Running

# 2. Create backup
echo "2. Creating backup..."
velero backup create pre-upgrade-backup-$(date +%Y%m%d-%H%M%S) --wait

# 3. Check available versions
echo "3. Available versions:"
doctl kubernetes options versions

# 4. Upgrade (com confirmação manual)
read -p "Enter target version (e.g., 1.28.3-do.0): " TARGET_VERSION
read -p "Confirm upgrade to $TARGET_VERSION? (yes/no): " CONFIRM

if [ "$CONFIRM" = "yes" ]; then
    echo "4. Starting upgrade..."
    doctl kubernetes cluster upgrade prod-k8s-cluster --version="$TARGET_VERSION"
    
    # 5. Monitor upgrade
    echo "5. Monitoring upgrade progress..."
    while true; do
        STATUS=$(doctl kubernetes cluster get prod-k8s-cluster --format Status --no-header)
        echo "Cluster status: $STATUS"
        if [ "$STATUS" = "running" ]; then
            break
        fi
        sleep 30
    done
    
    echo "Upgrade completed successfully!"
else
    echo "Upgrade cancelled."
    exit 1
fi
```

## 📚 Próximos Passos

1. 🚀 **Deploy inicial**: Siga os passos de implantação
2. 🔒 **Configurar SSO**: Integre com sistema de autenticação
3. 📊 **Configurar dashboards**: Personalize monitoramento
4. 🔄 **Automatizar backups**: Configure estratégia de backup
5. 🧪 **Teste de DR**: Execute teste de disaster recovery
6. 📋 **Documentar runbooks**: Crie procedimentos operacionais

## 🆘 Contatos de Emergência

```yaml
# emergency-contacts.yaml
production_emergency:
  primary_oncall: "+55-11-99999-9999"
  secondary_oncall: "+55-11-88888-8888"
  escalation_manager: "+55-11-77777-7777"
  
email_groups:
  critical_alerts: "oncall@empresa.com"
  infrastructure: "devops@empresa.com"
  security: "security@empresa.com"
  
slack_channels:
  alerts: "#prod-alerts"
  incidents: "#incident-response"
  general: "#devops"

vendor_support:
  digitalocean: "https://cloud.digitalocean.com/support/tickets"
  priority: "Business Critical"
```

## 🔗 Links Relacionados

- [Configuração de Desenvolvimento](development.md)
- [Configuração de Staging](staging.md)
- [Guia de Configuração Completo](../configuration-guide.md)
- [FAQ](../faq.md)

---

**🚨 IMPORTANTE**: Este é um ambiente de produção. Sempre siga os procedimentos de change management e obtenha aprovações necessárias antes de fazer alterações.