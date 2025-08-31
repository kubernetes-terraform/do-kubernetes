# Terraform DigitalOcean Kubernetes Module

Este módulo Terraform permite criar e gerenciar clusters Kubernetes na DigitalOcean de forma simples e segura, com integração ao Cloudflare R2 para armazenamento remoto de estado.

## Funcionalidades

- **Cluster Kubernetes** na DigitalOcean com configuração customizável
- **Node Pool** com auto-scaling configurável
- **Kubeconfig** salvo automaticamente para acesso local ao cluster
- **Backend R2** da Cloudflare para estado remoto
- **Exemplo completo** de uso incluído

## Recursos Criados

- Cluster Kubernetes na DigitalOcean
- Node pool com auto-scaling (min: 3, max: 5 nós por padrão)
- Arquivo kubeconfig local para acesso ao cluster
- Outputs com informações essenciais do cluster

## Como Usar

### 1. Exemplo Básico

```hcl
module "kubernetes_cluster" {
  source = "github.com/kubernetes-terraform/do-kubernetes"

  # Configurações do cluster
  cluster_name = "meu-cluster"
  region       = "nyc1"
  k8s_version  = "1.33.1-do.3"

  # Configurações do node pool
  node_pool_name       = "worker-nodes"
  node_pool_size       = "s-2vcpu-2gb"
  node_pool_auto_scale = true
  node_pool_min_nodes  = 3
  node_pool_max_nodes  = 5

  # Credenciais DigitalOcean
  do_pat = var.do_pat

  # Credenciais Cloudflare (para backend R2)
  cloudflare_api_token  = var.cloudflare_api_token
  cloudflare_account_id = var.cloudflare_account_id
  r2_access_key         = var.r2_access_key
  r2_access_secret      = var.r2_access_secret

  # Kubeconfig local
  write_kubeconfig = true
}
```

### 2. Exemplo Completo

Veja o exemplo completo na pasta [`examples/`](examples/) que inclui:

- Configuração completa do módulo
- Arquivo `terraform.tfvars` de exemplo
- Documentação detalhada de setup
- Instruções para obter credenciais

### 3. Configuração Rápida

```bash
# 1. Clone ou use o módulo
git clone https://github.com/kubernetes-terraform/do-kubernetes.git
cd do-kubernetes/examples

# 2. Configure suas credenciais no terraform.tfvars
cp terraform.tfvars.example terraform.tfvars
# Edite terraform.tfvars com suas credenciais

# 3. Execute o Terraform
terraform init
terraform plan
terraform apply -var-file=terraform.tfvars
```

## Variáveis de Entrada

| Nome                    | Descrição                    | Tipo     | Padrão                 | Obrigatória |
| ----------------------- | ---------------------------- | -------- | ---------------------- | ----------- |
| `cluster_name`          | Nome do cluster Kubernetes   | `string` | `"techpreta"`          | Não         |
| `region`                | Região da DigitalOcean       | `string` | `"nyc1"`               | Não         |
| `k8s_version`           | Versão do Kubernetes         | `string` | `"1.33.1-do.3"`        | Não         |
| `node_pool_name`        | Nome do node pool            | `string` | `"techpreta-nodepool"` | Não         |
| `node_pool_size`        | Tamanho dos nós              | `string` | `"s-2vcpu-2gb"`        | Não         |
| `node_pool_auto_scale`  | Habilitar auto-scaling       | `bool`   | `true`                 | Não         |
| `node_pool_min_nodes`   | Número mínimo de nós         | `number` | `3`                    | Não         |
| `node_pool_max_nodes`   | Número máximo de nós         | `number` | `5`                    | Não         |
| `write_kubeconfig`      | Salvar kubeconfig localmente | `bool`   | `true`                 | Não         |
| `do_pat`                | Token de acesso DigitalOcean | `string` | -                      | **Sim**     |
| `cloudflare_api_token`  | Token da API Cloudflare      | `string` | -                      | **Sim**     |
| `cloudflare_account_id` | ID da conta Cloudflare       | `string` | -                      | **Sim**     |
| `r2_access_key`         | Chave de acesso R2           | `string` | -                      | **Sim**     |
| `r2_access_secret`      | Segredo de acesso R2         | `string` | -                      | **Sim**     |

## Outputs

| Nome               | Descrição                     |
| ------------------ | ----------------------------- |
| `cluster_id`       | ID do cluster Kubernetes      |
| `cluster_name`     | Nome do cluster               |
| `cluster_endpoint` | Endpoint do cluster           |
| `cluster_status`   | Status do cluster             |
| `cluster_version`  | Versão do Kubernetes          |
| `node_pool_id`     | ID do node pool               |
| `kubeconfig_path`  | Caminho do arquivo kubeconfig |

## Credenciais Necessárias

### DigitalOcean
- **Personal Access Token**: Obtenha em [DigitalOcean > API](https://cloud.digitalocean.com/account/api/tokens)
- **Permissões**: Write (para criar recursos)

### Cloudflare R2
- **API Token**: Obtenha em [Cloudflare > My Profile > API Tokens](https://dash.cloudflare.com/profile/api-tokens)
- **R2 Access Key/Secret**: Obtenha em [Cloudflare > R2 > Manage R2 API tokens](https://dash.cloudflare.com/)

Consulte a [documentação completa](examples/docs/README.md) para instruções detalhadas.

## Verificação Pós-Deploy

Após a aplicação bem-sucedida:

```bash
# Use o kubeconfig gerado
export KUBECONFIG=./kubeconfig

# Verifique os nós do cluster
kubectl get nodes

# Verifique pods do sistema
kubectl get pods -A

# Informações do cluster
kubectl cluster-info
```

## Limpeza de Recursos

Para destruir todos os recursos criados:

```bash
terraform destroy
```

**⚠️ Atenção:** Isso removerá permanentemente o cluster e todos os recursos associados.

## Estrutura do Projeto

```
.
├── examples/                    # Exemplo de uso completo
│   ├── docs/                   # Documentação detalhada
│   ├── main.tf                 # Consumo do módulo
│   ├── variables.tf            # Variáveis do exemplo
│   ├── outputs.tf              # Outputs do exemplo
│   ├── versions.tf             # Providers e backend
│   └── terraform.tfvars.example # Exemplo de configuração
├── main.tf                     # Recursos principais do módulo
├── variables.tf                # Declaração de variáveis
├── outputs.tf                  # Outputs do módulo
├── versions.tf                 # Providers requeridos
├── kubeconfig.tf              # Configuração do kubeconfig
└── README.md                   # Esta documentação
```

## Segurança e Boas Práticas

- **Estado Remoto**: Utiliza Cloudflare R2 para armazenamento seguro do estado
- **Credenciais**: Nunca hardcode credenciais; use `terraform.tfvars` ou variáveis de ambiente
- **Kubeconfig**: Arquivo sensível, incluído no `.gitignore`
- **Análise de Segurança**: Workflows de CI/CD incluem scans de segurança automatizados

## Contribuição

Contribuições são bem-vindas! Veja nosso [guia de contribuição](CONTRIBUTING.md).

## Licença

Este projeto está licenciado sob a [Licença MIT](LICENSE).

## Contato

Para dúvidas ou reporte de vulnerabilidades, consulte o [SECURITY.md](SECURITY.md).

---

Feito com ❤️ por [Natália Granato](https://github.com/nataliagranato).
