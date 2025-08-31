## Configuração de Credenciais

O backend do projeto utiliza o R2 da Cloudflare para armazenamento de estado remoto. As credenciais podem ser configuradas de duas formas:

### Opção 1: Arquivo terraform.tfvars (Recomendado)

Configure suas credenciais diretamente no arquivo `terraform.tfvars`:

```hcl
# Credenciais DigitalOcean
do_pat = "dop_v1_seu_token_digitalocean"

# Credenciais Cloudflare R2
cloudflare_api_token  = "seu_token_cloudflare"
cloudflare_account_id = "seu_account_id_cloudflare"
r2_access_key         = "sua_chave_de_acesso_r2"
r2_access_secret      = "seu_segredo_de_acesso_r2"

# Configurações do cluster (opcionais)
cluster_name = "meu-cluster"
region       = "nyc1"
```

### Opção 2: Variáveis de ambiente

Alternativamente, você pode usar variáveis de ambiente:

```bash
export DIGITALOCEAN_TOKEN=<seu-token-digitalocean>
export CLOUDFLARE_API_TOKEN=<seu-token-cloudflare>
export CLOUDFLARE_ACCOUNT_ID=<seu-id-da-conta-cloudflare>
```

**Nota:** O backend R2 utiliza a API S3 da Cloudflare: `https://4839c9636a58fa9490bbe3d2e686ad98.r2.cloudflarestorage.com/nataliagranato`.


### Obtendo as credenciais necessárias

#### DigitalOcean Personal Access Token

Para obter seu token de acesso pessoal da DigitalOcean:

1. Acesse o [painel da DigitalOcean](https://cloud.digitalocean.com/)
2. Vá para **API** no menu lateral
3. Clique em **Generate New Token**
4. Dê um nome ao token e selecione **Write** scope
5. Copie o token gerado (começará com `dop_v1_`)

#### Cloudflare API Token

Para obter o seu token da API Cloudflare, siga estas etapas:

1. Acesse o [painel da Cloudflare](https://dash.cloudflare.com/)
2. No seu perfil clique em **API Tokens**
3. Crie um novo token com as permissões: **Conta.Armazenamento R2 do Workers**

#### Credenciais R2 (Cloudflare)

`r2_access_key` e `r2_access_secret` podem ser obtidos criando **Tokens de API da Conta** em:
https://dash.cloudflare.com/4839c9636a58fa9490bbe3d2e686ad98/r2/api-tokens

Selecione a permissão `Permite a capacidade de ler, gravar e listar objetos em buckets específicos` e `Todos os buckets R2 nesta conta` ou se preferir pode segmentar por bucket as credenciais.

Ao criar será exibido o valor do token, o id da chave de acesso, a chave de acesso secreta e o endpoint s3 da sua conta.

### Como usar

1. **Configure o arquivo terraform.tfvars** com suas credenciais
2. **Execute os comandos Terraform:**

```bash
# Navegue para a pasta de exemplos
cd examples/

# Inicialize o Terraform
terraform init

# Verifique o plano
terraform plan

# Aplique a configuração
terraform apply
```

### Solução de problemas

#### Erro de autenticação DigitalOcean (401)

Se você receber um erro como `Unable to authenticate you`, verifique:

1. Se o token `do_pat` está correto no `terraform.tfvars`
2. Se o token tem permissões de **Write**
3. Se o token não expirou

#### Erro de autenticação Cloudflare

1. Verifique se o `cloudflare_api_token` está correto
2. Confirme se o token tem as permissões necessárias para R2

### Verificação pós-deploy

Após a aplicação bem-sucedida do Terraform:

1. **Kubeconfig será salvo** em `./kubeconfig`
2. **Teste a conexão com o cluster:**

```bash
# Use o kubeconfig gerado
export KUBECONFIG=./kubeconfig

# Verifique os nós do cluster
kubectl get nodes

# Verifique a versão do Kubernetes
kubectl version
```

3. **Recursos criados:**
   - Cluster Kubernetes na DigitalOcean (região nyc1)
   - Node pool com auto-scaling (3-5 nós)
   - Arquivo kubeconfig local para acesso ao cluster

### Limpeza

Para destruir os recursos criados:

```bash
terraform destroy
```

**⚠️ Atenção:** Isso irá remover permanentemente o cluster e todos os recursos associados.
