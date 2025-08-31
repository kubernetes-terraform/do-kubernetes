# FAQ - Perguntas Frequentes sobre Upgrades Kubernetes

Esta seção responde às perguntas mais comuns sobre configurações de upgrade do Kubernetes na DigitalOcean.

## 🎯 Perguntas Gerais

### Q1: Qual a diferença entre `auto_upgrade` e `surge_upgrade`?

**R:** São funcionalidades complementares mas distintas:

- **`auto_upgrade`**: Atualiza automaticamente o **control plane** do Kubernetes
- **`surge_upgrade`**: Controla como os **worker nodes** são atualizados, permitindo zero downtime

```hcl
resource "digitalocean_kubernetes_cluster" "example" {
  auto_upgrade  = true   # Control plane automático
  surge_upgrade = true   # Worker nodes sem downtime
}
```

### Q2: Posso usar as duas configurações juntas?

**R:** Sim! É até recomendado para produção:

```hcl
resource "digitalocean_kubernetes_cluster" "prod" {
  auto_upgrade  = true   # Mantém control plane atualizado
  surge_upgrade = true   # Zero downtime nos nodes
  
  maintenance_policy {
    start_time = "04:00"
    day        = "sunday"
  }
}
```

### Q3: Qual configuração usar para cada ambiente?

**R:** Recomendações por ambiente:

| Ambiente | auto_upgrade | surge_upgrade | Motivo |
|----------|-------------|---------------|---------|
| **Development** | ✅ true | ❌ false | Atualizações rápidas, economia de custo |
| **Staging** | ✅ true | ✅ true | Simular produção, testar upgrades |
| **Production** | ⚠️ depende | ✅ true | Controle vs automação, zero downtime |

## 🔄 Auto Upgrade

### Q4: Como funciona exatamente o auto_upgrade?

**R:** O auto_upgrade atualiza automaticamente o control plane do Kubernetes:

1. **Detecção**: DO verifica novas versões disponíveis
2. **Agendamento**: Upgrade ocorre na janela de manutenção
3. **Execução**: Control plane é atualizado automaticamente
4. **Notificação**: Você recebe notificação do status

```hcl
resource "digitalocean_kubernetes_cluster" "main" {
  auto_upgrade = true
  
  maintenance_policy {
    start_time = "03:00"  # 3:00 AM
    day        = "sunday" # Domingo
  }
}
```

### Q5: Posso controlar quando os upgrades acontecem?

**R:** Sim, através da `maintenance_policy`:

```hcl
maintenance_policy {
  start_time = "02:00"    # Horário (formato 24h)
  day        = "saturday" # Dia da semana ou "any"
}
```

**Opções de dia:**
- `monday`, `tuesday`, `wednesday`, `thursday`, `friday`, `saturday`, `sunday`
- `any` (qualquer dia)

### Q6: O que acontece se o upgrade falhar?

**R:** A DigitalOcean tem mecanismos de segurança:

1. **Backup automático** antes do upgrade
2. **Rollback automático** em caso de falha
3. **Notificação** sobre status do upgrade
4. **Suporte** disponível para investigação

**Como verificar:**
```bash
# Status do cluster
doctl kubernetes cluster get meu-cluster

# Eventos recentes
kubectl get events --sort-by='.metadata.creationTimestamp'
```

### Q7: Auto upgrade atualiza os worker nodes também?

**R:** Não! `auto_upgrade` apenas atualiza o **control plane**. Para nodes:

```hcl
resource "digitalocean_kubernetes_node_pool" "workers" {
  # Nodes são atualizados separadamente
  # Você pode usar surge_upgrade para controlar como
}
```

Para atualizar nodes manualmente:
```bash
# Via CLI da DigitalOcean
doctl kubernetes cluster node-pool upgrade meu-cluster workers
```

## 🚀 Surge Upgrade

### Q8: Como o surge upgrade funciona?

**R:** O surge upgrade cria nodes temporários durante a atualização:

1. **Criação**: Novos nodes com versão atualizada
2. **Migração**: Pods são movidos para novos nodes
3. **Drenagem**: Nodes antigos são esvaziados
4. **Remoção**: Nodes antigos são deletados

```
Antes:  [Node1] [Node2] [Node3]
Durante: [Node1] [Node2] [Node3] [Node4-novo] [Node5-novo]
Depois:  [Node4] [Node5] [Node6-novo]
```

### Q9: Quanto custa o surge upgrade?

**R:** Há custo adicional temporário pelos nodes extras:

```hcl
# Exemplo: 3 nodes s-2vcpu-2gb ($24/mês cada)
# Custo normal: 3 × $24 = $72/mês
# Durante surge (50%): 3 + 1.5 ≈ 5 nodes
# Custo extra: ~$36 durante algumas horas do upgrade
```

**Para controlar custos:**
```hcl
surge_config = {
  max_surge       = "1"    # Apenas 1 node extra por vez
  max_unavailable = "0"    # Zero indisponibilidade
}
```

### Q10: Posso configurar quantos nodes extras usar?

**R:** Sim, através do `max_surge`:

```hcl
# Diferentes estratégias de surge
surge_config = {
  # Conservador (menos custo)
  max_surge = "1"          # 1 node extra por vez
  
  # Balanceado
  max_surge = "25%"        # 25% dos nodes existentes
  
  # Agressivo (mais rápido)
  max_surge = "50%"        # 50% dos nodes existentes
}
```

### Q11: O que é max_unavailable?

**R:** Controla quantos nodes podem ficar indisponíveis simultaneamente:

```hcl
surge_config = {
  max_surge       = "2"
  max_unavailable = "1"    # Máximo 1 node indisponível
}
```

**Para zero downtime**, sempre use:
```hcl
max_unavailable = "0"      # Nunca deixar nodes indisponíveis
```

## 🔧 Configuração e Implementação

### Q12: Como migrar um cluster existente para usar essas configurações?

**R:** Atualize gradualmente:

```hcl
# 1. Primeiro, habilite apenas auto_upgrade
resource "digitalocean_kubernetes_cluster" "main" {
  auto_upgrade  = true   # ← Adicione isto primeiro
  surge_upgrade = false  # Mantenha false inicialmente
}

# 2. Depois de testar, habilite surge_upgrade
resource "digitalocean_kubernetes_cluster" "main" {
  auto_upgrade  = true
  surge_upgrade = true   # ← Habilite depois de validar
}
```

### Q13: Como testar se as configurações estão funcionando?

**R:** Teste em ambiente controlado:

```bash
# 1. Verificar configuração atual
doctl kubernetes cluster get meu-cluster

# 2. Forçar upgrade manual para testar
doctl kubernetes cluster upgrade meu-cluster --version=1.28.3-do.0

# 3. Monitorar durante o processo
kubectl get nodes -w
kubectl get events --sort-by='.metadata.creationTimestamp'

# 4. Verificar logs
kubectl logs -n kube-system -l k8s-app=kube-proxy
```

### Q14: Posso reverter as configurações?

**R:** Sim, mas com cuidados:

```hcl
# Reverter auto_upgrade
resource "digitalocean_kubernetes_cluster" "main" {
  auto_upgrade = false  # Desabilita upgrades automáticos
}

# Reverter surge_upgrade
resource "digitalocean_kubernetes_cluster" "main" {
  surge_upgrade = false  # Volta para upgrade tradicional
}
```

**⚠️ Atenção:** Mudanças podem requerer recreação do cluster!

## 🛠️ Troubleshooting

### Q15: Upgrade automático não está acontecendo

**R:** Verifique estas configurações:

```hcl
# 1. Confirme que está habilitado
auto_upgrade = true

# 2. Verifique a política de manutenção
maintenance_policy {
  start_time = "04:00"    # Formato HH:MM válido?
  day        = "sunday"   # Dia válido?
}

# 3. Confirme a versão atual vs disponível
data "digitalocean_kubernetes_versions" "current" {
  version_prefix = "1.28."
}
```

**Comandos para debug:**
```bash
# Versões disponíveis
doctl kubernetes options versions

# Status do cluster
doctl kubernetes cluster get meu-cluster --format ID,Name,Status,Version,AutoUpgrade
```

### Q16: Surge upgrade está custando muito

**R:** Ajuste as configurações:

```hcl
# Configuração mais econômica
surge_config = {
  max_surge       = "1"        # Apenas 1 node extra
  max_unavailable = "0"        # Zero indisponibilidade
}

# Para clusters pequenos
node_pool {
  auto_scale = true
  min_nodes  = 2               # Mínimo necessário
  max_nodes  = 4               # Limite o crescimento
}
```

### Q17: Pods não estão sendo migrados corretamente

**R:** Configure Pod Disruption Budgets:

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: app-pdb
spec:
  minAvailable: 75%           # Mínimo 75% disponível
  selector:
    matchLabels:
      app: minha-aplicacao
```

E resource requests apropriados:
```yaml
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

### Q18: Como monitorar upgrades em andamento?

**R:** Use estes comandos:

```bash
# 1. Status geral do cluster
kubectl get nodes -o wide

# 2. Eventos em tempo real
kubectl get events --watch

# 3. Status dos pods durante migração
kubectl get pods --all-namespaces -o wide

# 4. Logs do sistema
kubectl logs -n kube-system -l component=kube-apiserver

# 5. Métricas de recursos
kubectl top nodes
```

**Scripts úteis:**
```bash
#!/bin/bash
# monitor-upgrade.sh
while true; do
  echo "=== $(date) ==="
  kubectl get nodes --no-headers | awk '{print $1, $2}'
  echo "---"
  sleep 30
done
```

## 🔐 Segurança e Melhores Práticas

### Q19: Auto upgrade é seguro para produção?

**R:** Depende da sua estratégia:

**✅ Seguro quando:**
- Você tem testes automatizados robustos
- Ambiente de staging espelha produção
- Monitoramento abrangente configurado
- Plano de rollback bem definido

**⚠️ Cuidado quando:**
- Aplicações não foram testadas com novas versões K8s
- Mudanças críticas de API entre versões
- Integração com sistemas legados

**Configuração segura para prod:**
```hcl
resource "digitalocean_kubernetes_cluster" "prod" {
  auto_upgrade = true
  
  # Janela controlada
  maintenance_policy {
    start_time = "04:00"
    day        = "sunday"
  }
}
```

### Q20: Como garantir que aplicações sobrevivam aos upgrades?

**R:** Implemente estas práticas:

**1. Pod Disruption Budgets:**
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: app-pdb
spec:
  minAvailable: 2           # Mínimo 2 pods sempre
  selector:
    matchLabels:
      app: minha-app
```

**2. Multiple Replicas:**
```yaml
apiVersion: apps/v1
kind: Deployment
spec:
  replicas: 3               # Sempre múltiplas instâncias
```

**3. Health Checks:**
```yaml
containers:
- name: app
  livenessProbe:
    httpGet:
      path: /health
      port: 8080
    initialDelaySeconds: 30
  readinessProbe:
    httpGet:
      path: /ready
      port: 8080
```

**4. Graceful Shutdown:**
```yaml
containers:
- name: app
  lifecycle:
    preStop:
      exec:
        command: ["/bin/sh", "-c", "sleep 15"]
```

### Q21: Como backup antes de upgrades?

**R:** Estratégias de backup:

**1. Backup via Velero:**
```bash
# Instalar Velero
velero install --provider aws --bucket meu-backup-bucket

# Backup completo antes do upgrade
velero backup create pre-upgrade-backup --include-namespaces "*"
```

**2. Backup ETCD (via DigitalOcean):**
```bash
# DigitalOcean faz backup automático do ETCD
# Mas você pode criar snapshots manuais:
doctl kubernetes cluster get meu-cluster
```

**3. Backup de recursos importantes:**
```bash
# Export recursos críticos
kubectl get all -o yaml > cluster-backup.yaml
kubectl get configmaps -o yaml > configmaps-backup.yaml
kubectl get secrets -o yaml > secrets-backup.yaml
```

## 📊 Monitoramento e Observabilidade

### Q22: Que métricas devo monitorar durante upgrades?

**R:** Métricas essenciais:

**1. Node Health:**
```bash
# CPU e memória dos nodes
kubectl top nodes

# Status dos nodes
kubectl get nodes -o wide
```

**2. Pod Health:**
```bash
# Pods com problemas
kubectl get pods --all-namespaces --field-selector=status.phase!=Running

# Eventos de problemas
kubectl get events --field-selector type=Warning
```

**3. API Server:**
```bash
# Latência da API
kubectl get --raw /metrics | grep apiserver_request_duration

# Certificados expirando
kubectl get --raw /metrics | grep certificate_expiry
```

**4. Aplicação:**
- Response time das aplicações
- Error rate
- Throughput
- Disponibilidade dos serviços

### Q23: Como configurar alertas para upgrades?

**R:** Configure alertas para:

```hcl
# Alerta para upgrade iniciado
resource "digitalocean_monitoring_alert_policy" "upgrade_started" {
  alerts {
    email = ["devops@empresa.com"]
    slack {
      channel = "#k8s-alerts"
      url     = var.slack_webhook
    }
  }
  
  description = "Upgrade do cluster iniciado"
  type        = "v1/insights/cluster/upgrade_status"
  compare     = "GreaterThan"
  value       = 0
  window      = "5m"
}

# Alerta para CPU alta durante upgrade
resource "digitalocean_monitoring_alert_policy" "high_cpu_upgrade" {
  description = "CPU alta durante upgrade"
  type        = "v1/insights/droplet/cpu"
  compare     = "GreaterThan"
  value       = 85
  window      = "10m"
}
```

## 📈 Performance e Otimização

### Q24: Como otimizar performance durante upgrades?

**R:** Várias estratégias:

**1. Timing Inteligente:**
```hcl
maintenance_policy {
  start_time = "03:00"    # Horário de menor tráfego
  day        = "sunday"   # Dia de menor uso
}
```

**2. Recursos Adequados:**
```hcl
node_pools = {
  workers = {
    size       = "s-4vcpu-8gb"    # Nodes com recursos suficientes
    auto_scale = true
    min_nodes  = 3                # Sempre capacidade mínima
    max_nodes  = 8                # Permite crescer durante upgrade
  }
}
```

**3. Configuração de Surge Balanceada:**
```hcl
surge_config = {
  max_surge       = "25%"         # Balanced: não muito agressivo
  max_unavailable = "0"           # Zero downtime
}
```

### Q25: Como acelerar upgrades sem comprometer estabilidade?

**R:** Otimizações seguras:

**1. Paralelização Controlada:**
```hcl
surge_config = {
  max_surge = "2"                 # 2 nodes por vez (vs 1)
  max_unavailable = "0"           # Mantém zero downtime
}
```

**2. Pre-pull de Imagens:**
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: image-puller
spec:
  template:
    spec:
      initContainers:
      - name: pull-images
        image: minha-app:latest     # Pre-download das imagens
        command: ["echo", "done"]
```

**3. Resource Requests Otimizados:**
```yaml
containers:
- name: app
  resources:
    requests:
      cpu: "100m"               # Requests mínimos para scheduling rápido
      memory: "128Mi"
    limits:
      cpu: "500m"               # Limits apropriados
      memory: "512Mi"
```

## 🌐 Casos de Uso Específicos

### Q26: Como configurar para aplicações críticas 24/7?

**R:** Configuração ultra-conservadora:

```hcl
resource "digitalocean_kubernetes_cluster" "critical" {
  auto_upgrade  = false           # Controle manual total
  surge_upgrade = true            # Zero downtime essencial
  
  # Múltiplos node pools para redundância
  node_pool {
    name       = "critical-primary"
    size       = "s-4vcpu-8gb"
    node_count = 5
    auto_scale = true
    min_nodes  = 5
    max_nodes  = 10
  }
}

# Upgrade manual controlado
surge_config = {
  max_surge       = "1"           # Muito conservador
  max_unavailable = "0"           # Zero indisponibilidade
}
```

**+ Configurações de aplicação:**
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: critical-app-pdb
spec:
  minAvailable: 80%             # 80% sempre disponível
  selector:
    matchLabels:
      tier: critical

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: critical-app
spec:
  replicas: 5                   # Múltiplas réplicas
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0         # Zero downtime no deployment também
```

### Q27: Como configurar para ambientes de CI/CD?

**R:** Configuração otimizada para desenvolvimento:

```hcl
resource "digitalocean_kubernetes_cluster" "cicd" {
  auto_upgrade  = true            # Atualizações automáticas OK
  surge_upgrade = false           # Economia de custo
  
  maintenance_policy {
    start_time = "02:00"
    day        = "any"            # Qualquer dia OK
  }
  
  node_pool {
    name       = "ci-workers"
    size       = "s-2vcpu-4gb"
    node_count = 2
    auto_scale = true
    min_nodes  = 1              # Pode escalar para zero economizar
    max_nodes  = 10             # Pode crescer para builds paralelos
  }
}
```

### Q28: Como configurar multi-região?

**R:** Estratégia para alta disponibilidade:

```hcl
# Cluster principal
resource "digitalocean_kubernetes_cluster" "primary" {
  region        = "fra1"
  auto_upgrade  = false         # Controle manual para coordenar
  surge_upgrade = true
}

# Cluster secundário
resource "digitalocean_kubernetes_cluster" "secondary" {
  region        = "nyc1"
  auto_upgrade  = false         # Mesmo controle manual
  surge_upgrade = true
}

# Upgrade coordenado via automation
locals {
  upgrade_sequence = [
    "secondary",                # Upgrade secundário primeiro
    "primary"                   # Primary por último
  ]
}
```

## 🔚 Quando Usar Cada Configuração

### Matriz de Decisão

| Cenário | auto_upgrade | surge_upgrade | Motivo |
|---------|-------------|---------------|---------|
| **Dev/Test** | ✅ true | ❌ false | Atualizações rápidas, economia |
| **Staging** | ✅ true | ✅ true | Simular produção |
| **Prod não-crítica** | ✅ true | ✅ true | Automação com segurança |
| **Prod crítica** | ❌ false | ✅ true | Controle total, zero downtime |
| **CI/CD** | ✅ true | ❌ false | Economia, atualizações rápidas |
| **Multi-tenant** | ❌ false | ✅ true | Controle, isolamento |

---

## 📞 Precisa de mais ajuda?

- 📖 Consulte a [documentação principal](kubernetes-upgrades.md)
- ⚙️ Veja o [guia de configuração](configuration-guide.md)
- 💡 Confira os [exemplos práticos](examples/)
- 🐛 Reporte problemas nas [issues do GitHub](../../issues)

**Lembre-se:** Sempre teste configurações em ambiente não-crítico primeiro!