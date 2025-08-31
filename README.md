# Kubernetes DigitalOcean - Terraform Template

Este repositório fornece configurações Terraform seguras e bem documentadas para clusters Kubernetes na DigitalOcean, com foco especial em configurações de upgrade (`auto_upgrade` e `surge_upgrade`).

## Funcionalidades

- **Pipeline CI/CD seguro** com validações automáticas
- **Análise de segurança de código e dependências**
- **Política de permissões mínimas no GitHub Actions**
- **Configurações de upgrade otimizadas** para diferentes ambientes
- **Documentação abrangente** sobre upgrades do Kubernetes
- **Exemplos práticos** para desenvolvimento, staging e produção

## Documentação de Upgrades Kubernetes

### 📚 Guias Principais
- [**Configurações de Upgrade do Kubernetes**](docs/kubernetes-upgrades.md) - Documentação completa sobre `auto_upgrade` e `surge_upgrade`
- [**Guia de Configuração**](docs/configuration-guide.md) - Como configurar variáveis Terraform para diferentes cenários
- [**FAQ**](docs/faq.md) - Perguntas frequentes e soluções de problemas

### 💡 Exemplos Práticos
- [**Desenvolvimento**](docs/examples/development.md) - Configuração otimizada para economia e agilidade
- [**Staging**](docs/examples/staging.md) - Ambiente intermediário para testes
- [**Produção**](docs/examples/production.md) - Configuração robusta para ambientes críticos

### 🎯 Configurações Principais

#### `auto_upgrade`
Habilita atualizações automáticas do control plane do cluster Kubernetes.
- ✅ **Desenvolvimento**: Sempre habilitado para ter versões atualizadas
- ✅ **Staging**: Habilitado para testar antes da produção  
- ⚠️ **Produção**: Controlado manualmente para máxima estabilidade

#### `surge_upgrade`
Permite atualizações de nodes com zero downtime através de nodes temporários.
- ❌ **Desenvolvimento**: Desabilitado para economia de custos
- ✅ **Staging**: Habilitado para simular produção
- ✅ **Produção**: Sempre habilitado para zero downtime crítico


## Workflows e Soluções de Segurança
### 1. Terraform Format, Validate, and Test
- **Função:** Formata, valida e executa testes em código Terraform a cada push ou pull request.
- **Segurança:** Utiliza o bloco `permissions` para garantir acesso mínimo (`contents: read`).

### 2. Checkov Security Scan
- **Arquivo:** `.github/workflows/checkov.yml`
- **Função:** Executa o [Checkov](https://www.checkov.io/) para análise estática de segurança em código IaC (Infrastructure as Code), gerando relatórios SARIF.
- **Segurança:** Detecta más práticas, configurações inseguras e vulnerabilidades em arquivos Terraform.

### 3. Trivy SBOM & Vulnerability Scan
- **Arquivo:** `.github/workflows/trivy.yml`
- **Função:** Gera SBOM (Software Bill of Materials) e faz varredura de vulnerabilidades em dependências e imagens, integrando resultados ao GitHub Dependency Graph.
- **Segurança:** Ajuda a identificar componentes vulneráveis presentes no projeto.

### 4. Scorecard Supply-chain Security
- **Arquivo:** `.github/workflows/scorecard.yml`
- **Função:** Usa o [OSSF Scorecard](https://github.com/ossf/scorecard) para avaliar práticas de segurança da cadeia de suprimentos do repositório.
- **Segurança:** Analisa branch protection, dependabot, workflows, tokens, entre outros.

### 5. OSV-Scanner
- **Arquivo:** `.github/workflows/osv-scanner.yml`
- **Função:** Executa o [OSV-Scanner](https://osv.dev/) para identificar vulnerabilidades conhecidas em dependências.
- **Segurança:** Automatiza a checagem contínua de vulnerabilidades em bibliotecas e módulos.

### 6. Dependency Review
- **Arquivo:** `.github/workflows/dependency-review.yml`
- **Função:** Bloqueia PRs que introduzem dependências vulneráveis conhecidas, usando o GitHub Dependency Review Action.
- **Segurança:** Garante que novas dependências estejam livres de vulnerabilidades conhecidas.

### 7. CodeQL Analysis (opcional)
- **Arquivo:** (não incluído por padrão)
- **Função:** Executa análise estática de segurança aprofundada com CodeQL para identificar vulnerabilidades no código.
- **Segurança:** Detecta padrões de código problemáticos que podem levar a vulnerabilidades, com base em queries mantidas pela comunidade e pelo GitHub.
- **Observação:** O uso do CodeQL é recomendado e está documentado em [SECURITY.md](SECURITY.md), mas o workflow não está incluído por padrão neste template. Para habilitar, utilize a opção "Configure CodeQL" na aba "Security" do GitHub ou adicione manualmente o workflow sugerido pela plataforma.

## Outras Práticas de Segurança

- **Dependabot:** Atualizações automáticas de dependências.
- **Política de Segurança:** Veja [SECURITY.md](SECURITY.md) para detalhes sobre reporte de vulnerabilidades e práticas adotadas.
- **Code of Conduct:** Ambiente colaborativo e respeitoso ([CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)).

## Como usar este template

### 🚀 Início Rápido

1. **Consulte a documentação**: Comece lendo a [documentação completa](docs/README.md)
2. **Escolha sua configuração**: Use os exemplos para [desenvolvimento](docs/examples/development.md), [staging](docs/examples/staging.md) ou [produção](docs/examples/production.md)
3. **Configure as variáveis**: Siga o [guia de configuração](docs/configuration-guide.md)
4. **Deploy com segurança**: Aplique as configurações em seu ambiente

### 📋 Template Usage

1. Clique em `Use this template` no GitHub.
2. Siga as instruções para criar seu novo repositório.
3. Adapte os workflows conforme as necessidades do seu projeto.
4. Configure as variáveis de upgrade conforme sua estratégia.

## Contato

Para dúvidas ou reporte de vulnerabilidades, consulte o [SECURITY.md](SECURITY.md).

---

Feito com ❤️ por [Natália Granato](https://github.com/nataliagranato).
