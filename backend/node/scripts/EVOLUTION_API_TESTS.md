# 🚀 Testes Evolution API - Documentação Completa

## 📋 Visão Geral

Esta documentação descreve a infraestrutura completa de testes para a integração WhatsApp Evolution API no sistema SPR Backend.

### ✅ Scripts Disponíveis

| Script | Função | Uso |
|--------|--------|-----|
| `evo_test.sh` | Testes principais Evolution API | `./scripts/evo_test.sh <comando>` |
| `monitor_dashboard.sh` | Dashboard de monitoramento | `./scripts/monitor_dashboard.sh` |
| `setup_evolution_env.sh` | Configuração do ambiente | `./scripts/setup_evolution_env.sh <comando>` |

---

## 🧪 Script Principal: evo_test.sh

### Comandos Disponíveis

```bash
# Verificar pré-requisitos
./scripts/evo_test.sh check

# Testar health checks
./scripts/evo_test.sh health  

# Criar instância WhatsApp
./scripts/evo_test.sh create [nome_instancia]

# Obter QR Code para conexão
./scripts/evo_test.sh qr [nome_instancia]

# Conectar instância (mostra QR)
./scripts/evo_test.sh connect [nome_instancia]

# Enviar mensagem teste
./scripts/evo_test.sh send [instancia] [numero] [mensagem]

# Monitoramento em tempo real
./scripts/evo_test.sh monitor

# Suite completa de testes
./scripts/evo_test.sh test
```

### Exemplos Práticos

```bash
# 1. Verificar se tudo está funcionando
./scripts/evo_test.sh check

# 2. Criar nova instância
./scripts/evo_test.sh create minha_empresa

# 3. Obter QR Code para conectar
./scripts/evo_test.sh qr minha_empresa

# 4. Enviar mensagem teste
./scripts/evo_test.sh send minha_empresa +5511999887766 "Olá! Teste da API"

# 5. Executar todos os testes
./scripts/evo_test.sh test
```

### Saídas Esperadas

#### ✅ Teste com Sucesso
```
[STEP] Verificando pré-requisitos
[SUCCESS] Backend SPR está disponível
[SUCCESS] Evolution API está disponível
[SUCCESS] Pré-requisitos verificados

[STEP] Testando health checks
[SUCCESS] Backend health: ok
[SUCCESS] WhatsApp health: service=whatsapp, ok=true
[SUCCESS] Health checks completados
```

#### ❌ Problemas Comuns
```
[ERROR] Backend SPR não está disponível em http://localhost:3002
[INFO] Execute: node spr-backend-complete.js

[ERROR] Evolution API não está disponível em http://localhost:8080
[WARNING] Alguns testes serão limitados
```

---

## 📊 Dashboard de Monitoramento

O `monitor_dashboard.sh` fornece uma visão em tempo real de todos os serviços.

### Como Usar
```bash
./scripts/monitor_dashboard.sh
```

### Informações Exibidas
- ✅ Status dos serviços principais
- ⏱️ Uptime do backend
- 📱 Contagem de instâncias WhatsApp
- 💻 Métricas do sistema (CPU, RAM, Disco)
- 🔗 Status dos endpoints
- 📝 Atividade recente

### Exemplo de Saída
```
╔══════════════════════════════════════════════════════════════╗
║               🚀 SPR MONITORING DASHBOARD                    ║
╚══════════════════════════════════════════════════════════════╝

SERVIÇOS PRINCIPAIS:
  Backend SPR:         🟢 ONLINE
  Evolution API:       🟢 ONLINE  
  WhatsApp Service:    🟢 ONLINE

MÉTRICAS:
  Backend Uptime:      2h 45m
  Instâncias WA:       3 instâncias
  Sistema:             CPU: 15.2% | RAM: 68.1% | Disco: 45%

ENDPOINTS:
  /health                    🟢 ONLINE
  /api/status               🟢 ONLINE
  /api/offers               🟢 ONLINE
  /api/whatsapp/health      🟢 ONLINE
```

---

## ⚙️ Configuração do Ambiente

O script `setup_evolution_env.sh` automatiza a configuração inicial.

### Comandos Disponíveis
```bash
# Configuração inicial completa
./scripts/setup_evolution_env.sh init

# Configurar apenas Evolution API
./scripts/setup_evolution_env.sh config

# Testar configurações
./scripts/setup_evolution_env.sh test

# Mostrar configurações atuais
./scripts/setup_evolution_env.sh show

# Recriar arquivo .env
./scripts/setup_evolution_env.sh reset
```

### Configuração Inicial
```bash
./scripts/setup_evolution_env.sh init
```

O script irá:
1. ✅ Criar arquivo `.env` com configurações padrão
2. ✅ Solicitar URL e API Key da Evolution API
3. ✅ Criar scripts auxiliares
4. ✅ Testar todas as configurações
5. ✅ Mostrar resumo final

### Arquivo .env Gerado
```bash
# EVOLUTION API - WHATSAPP
EVO_URL=http://localhost:8080
EVOLUTION_API_URL=http://localhost:8080
EVO_APIKEY=sua-api-key-aqui
EVOLUTION_API_KEY=sua-api-key-aqui
EVO_WEBHOOK_TOKEN=seu-webhook-token
EVOLUTION_WEBHOOK_TOKEN=seu-webhook-token

# SPR BACKEND
PORT=3002
NODE_ENV=development
SPR_MTR_SERVICE_URL=http://localhost:3001/mtr/detect
```

---

## 🔧 Pré-requisitos

### Software Necessário
- ✅ `curl` - Para requisições HTTP
- ✅ `bash` - Shell script execution
- ⚠️ `jq` - Para parsing JSON (opcional, script funciona sem)

### Serviços Necessários
- ✅ **Backend SPR** rodando em `localhost:3002`
- ✅ **Evolution API** configurada (URL e API Key)
- ⚠️ **Evolution API Server** rodando (opcional para alguns testes)

### Verificação Rápida
```bash
# Verificar se backend está rodando
curl http://localhost:3002/health

# Verificar se Evolution API está acessível  
curl http://localhost:8080

# Executar verificação completa
./scripts/evo_test.sh check
```

---

## 📱 Fluxo de Teste Completo

### 1. Preparação do Ambiente
```bash
# 1.1. Configurar ambiente (primeira vez)
./scripts/setup_evolution_env.sh init

# 1.2. Verificar pré-requisitos
./scripts/evo_test.sh check
```

### 2. Testes de Conectividade
```bash
# 2.1. Testar health checks
./scripts/evo_test.sh health

# 2.2. Executar suite completa
./scripts/evo_test.sh test
```

### 3. Criação e Teste de Instância
```bash
# 3.1. Criar nova instância
./scripts/evo_test.sh create teste_spr

# 3.2. Obter QR Code
./scripts/evo_test.sh qr teste_spr

# 3.3. Conectar WhatsApp (escaneie o QR Code)
# Aguardar conexão ser estabelecida

# 3.4. Enviar mensagem teste
./scripts/evo_test.sh send teste_spr +5511999887766 "🤖 Teste SPR Evolution API"
```

### 4. Monitoramento Contínuo
```bash
# Dashboard em tempo real
./scripts/monitor_dashboard.sh
```

---

## 🐛 Diagnóstico e Resolução de Problemas

### Problema: Backend não está disponível
```bash
[ERROR] Backend SPR não está disponível em http://localhost:3002
```

**Solução:**
```bash
# Verificar se o processo está rodando
ps aux | grep node

# Iniciar backend se necessário
node spr-backend-complete.js
```

### Problema: Evolution API não configurada
```bash
[WARNING] Evolution API não está disponível em http://localhost:8080
```

**Solução:**
```bash
# 1. Verificar configuração
./scripts/setup_evolution_env.sh show

# 2. Reconfigurar se necessário
./scripts/setup_evolution_env.sh config

# 3. Testar nova configuração
./scripts/setup_evolution_env.sh test
```

### Problema: Falha na criação de instância
```bash
[ERROR] Falha ao criar instância 'minha_instancia'
```

**Possíveis causas:**
1. ❌ API Key inválida
2. ❌ Evolution API não está rodando
3. ❌ Nome da instância já existe

**Soluções:**
```bash
# Verificar logs detalhados
curl -v -X POST http://localhost:3002/api/whatsapp/instance \
  -H "Content-Type: application/json" \
  -d '{"instanceName":"teste_debug"}'

# Verificar Evolution API diretamente
curl -H "apikey: $EVO_APIKEY" http://localhost:8080/instance/fetchInstances
```

### Problema: Mensagem não é enviada
```bash
[ERROR] Falha ao enviar mensagem
```

**Verificações:**
1. ✅ Instância está conectada ao WhatsApp?
2. ✅ Número está no formato correto? (+5511999887766)
3. ✅ WhatsApp Web está funcionando na instância?

---

## 📈 Métricas e Monitoramento

### Health Check Endpoints

| Endpoint | Função | Resposta Esperada |
|----------|--------|-------------------|
| `/health` | Status geral do backend | `{"status": "ok"}` |
| `/api/whatsapp/health` | Status do WhatsApp service | `{"ok": true, "service": "whatsapp"}` |
| `/api/status` | Métricas detalhadas | Status completo dos serviços |

### Códigos de Status HTTP

| Código | Significado | Ação |
|--------|-------------|------|
| 200 | ✅ Sucesso | Continuar operação |
| 400 | ❌ Erro de requisição | Verificar parâmetros |
| 401 | ❌ Não autorizado | Verificar API Key |
| 500 | ❌ Erro interno | Verificar logs do servidor |
| Timeout | ❌ Sem resposta | Verificar conectividade |

---

## 🔄 Integração Contínua

### Testes Automatizados
```bash
#!/bin/bash
# Script para CI/CD

# 1. Verificar ambiente
./scripts/evo_test.sh check || exit 1

# 2. Executar testes
./scripts/evo_test.sh health || exit 1

# 3. Testar criação de instância (se Evolution API disponível)
if [ -n "$EVO_APIKEY" ]; then
    ./scripts/evo_test.sh create ci_test_$(date +%s)
fi

echo "✅ Todos os testes passaram"
```

### Monitoramento em Produção
```bash
# Cron job para monitoramento (executar a cada 5 minutos)
*/5 * * * * /path/to/scripts/evo_test.sh health >> /var/log/spr-health.log 2>&1
```

---

## 📚 Referências Técnicas

### Estrutura de Resposta da API
```json
{
  "success": true,
  "data": {
    "instanceName": "minha_instancia",
    "qrcode": "data:image/png;base64,..."
  },
  "timestamp": "2025-09-05T18:53:00.000Z"
}
```

### Variáveis de Ambiente
```bash
# URLs
BACKEND_URL=http://localhost:3002    # URL do backend SPR
EVO_URL=http://localhost:8080        # URL da Evolution API

# Autenticação
EVO_APIKEY=sua-api-key-aqui         # API Key da Evolution API
EVO_WEBHOOK_TOKEN=webhook-token      # Token para webhooks

# Configurações de teste
DEFAULT_INSTANCE=spr_test_instance   # Nome padrão para instância
DEFAULT_TEST_NUMBER=+5511999887766   # Número para testes
```

---

## ✨ Próximos Passos

### Melhorias Planejadas
- [ ] Suporte a múltiplas instâncias simultâneas
- [ ] Dashboard web em tempo real  
- [ ] Integração com Grafana/Prometheus
- [ ] Testes automatizados de regressão
- [ ] Notificações por email/Slack em falhas

### Comandos Avançados (Em Desenvolvimento)
```bash
# Backup e restore de instâncias
./scripts/evo_test.sh backup [instancia]
./scripts/evo_test.sh restore [instancia]

# Métricas detalhadas
./scripts/evo_test.sh metrics

# Limpeza de instâncias antigas
./scripts/evo_test.sh cleanup
```

---

## 📞 Suporte

Para problemas ou dúvidas:

1. 🔍 Verificar esta documentação
2. 🧪 Executar `./scripts/evo_test.sh test` para diagnóstico
3. 📊 Usar `./scripts/monitor_dashboard.sh` para monitoramento
4. 📝 Verificar logs em `/tmp/spr_*.log`

---

**✅ Infraestrutura de testes Evolution API configurada e pronta para uso!**