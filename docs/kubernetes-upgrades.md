# Configurações de Upgrade do Kubernetes na DigitalOcean

Esta documentação detalha as principais configurações para upgrades de clusters Kubernetes na DigitalOcean, focando nas opções `auto_upgrade` e `surge_upgrade`.

## 🎯 Visão Geral

Os upgrades de Kubernetes são uma parte crítica da manutenção de clusters. A DigitalOcean oferece duas configurações principais para automatizar e otimizar este processo:

- **`auto_upgrade`**: Automatiza upgrades do control plane
- **`surge_upgrade`**: Permite upgrades de nodes com zero downtime

## 🔄 Auto Upgrade (`auto_upgrade`)

### O que é

O `auto_upgrade` é uma funcionalidade que permite atualizações automáticas do control plane do cluster Kubernetes. Quando habilitado, a DigitalOcean gerencia automaticamente os upgrades para versões mais recentes do Kubernetes.

### Como Funciona

```hcl
resource "digitalocean_kubernetes_cluster" "example" {
  name    = "exemplo-cluster"
  region  = "nyc1"
  version = "1.28.2-do.0"
  
  auto_upgrade = true  # Habilita upgrade automático
  
  node_pool {
    name       = "worker-pool"
    size       = "s-2vcpu-2gb"
    node_count = 3
  }
}
```

### ⚡ Vantagens

1. **Automação Completa**: Elimina a necessidade de upgrades manuais
2. **Segurança**: Mantém o cluster sempre atualizado com patches de segurança
3. **Compatibilidade**: Garante compatibilidade com recursos mais recentes
4. **Redução de Overhead**: Menos trabalho manual para a equipe de DevOps

### ⚠️ Desvantagens

1. **Controle Limitado**: Menos controle sobre o timing dos upgrades
2. **Risco de Incompatibilidade**: Possível quebra de aplicações não testadas
3. **Downtime Potencial**: Pode causar indisponibilidade temporária
4. **Dependência**: Depende da estabilidade dos upgrades automáticos da DO

### 🔧 Configuração Técnica

#### Variáveis Terraform

```hcl
variable "auto_upgrade_enabled" {
  description = "Habilita upgrade automático do control plane"
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
}
```

#### Exemplo Completo

```hcl
resource "digitalocean_kubernetes_cluster" "main" {
  name     = var.cluster_name
  region   = var.region
  version  = var.kubernetes_version
  
  auto_upgrade = var.auto_upgrade_enabled
  
  maintenance_policy {
    start_time = var.maintenance_policy.start_time
    day        = var.maintenance_policy.day
  }
  
  node_pool {
    name       = "primary"
    size       = var.node_size
    node_count = var.node_count
    
    auto_scale = true
    min_nodes  = var.min_nodes
    max_nodes  = var.max_nodes
  }
}
```

### 🕒 Timing das Atualizações

- **Janela de Manutenção**: Configurável através da `maintenance_policy`
- **Frequência**: Baseada na disponibilidade de novas versões
- **Notificação**: A DigitalOcean envia notificações antes dos upgrades

### 🔙 Estratégias de Rollback

1. **Backup Antes do Upgrade**: Sempre faça backup do estado do cluster
2. **Teste em Staging**: Use ambiente de teste para validar compatibilidade
3. **Monitoramento**: Configure alertas para detectar problemas rapidamente
4. **Plano de Contingência**: Tenha um plano para reversão manual se necessário

## 🚀 Surge Upgrade (`surge_upgrade`)

### O que é

O `surge_upgrade` é uma estratégia que permite atualizações de nodes com zero downtime, criando temporariamente nodes adicionais durante o processo de upgrade.

### Como Funciona

```hcl
resource "digitalocean_kubernetes_cluster" "example" {
  name    = "exemplo-cluster"
  region  = "nyc1"
  version = "1.28.2-do.0"
  
  node_pool {
    name       = "worker-pool"
    size       = "s-2vcpu-2gb"
    node_count = 3
    
    # Configuração do Surge Upgrade
    auto_scale = true
    min_nodes  = 3
    max_nodes  = 6  # Permite dobrar temporariamente
  }
  
  surge_upgrade = true
  max_surge     = "50%"  # Até 50% de nodes extras durante upgrade
}
```

### ⚡ Vantagens

1. **Zero Downtime**: Mantém aplicações rodando durante upgrades
2. **Disponibilidade**: Preserva a capacidade do cluster durante o processo
3. **Segurança**: Permite rollback mais seguro
4. **Performance**: Mantém performance durante a transição

### ⚠️ Desvantagens

1. **Custo Temporário**: Nodes extras geram custos adicionais durante upgrade
2. **Complexidade**: Mais complexo de configurar e monitorar
3. **Recursos**: Requer limites de quota maiores na conta da DigitalOcean
4. **Tempo**: Processo pode ser mais demorado

### 🔧 Configuração Detalhada

#### Parâmetros Principais

```hcl
variable "surge_upgrade_config" {
  description = "Configuração do surge upgrade"
  type = object({
    enabled    = bool
    max_surge  = string
    max_unavailable = string
  })
  default = {
    enabled         = true
    max_surge       = "1"
    max_unavailable = "0"
  }
}
```

#### Exemplo de Node Pool com Surge

```hcl
resource "digitalocean_kubernetes_node_pool" "workers" {
  cluster_id = digitalocean_kubernetes_cluster.main.id
  
  name       = "worker-nodes"
  size       = "s-4vcpu-8gb"
  node_count = 3
  
  # Configurações para Surge Upgrade
  auto_scale = true
  min_nodes  = 3
  max_nodes  = 6  # Permite surge de 100%
  
  tags = ["worker", "production"]
  
  taint {
    key    = "workload-type"
    value  = "general"
    effect = "NoSchedule"
  }
}
```

### 💰 Impacto nos Custos

#### Cálculo de Custos Durante Surge

```hcl
# Exemplo: Cluster com 3 nodes s-2vcpu-2gb
# Custo normal: 3 × $24/mês = $72/mês
# Durante surge (50%): 3 + 1.5 ≈ 5 nodes por algumas horas
# Custo adicional temporário: ~$12 durante o upgrade
```

#### Configuração para Controle de Custos

```hcl
variable "surge_cost_control" {
  description = "Controles para minimizar custos do surge"
  type = object({
    max_surge_percentage = number
    preferred_surge_time = string
    cost_alert_threshold = number
  })
  default = {
    max_surge_percentage = 25  # Máximo 25% de nodes extras
    preferred_surge_time = "02:00"  # Horário de menor uso
    cost_alert_threshold = 150  # Alert se custo > 150% do normal
  }
}
```

### 🛡️ Configurações Complementares

#### 1. Pod Disruption Budgets (PDB)

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: app-pdb
spec:
  minAvailable: 75%
  selector:
    matchLabels:
      app: my-application
```

#### 2. Resource Requests e Limits

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-deployment
spec:
  replicas: 3
  template:
    spec:
      containers:
      - name: app
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
```

#### 3. Node Affinity

```yaml
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - my-app
              topologyKey: kubernetes.io/hostname
```

## 🎛️ Combinando Auto Upgrade e Surge Upgrade

### Configuração Recomendada

```hcl
resource "digitalocean_kubernetes_cluster" "production" {
  name    = "prod-cluster"
  region  = "fra1"
  version = "1.28.2-do.0"
  
  # Combina ambas as funcionalidades
  auto_upgrade  = true
  surge_upgrade = true
  
  maintenance_policy {
    start_time = "03:00"  # Horário de menor tráfego
    day        = "sunday"  # Dia com menor impacto
  }
  
  node_pool {
    name       = "production-workers"
    size       = "s-4vcpu-8gb"
    node_count = 5
    
    auto_scale = true
    min_nodes  = 5
    max_nodes  = 10  # Permite surge de 100%
    
    tags = ["production", "auto-upgrade", "surge-capable"]
  }
}
```

### ⚖️ Melhores Práticas

#### Para Desenvolvimento
- ✅ `auto_upgrade = true` (atualizações rápidas)
- ❌ `surge_upgrade = false` (economizar custos)
- 🕒 Janela de manutenção flexível

#### Para Staging
- ✅ `auto_upgrade = true` (testar upgrades antes da produção)
- ✅ `surge_upgrade = true` (simular ambiente de produção)
- 🕒 Janela antes da produção

#### Para Produção
- ⚠️ `auto_upgrade = false` ou configurado cuidadosamente
- ✅ `surge_upgrade = true` (zero downtime crítico)
- 🕒 Janela de manutenção rigorosamente controlada

## 🔍 Monitoramento Durante Upgrades

### Métricas Essenciais

```hcl
# Exemplo de configuração de alertas
resource "digitalocean_monitoring_alert_policy" "cluster_health" {
  alerts {
    email = ["devops@empresa.com"]
  }
  
  description = "Alerta de saúde do cluster durante upgrades"
  type        = "v1/insights/cluster/node_cpu"
  compare     = "GreaterThan"
  value       = 80
  window      = "5m"
  
  entities = [digitalocean_kubernetes_cluster.main.id]
}
```

### Dashboard de Monitoramento

Monitore as seguintes métricas durante upgrades:

1. **CPU e Memória dos Nodes**
2. **Status dos Pods**
3. **Latência de API**
4. **Eventos do Cluster**
5. **Logs de Sistema**

## 🚨 Troubleshooting Comum

### Problemas com Auto Upgrade

1. **Upgrade Falha**: Verifique logs do control plane
2. **Incompatibilidade**: Teste aplicações em cluster de staging
3. **Performance**: Monitore métricas durante e após upgrade

### Problemas com Surge Upgrade

1. **Falta de Recursos**: Aumente limites de quota na DO
2. **Pods Não Agendam**: Verifique resource requests e node capacity
3. **Custo Elevado**: Ajuste `max_surge` para valor menor

### Comandos Úteis

```bash
# Verificar status do cluster
doctl kubernetes cluster get <cluster-name>

# Listar nodes e seu status
kubectl get nodes -o wide

# Verificar eventos do cluster
kubectl get events --sort-by=.metadata.creationTimestamp

# Verificar pods com problemas
kubectl get pods --all-namespaces --field-selector=status.phase!=Running
```

## 📚 Próximos Passos

1. 📖 Leia o [Guia de Configuração](configuration-guide.md) para implementação prática
2. 💡 Veja os [Exemplos](examples/) para seu ambiente específico
3. ❓ Consulte o [FAQ](faq.md) para dúvidas comuns
4. 🔧 Configure monitoramento adequado para seu cluster

---

**Importante**: Sempre teste configurações de upgrade em ambientes não-críticos antes de aplicar em produção.