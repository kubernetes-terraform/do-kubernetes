# Configuração para Ambiente de Staging

Este exemplo mostra como configurar um cluster Kubernetes na DigitalOcean otimizado para staging/homologação, servindo como ambiente intermediário entre desenvolvimento e produção.

## 🎯 Características do Ambiente de Staging

- **Prioridade**: Simular produção com economia controlada
- **Downtime**: Mínimo aceitável, mas zero downtime preferível
- **Recursos**: Similares à produção, mas em escala menor
- **Automação**: Equilibrio entre controle e automação
- **Testes**: Ambiente para validar upgrades antes da produção

## ⚙️ Configuração Completa

### Arquivo `environments/staging/terraform.tfvars`

```hcl
# =============================================================================
# CONFIGURAÇÕES BÁSICAS
# =============================================================================

cluster_name        = "staging-k8s-cluster"
region             = "fra1"                    # Mesma região da produção
kubernetes_version = "1.28.2-do.0"            # Versão igual ou superior à prod
environment        = "staging"
project           = "meu-projeto"
cost_center       = "engineering"

# =============================================================================
# CONFIGURAÇÕES DE UPGRADE - STAGING
# =============================================================================

# Auto upgrade HABILITADO para testar antes da produção
auto_upgrade_enabled  = true

# Surge upgrade HABILITADO para simular produção
surge_upgrade_enabled = true

# Manutenção antes da janela de produção (para testar primeiro)
maintenance_policy = {
  start_time = "01:00"    # 1:00 AM (antes da produção)
  day        = "saturday" # Sábado (antes da manutenção de produção no domingo)
}

# Configuração de surge mais conservadora que dev, mas menos que prod
surge_config = {
  max_surge       = "1"   # 1 node por vez (balance custo/velocidade)
  max_unavailable = "0"   # Zero indisponibilidade
}

# =============================================================================
# NODE POOLS - CONFIGURAÇÃO EQUILIBRADA
# =============================================================================

node_pools = {
  # Pool principal - simula produção em escala menor
  workers = {
    size       = "s-2vcpu-4gb"    # Maior que dev, menor que prod
    node_count = 3                # Mínimo para HA real
    min_nodes  = 3                # Sempre 3 nodes mínimo
    max_nodes  = 6                # Pode escalar para 2x (surge + carga)
    auto_scale = true             # Auto scale habilitado
    tags       = ["staging", "workers", "primary"]
    labels = {
      role        = "worker"
      tier        = "staging"
      workload    = "general"
      zone        = "primary"
    }
    taints = []                   # Sem taints no pool principal
  }
  
  # Pool especializado - para testar workloads específicos
  specialized = {
    size       = "s-4vcpu-8gb"    # Nodes maiores para workloads específicos
    node_count = 1                # Mínimo 1 para testes
    min_nodes  = 0                # Pode reduzir a zero quando não usado
    max_nodes  = 3                # Pode escalar conforme necessidade
    auto_scale = true
    tags       = ["staging", "specialized", "compute"]
    labels = {
      role        = "worker"
      tier        = "staging"
      workload    = "specialized"
      node_type   = "compute"
    }
    taints = [
      {
        key    = "workload-type"
        value  = "specialized"
        effect = "NoSchedule"
      }
    ]
  }
}

# =============================================================================
# CONFIGURAÇÕES DE REDE - HÍBRIDA
# =============================================================================

# Cluster privado para simular produção, mas permite acesso mais flexível
enable_private_cluster = false        # Público para facilitar testes
vpc_uuid              = null          # VPC padrão (customize se necessário)

# Subnets customizadas (opcional - remova se não necessário)
service_subnet = "10.245.0.0/16"     # Diferente de dev e prod
pod_subnet     = "10.245.64.0/18"

# =============================================================================
# TAGS ESPECÍFICAS DE STAGING
# =============================================================================

additional_tags = [
  "testing:enabled",            # Ambiente de testes
  "pre-production:true",        # Pré-produção
  "monitoring:enhanced",        # Monitoramento melhorado
  "backup:required",            # Backup necessário (mas menor retenção)
  "auto-scale:enabled",         # Auto scaling habilitado
  "load-testing:allowed"        # Permite testes de carga
]
```

### Arquivo `environments/staging/main.tf`

```hcl
# =============================================================================
# CONFIGURAÇÃO TERRAFORM PARA STAGING
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
  
  # Backend remoto para staging (recomendado)
  backend "s3" {
    bucket = "meu-projeto-terraform-state"
    key    = "staging/kubernetes/terraform.tfstate"
    region = "fra1"
    
    # DigitalOcean Spaces como backend S3-compatível
    endpoint                    = "https://fra1.digitaloceanspaces.com"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
  }
}

# =============================================================================
# PROVIDERS
# =============================================================================

provider "digitalocean" {
  # Token via variável de ambiente DIGITALOCEAN_TOKEN
}

provider "kubernetes" {
  host  = digitalocean_kubernetes_cluster.staging.endpoint
  token = digitalocean_kubernetes_cluster.staging.kube_config[0].token
  cluster_ca_certificate = base64decode(
    digitalocean_kubernetes_cluster.staging.kube_config[0].cluster_ca_certificate
  )
}

provider "helm" {
  kubernetes {
    host  = digitalocean_kubernetes_cluster.staging.endpoint
    token = digitalocean_kubernetes_cluster.staging.kube_config[0].token
    cluster_ca_certificate = base64decode(
      digitalocean_kubernetes_cluster.staging.kube_config[0].cluster_ca_certificate
    )
  }
}

# =============================================================================
# DATA SOURCES
# =============================================================================

data "digitalocean_kubernetes_versions" "staging" {
  version_prefix = "1.28."
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
  # Tags padrão para staging
  default_tags = [
    "environment:${var.environment}",
    "project:${var.project}",
    "cost-center:${var.cost_center}",
    "managed-by:terraform",
    "tier:staging"
  ]
  
  all_tags = concat(local.default_tags, var.additional_tags)
  
  # Configuração específica para staging
  staging_config = {
    auto_upgrade            = var.auto_upgrade_enabled
    surge_upgrade          = var.surge_upgrade_enabled
    enable_monitoring      = true    # Monitoramento habilitado
    backup_retention_days  = 7       # Backup por 1 semana
    log_retention_days     = 14      # Logs por 2 semanas
    enable_autoscaling     = true    # HPA habilitado
    enable_load_testing    = true    # Permite testes de carga
  }
  
  # Configuração de recursos por node pool
  node_pool_configs = {
    for name, pool in var.node_pools : name => {
      resource_quota = {
        cpu_requests    = "${pool.node_count * 1.5}000m"  # 1.5 CPU por node
        memory_requests = "${pool.node_count * 3}Gi"       # 3GB por node
        cpu_limits      = "${pool.node_count * 2}000m"     # 2 CPU por node
        memory_limits   = "${pool.node_count * 6}Gi"       # 6GB por node
      }
    }
  }
}

# =============================================================================
# CLUSTER KUBERNETES PARA STAGING
# =============================================================================

resource "digitalocean_kubernetes_cluster" "staging" {
  name     = var.cluster_name
  region   = var.region
  version  = var.kubernetes_version
  
  # Configurações de upgrade
  auto_upgrade  = local.staging_config.auto_upgrade
  surge_upgrade = local.staging_config.surge_upgrade
  
  # Política de manutenção para testar antes da produção
  maintenance_policy {
    start_time = var.maintenance_policy.start_time
    day        = var.maintenance_policy.day
  }
  
  # Configurações de rede
  vpc_uuid = var.vpc_uuid
  
  # Tags
  tags = local.all_tags
  
  # Node pool padrão (temporário)
  node_pool {
    name       = "default-pool"
    size       = "s-2vcpu-2gb"
    node_count = 1
    tags       = concat(local.all_tags, ["default-pool", "temporary"])
  }
  
  lifecycle {
    ignore_changes = [node_pool]
  }
}

# =============================================================================
# NODE POOLS DEDICADOS
# =============================================================================

resource "digitalocean_kubernetes_node_pool" "staging_pools" {
  for_each = var.node_pools
  
  cluster_id = digitalocean_kubernetes_cluster.staging.id
  
  name       = each.key
  size       = each.value.size
  node_count = each.value.node_count
  
  # Auto scaling
  auto_scale = each.value.auto_scale
  min_nodes  = each.value.auto_scale ? each.value.min_nodes : null
  max_nodes  = each.value.auto_scale ? each.value.max_nodes : null
  
  # Labels detalhados para staging
  labels = merge(
    each.value.labels,
    {
      "node-pool"           = each.key
      "cluster-name"        = var.cluster_name
      "environment"         = var.environment
      "auto-upgrade"        = tostring(local.staging_config.auto_upgrade)
      "surge-upgrade"       = tostring(local.staging_config.surge_upgrade)
      "monitoring-enabled"  = "true"
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
# NAMESPACES PARA STAGING
# =============================================================================

resource "kubernetes_namespace" "staging" {
  metadata {
    name = "staging"
    
    labels = {
      environment = var.environment
      project     = var.project
      tier        = "staging"
      monitoring  = "enabled"
    }
    
    annotations = {
      "scheduler.alpha.kubernetes.io/preferred-anti-affinity" = "true"
    }
  }
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
    
    labels = {
      environment = var.environment
      purpose     = "monitoring"
      tier        = "system"
    }
  }
}

resource "kubernetes_namespace" "testing" {
  metadata {
    name = "testing"
    
    labels = {
      environment = var.environment
      purpose     = "load-testing"
      tier        = "testing"
    }
  }
}

# =============================================================================
# CONFIGURAÇÕES DE RECURSOS E POLÍTICAS
# =============================================================================

# Resource Quota para namespace staging
resource "kubernetes_resource_quota" "staging" {
  metadata {
    name      = "staging-resources"
    namespace = kubernetes_namespace.staging.metadata[0].name
  }
  
  spec {
    hard = {
      "requests.cpu"    = "6000m"      # 6 CPUs de requests
      "requests.memory" = "12Gi"       # 12GB de memory requests
      "limits.cpu"      = "12000m"     # 12 CPUs de limits
      "limits.memory"   = "24Gi"       # 24GB de memory limits
      "pods"           = "50"          # Máximo 50 pods
      "services"       = "20"          # Máximo 20 services
      "persistentvolumeclaims" = "10"  # Máximo 10 PVCs
    }
  }
}

# Limit Range para pods
resource "kubernetes_limit_range" "staging" {
  metadata {
    name      = "staging-limits"
    namespace = kubernetes_namespace.staging.metadata[0].name
  }
  
  spec {
    limit {
      type = "Pod"
      max = {
        cpu    = "2000m"
        memory = "4Gi"
      }
      min = {
        cpu    = "100m"
        memory = "128Mi"
      }
    }
    
    limit {
      type = "Container"
      default = {
        cpu    = "500m"
        memory = "512Mi"
      }
      default_request = {
        cpu    = "100m"
        memory = "128Mi"
      }
    }
  }
}

# Network Policy para isolamento básico
resource "kubernetes_network_policy" "staging" {
  metadata {
    name      = "staging-network-policy"
    namespace = kubernetes_namespace.staging.metadata[0].name
  }
  
  spec {
    pod_selector {}
    
    policy_types = ["Ingress", "Egress"]
    
    # Permite tráfego interno do namespace
    ingress {
      from {
        namespace_selector {
          match_labels = {
            name = "staging"
          }
        }
      }
    }
    
    # Permite tráfego do namespace de monitoring
    ingress {
      from {
        namespace_selector {
          match_labels = {
            purpose = "monitoring"
          }
        }
      }
    }
    
    # Permite todo tráfego de saída
    egress {}
  }
}

# =============================================================================
# CONFIGURAÇÕES BÁSICAS DE MONITORAMENTO
# =============================================================================

# ConfigMap com configurações de cluster
resource "kubernetes_config_map" "cluster_config" {
  metadata {
    name      = "cluster-config"
    namespace = kubernetes_namespace.staging.metadata[0].name
  }
  
  data = {
    cluster_name      = var.cluster_name
    environment       = var.environment
    auto_upgrade      = tostring(local.staging_config.auto_upgrade)
    surge_upgrade     = tostring(local.staging_config.surge_upgrade)
    monitoring        = "enabled"
    load_testing      = "enabled"
    backup_retention  = tostring(local.staging_config.backup_retention_days)
    log_retention     = tostring(local.staging_config.log_retention_days)
  }
}

# Service Account para monitoramento
resource "kubernetes_service_account" "monitoring" {
  metadata {
    name      = "monitoring-sa"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }
}

# =============================================================================
# OUTPUTS
# =============================================================================

output "cluster_info" {
  description = "Informações do cluster de staging"
  value = {
    id              = digitalocean_kubernetes_cluster.staging.id
    name            = digitalocean_kubernetes_cluster.staging.name
    region          = digitalocean_kubernetes_cluster.staging.region
    version         = digitalocean_kubernetes_cluster.staging.version
    endpoint        = digitalocean_kubernetes_cluster.staging.endpoint
    status          = digitalocean_kubernetes_cluster.staging.status
    auto_upgrade    = digitalocean_kubernetes_cluster.staging.auto_upgrade
    surge_upgrade   = digitalocean_kubernetes_cluster.staging.surge_upgrade
  }
}

output "upgrade_configuration" {
  description = "Configurações de upgrade"
  value = {
    auto_upgrade_enabled  = local.staging_config.auto_upgrade
    surge_upgrade_enabled = local.staging_config.surge_upgrade
    maintenance_window    = "${var.maintenance_policy.day} at ${var.maintenance_policy.start_time}"
    surge_strategy        = var.surge_config
  }
}

output "node_pools_info" {
  description = "Informações dos node pools"
  value = {
    for k, v in digitalocean_kubernetes_node_pool.staging_pools : k => {
      id         = v.id
      name       = v.name
      size       = v.size
      node_count = v.node_count
      min_nodes  = v.min_nodes
      max_nodes  = v.max_nodes
      nodes      = v.nodes
    }
  }
}

output "cost_estimation" {
  description = "Estimativa de custos do ambiente de staging"
  value = {
    base_cost_monthly     = "$84-168/mês (3-6 nodes)"
    load_balancer_monthly = "$12/mês"
    total_estimated       = "$96-180/mês"
    cost_optimization     = "Auto-scale habilitado para reduzir custos"
  }
}

output "namespaces" {
  description = "Namespaces criados"
  value = {
    staging    = kubernetes_namespace.staging.metadata[0].name
    monitoring = kubernetes_namespace.monitoring.metadata[0].name
    testing    = kubernetes_namespace.testing.metadata[0].name
  }
}

output "useful_commands" {
  description = "Comandos úteis para staging"
  value = {
    kubeconfig        = "doctl kubernetes cluster kubeconfig save ${digitalocean_kubernetes_cluster.staging.name}"
    switch_to_staging = "kubectl config set-context --current --namespace=staging"
    get_nodes         = "kubectl get nodes -o wide --show-labels"
    cluster_info      = "kubectl cluster-info"
    monitor_upgrades  = "kubectl get events --sort-by='.metadata.creationTimestamp' -w"
  }
}

output "testing_endpoints" {
  description = "Endpoints para testes"
  value = {
    load_testing_namespace = "testing"
    monitoring_namespace   = "monitoring"
    staging_namespace      = "staging"
  }
}
```

### Arquivo `environments/staging/monitoring.tf`

```hcl
# =============================================================================
# CONFIGURAÇÕES DE MONITORAMENTO PARA STAGING
# =============================================================================

# ConfigMap para Prometheus
resource "kubernetes_config_map" "prometheus_config" {
  metadata {
    name      = "prometheus-config"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }
  
  data = {
    "prometheus.yml" = <<-EOT
      global:
        scrape_interval: 30s
        evaluation_interval: 30s
      
      scrape_configs:
        - job_name: 'kubernetes-apiservers'
          kubernetes_sd_configs:
          - role: endpoints
          scheme: https
          tls_config:
            ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
          bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
          relabel_configs:
          - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
            action: keep
            regex: default;kubernetes;https
        
        - job_name: 'kubernetes-nodes'
          kubernetes_sd_configs:
          - role: node
          scheme: https
          tls_config:
            ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
          bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
          relabel_configs:
          - action: labelmap
            regex: __meta_kubernetes_node_label_(.+)
        
        - job_name: 'kubernetes-pods'
          kubernetes_sd_configs:
          - role: pod
          relabel_configs:
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
            action: keep
            regex: true
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
            action: replace
            target_label: __metrics_path__
            regex: (.+)
          - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
            action: replace
            regex: ([^:]+)(?::\d+)?;(\d+)
            replacement: $1:$2
            target_label: __address__
          - action: labelmap
            regex: __meta_kubernetes_pod_label_(.+)
          - source_labels: [__meta_kubernetes_namespace]
            action: replace
            target_label: kubernetes_namespace
          - source_labels: [__meta_kubernetes_pod_name]
            action: replace
            target_label: kubernetes_pod_name
    EOT
  }
}

# Deployment do Prometheus (versão simples para staging)
resource "kubernetes_deployment" "prometheus" {
  metadata {
    name      = "prometheus"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    labels = {
      app = "prometheus"
    }
  }
  
  spec {
    replicas = 1
    
    selector {
      match_labels = {
        app = "prometheus"
      }
    }
    
    template {
      metadata {
        labels = {
          app = "prometheus"
        }
      }
      
      spec {
        service_account_name = kubernetes_service_account.monitoring.metadata[0].name
        
        container {
          name  = "prometheus"
          image = "prom/prometheus:v2.40.0"
          
          args = [
            "--config.file=/etc/prometheus/prometheus.yml",
            "--storage.tsdb.path=/prometheus/",
            "--web.console.libraries=/etc/prometheus/console_libraries",
            "--web.console.templates=/etc/prometheus/consoles",
            "--storage.tsdb.retention.time=7d",
            "--web.enable-lifecycle"
          ]
          
          port {
            container_port = 9090
          }
          
          volume_mount {
            name       = "prometheus-config"
            mount_path = "/etc/prometheus"
          }
          
          volume_mount {
            name       = "prometheus-storage"
            mount_path = "/prometheus"
          }
          
          resources {
            requests = {
              cpu    = "200m"
              memory = "512Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "1Gi"
            }
          }
        }
        
        volume {
          name = "prometheus-config"
          config_map {
            name = kubernetes_config_map.prometheus_config.metadata[0].name
          }
        }
        
        volume {
          name = "prometheus-storage"
          empty_dir {}
        }
      }
    }
  }
}

# Service para Prometheus
resource "kubernetes_service" "prometheus" {
  metadata {
    name      = "prometheus"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    labels = {
      app = "prometheus"
    }
  }
  
  spec {
    selector = {
      app = "prometheus"
    }
    
    port {
      port        = 9090
      target_port = 9090
      protocol    = "TCP"
    }
    
    type = "ClusterIP"
  }
}

# ClusterRole para Prometheus
resource "kubernetes_cluster_role" "prometheus" {
  metadata {
    name = "prometheus"
  }
  
  rule {
    api_groups = [""]
    resources  = ["nodes", "nodes/proxy", "services", "endpoints", "pods"]
    verbs      = ["get", "list", "watch"]
  }
  
  rule {
    api_groups = ["extensions"]
    resources  = ["ingresses"]
    verbs      = ["get", "list", "watch"]
  }
  
  rule {
    non_resource_urls = ["/metrics"]
    verbs             = ["get"]
  }
}

# ClusterRoleBinding para Prometheus
resource "kubernetes_cluster_role_binding" "prometheus" {
  metadata {
    name = "prometheus"
  }
  
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.prometheus.metadata[0].name
  }
  
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.monitoring.metadata[0].name
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }
}
```

## 🚀 Como Usar

### 1. Preparação

```bash
# Clone e navegue para staging
cd terraform/environments/staging

# Configure credenciais
export DIGITALOCEAN_TOKEN="seu-token"

# Configure backend (se usando S3/Spaces)
export AWS_ACCESS_KEY_ID="sua-access-key"
export AWS_SECRET_ACCESS_KEY="sua-secret-key"
```

### 2. Customização

```hcl
# Edite terraform.tfvars conforme sua necessidade
cluster_name = "staging-meu-projeto"
project     = "meu-projeto"

# Ajuste node pools se necessário
node_pools = {
  workers = {
    size       = "s-2vcpu-4gb"  # ou s-4vcpu-8gb para mais performance
    node_count = 3
    min_nodes  = 3
    max_nodes  = 6
    auto_scale = true
    tags       = ["staging", "primary"]
    labels = {
      role = "worker"
      tier = "staging"
    }
    taints = []
  }
}
```

### 3. Deploy

```bash
# Inicializar
terraform init

# Planejar
terraform plan

# Aplicar
terraform apply

# Configurar kubectl
doctl kubernetes cluster kubeconfig save staging-meu-projeto
```

### 4. Verificação

```bash
# Verificar cluster
kubectl cluster-info
kubectl get nodes -o wide

# Verificar namespaces
kubectl get namespaces

# Verificar monitoramento
kubectl get pods -n monitoring

# Testar acesso ao Prometheus
kubectl port-forward -n monitoring service/prometheus 9090:9090
# Abrir http://localhost:9090
```

## 💰 Estimativa de Custos

### Configuração Básica

```
3x s-2vcpu-4gb nodes = 3 × $42/mês = $126/mês
1x Load Balancer = $12/mês
Total base: ~$138/mês
```

### Durante Auto Scale

```
Máximo 6 nodes = 6 × $42/mês = $252/mês (temporário)
Média esperada: ~$180/mês
```

### Durante Surge Upgrade

```
Surge +1 node = +$42 durante upgrade (algumas horas)
Custo adicional mensal negligível
```

## 🧪 Funcionalidades de Teste

### 1. Load Testing

```yaml
# load-test-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: load-test
  namespace: testing
spec:
  template:
    spec:
      containers:
      - name: load-test
        image: williamyeh/wrk
        command:
        - wrk
        - -t4
        - -c100
        - -d30s
        - http://minha-app.staging.svc.cluster.local
      restartPolicy: Never
```

### 2. Chaos Testing

```yaml
# chaos-monkey.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: chaos-monkey
  namespace: testing
spec:
  replicas: 1
  selector:
    matchLabels:
      app: chaos-monkey
  template:
    metadata:
      labels:
        app: chaos-monkey
    spec:
      containers:
      - name: chaos-monkey
        image: quay.io/linki/chaoskube:v0.21.0
        args:
        - --interval=10m
        - --dry-run=false
        - --annotation-selector=chaos.alpha.kubernetes.io/enabled=true
        - --timezone=Europe/Berlin
```

### 3. Upgrade Testing

```bash
#!/bin/bash
# test-upgrade.sh

echo "Testing upgrade scenario..."

# 1. Deploy test app
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: upgrade-test-app
  namespace: staging
spec:
  replicas: 3
  selector:
    matchLabels:
      app: upgrade-test
  template:
    metadata:
      labels:
        app: upgrade-test
    spec:
      containers:
      - name: app
        image: nginx:1.20
        ports:
        - containerPort: 80
EOF

# 2. Create service
kubectl expose deployment upgrade-test-app --port=80 --target-port=80 -n staging

# 3. Monitor during upgrade
kubectl get pods -n staging -w &
WATCH_PID=$!

# 4. Trigger manual upgrade (or wait for auto upgrade)
echo "Upgrade will be tested during next maintenance window"
echo "Monitor with: kubectl get events --sort-by='.metadata.creationTimestamp' -w"

# Cleanup
kill $WATCH_PID
```

## 📊 Monitoramento e Alertas

### Métricas Importantes

```bash
# Node health
kubectl top nodes

# Pod distribution
kubectl get pods -o wide --all-namespaces

# Events related to upgrades
kubectl get events --field-selector reason=NodeReady
kubectl get events --field-selector reason=NodeNotReady

# Resource usage
kubectl describe nodes | grep -A 5 "Allocated resources"
```

### Configuração de Alertas

```yaml
# alert-rules.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: alert-rules
  namespace: monitoring
data:
  alerts.yml: |
    groups:
    - name: kubernetes-staging
      rules:
      - alert: NodeDown
        expr: up{job="kubernetes-nodes"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Node {{ $labels.instance }} is down"
      
      - alert: PodCrashLooping
        expr: rate(kube_pod_container_status_restarts_total[15m]) > 0
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Pod {{ $labels.pod }} is crash looping"
      
      - alert: HighMemoryUsage
        expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes > 0.8
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage on {{ $labels.instance }}"
```

## 🔧 Manutenção e Operações

### Rotinas de Manutenção

```bash
#!/bin/bash
# staging-maintenance.sh

# 1. Verificar saúde do cluster
kubectl get nodes
kubectl get pods --all-namespaces --field-selector=status.phase!=Running

# 2. Verificar recursos
kubectl top nodes
kubectl top pods --all-namespaces

# 3. Limpar recursos antigos
kubectl delete jobs --field-selector status.successful=1 -n testing
kubectl delete pods --field-selector=status.phase=Succeeded --all-namespaces

# 4. Backup de configurações importantes
kubectl get configmaps -o yaml > configmaps-backup-$(date +%Y%m%d).yaml
kubectl get secrets -o yaml > secrets-backup-$(date +%Y%m%d).yaml

# 5. Verificar upgrades disponíveis
doctl kubernetes options versions
```

### Debugging de Upgrades

```bash
# Monitorar upgrade em tempo real
kubectl get events --sort-by='.metadata.creationTimestamp' -w

# Verificar status dos nodes durante upgrade
watch "kubectl get nodes -o wide"

# Logs do control plane (via DigitalOcean)
doctl kubernetes cluster get staging-cluster --format ID,Name,Status,Version

# Verificar pods que não conseguem agendar
kubectl get pods --all-namespaces --field-selector=status.phase=Pending
```

## 📚 Próximos Passos

1. 🚀 **Deploy aplicações de teste**: Use este ambiente para validar suas aplicações
2. 🔧 **Configure CI/CD**: Automatize deploys para staging
3. 📊 **Implemente monitoramento completo**: Adicione Grafana e alertas
4. 🧪 **Execute testes de carga**: Valide performance antes da produção
5. 🏗️ **Evolua para produção**: Use como base para ambiente de produção

## 🔗 Links Relacionados

- [Configuração de Desenvolvimento](development.md)
- [Configuração de Produção](production.md)
- [Guia de Configuração Completo](../configuration-guide.md)
- [FAQ](../faq.md)

---

**Importante**: Este ambiente deve espelhar a produção o máximo possível para validação eficaz dos upgrades.