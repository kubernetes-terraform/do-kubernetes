# Documentação do Kubernetes DigitalOcean

Esta documentação fornece informações abrangentes sobre as configurações de upgrade de clusters Kubernetes na DigitalOcean usando Terraform.

## 📋 Índice da Documentação

### 📚 Guias Principais
- [**Upgrades do Kubernetes**](kubernetes-upgrades.md) - Documentação completa sobre configurações de upgrade
- [**Guia de Configuração**](configuration-guide.md) - Como configurar as variáveis no Terraform
- [**FAQ**](faq.md) - Perguntas frequentes e soluções de problemas

### 💡 Exemplos Práticos
- [**Desenvolvimento**](examples/development.md) - Configuração para ambiente de desenvolvimento
- [**Staging**](examples/staging.md) - Configuração para ambiente de staging/homologação
- [**Produção**](examples/production.md) - Configuração para ambiente de produção

## 🚀 Início Rápido

Se você está começando agora, recomendamos seguir esta ordem:

1. 📖 Leia a [documentação principal sobre upgrades](kubernetes-upgrades.md)
2. ⚙️ Consulte o [guia de configuração](configuration-guide.md)
3. 🔍 Veja os [exemplos práticos](examples/) para seu ambiente
4. ❓ Se tiver dúvidas, consulte o [FAQ](faq.md)

## 🎯 Configurações Principais

Este projeto foca nas seguintes configurações de upgrade do Kubernetes na DigitalOcean:

### `auto_upgrade`
Habilita atualizações automáticas do control plane do cluster Kubernetes.

### `surge_upgrade` 
Permite atualizações de nodes com zero downtime através de nodes temporários.

## 📝 Como Contribuir

Para contribuir com esta documentação:

1. Verifique se existe uma issue relacionada ao que você quer melhorar
2. Faça um fork do repositório
3. Crie uma branch com suas alterações
4. Envie um pull request com uma descrição clara das mudanças

## 🆘 Suporte

- 📋 Para bugs e melhorias: [Abra uma issue](../../../issues)
- 💬 Para dúvidas gerais: Consulte o [FAQ](faq.md)
- 🔒 Para questões de segurança: Veja [SECURITY.md](../SECURITY.md)

---

**Última atualização:** {{current_date}}  
**Versão da documentação:** 1.0.0