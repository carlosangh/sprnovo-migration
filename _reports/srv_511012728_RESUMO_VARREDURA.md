# VARREDURA COMPLETA SPR SERVIDOR 511012728
**Data:** 2025-09-05  
**Servidor:** SPR-server (138.197.83.3)  
**Status:** CONCLUÍDA ✅

---

## 📋 RESUMO EXECUTIVO

### Informações do Servidor
- **Droplet ID:** 511012728
- **Nome:** SPR-server
- **IP:** 138.197.83.3
- **OS:** Ubuntu 22.04 LTS
- **Região:** New York 3 (nyc3)
- **Recursos:** 2 vCPUs, 4GB RAM, 80GB SSD
- **Uptime:** 3 dias, 22:35 (estável)

### Status Geral
🟢 **SISTEMA OPERACIONAL:** Funcionando normalmente  
🟡 **SERVIÇOS PM2:** 11 online, 4 parados, alta instabilidade em alguns  
🟢 **NGINX:** Ativo e configurado  
🟢 **BANCOS DE DADOS:** SQLite principal + PostgreSQL em containers  
🟢 **CRON JOBS:** 15 jobs ativos de ingestão e monitoramento  

---

## 🏗️ ARQUITETURA IDENTIFICADA

### Estrutura Principal
```
/opt/spr/                    # Diretório principal (52 subdiretórios)
├── data/                    # Bancos SQLite
├── frontend/                # Código React/TypeScript
├── _logs/                   # Logs do sistema
├── agents/                  # Sistema de agentes
├── monitoring/              # Monitoramento
├── backups/                 # Backups automáticos
├── clg-core/               # Sistema CLG integrado
└── [múltiplos scripts]     # Ingestão e processamento

/var/www/spr/               # Frontend compilado (web root)
```

### Serviços Ativos (PM2)
| Porta | Serviço | Status | Restarts | Crítico |
|-------|---------|--------|----------|---------|
| 3001  | spr-coordinator | 🟢 Online | 8 | ⭐ |
| 3002  | spr-backend-production | 🟢 Online | 141 | ⭐⭐⭐ |
| 3004  | spr-ai-commercial | 🟢 Online | 7 | ⭐ |
| 3005  | spr-analytics | 🟢 Online | 6 | ⭐ |
| 3006  | spr-automation | 🟢 Online | 7 | ⭐ |
| 3007  | spr-backend-agent | 🟢 Online | 5 | ⭐ |
| 3008  | spr-typescript-pro | 🟢 Online | 5 | ⭐ |
| 3010  | spr-real-data | 🟢 Online | 2369 | ⭐⭐ |
| 8002  | clg-core | 🟢 Online | 5 | ⭐ |

---

## 🗄️ BANCOS DE DADOS

### SQLite Principal (`/opt/spr/data/spr_central.db`)
**Tabelas identificadas:**
- `usuarios` - Sistema de autenticação
- `whatsapp_sessoes` - Sessões WhatsApp
- `whatsapp_conversas` - Histórico de mensagens
- `dados_mercado` - Dados de commodities
- `pulso_analises` - Análises do Pulso IA
- `logs_sistema` - Logs estruturados
- `agentes_mensagens` - Comunicação entre agentes
- `agentes_status` - Status dos agentes
- **1380 linhas de schema total**

### PostgreSQL (Docker)
- Container: `spr-postgres` (porta 5432)
- Container: `evolution_postgres` (Evolution API)
- Status: Containers ativos, acesso a investigar

### Outros Bancos
- `typescript_pro.db` - Dados TypeScript
- `clg.db` - Sistema CLG
- `roy_atendimentos.db` - Sistema Roy Assistant
- Múltiplos backups automáticos

---

## 🔄 INGESTÃO DE DADOS (CRON)

### Fontes Ativas
| Fonte | Frequência | Horário | Status |
|-------|-----------|---------|--------|
| CEPEA | 10 min | 8h-18h, seg-sex | 🟢 |
| IMEA | 1 hora | 8h-18h, seg-sex | 🟢 |
| B3 | 15 min | 9h-18h, seg-sex | 🟢 |
| CME | 30 min | 9h-23h, seg-sex | 🟢 |
| News | 1 hora | 24/7 | 🟢 |
| INMET | 3 horas | 24/7 | 🟢 |
| USDM | Diário | 3:00 AM | 🟢 |
| US Crop | Semanal | Segunda 4:00 AM | 🟢 |

### Monitoramento
- Health check: A cada 5 minutos
- System monitor: A cada 5 minutos  
- Backup SPR: Diário 2:10 AM
- Backup CLG: Diário 2:30 AM
- Log cleanup: Diário 00:00 (retenção 30 dias)

---

## 🌐 INFRAESTRUTURA WEB

### Nginx
- **Porta 80:** HTTP principal
- **Porta 443:** HTTPS (royalnegociosagricolas.com.br)  
- **Porta 8090:** Interface administrativa
- **SSL:** Let's Encrypt ativo
- **Configurações:** Múltiplas configs, alguns conflitos

### Frontend (React SPA)
- **Localização:** `/var/www/spr/`
- **Build:** Compilado e otimizado
- **Rotas:** Dashboard, Market Calls, Sentiment Analysis, etc.
- **Assets:** ~11MB total

---

## ⚠️ PROBLEMAS IDENTIFICADOS

### 🔴 CRÍTICO - Instabilidade Alta
1. **spr-real-data:** 2369 restarts (MUITO ALTO)
2. **spr-whatsapp-agent:** 605 restarts 
3. **spr-backend-production:** 141 restarts (serviço principal)

### 🟡 ATENÇÃO - Configuração
1. **Nginx:** Server names conflitantes
2. **PM2:** 4 processos parados (spr-backend-*)
3. **PostgreSQL:** Acesso não configurado corretamente
4. **Múltiplos .env:** Configurações espalhadas

### 🟢 FUNCIONANDO BEM
1. **Sistema operacional:** Estável, uptime alto
2. **Ingestão de dados:** Todos os cron jobs ativos
3. **Backup:** Funcionando diariamente
4. **SSL/HTTPS:** Configurado e válido
5. **Monitoramento:** Health checks ativos

---

## 📊 CÓDIGO FONTE MAPEADO

### Python
- **Arquivos principais:** 10+ arquivos .py
- **Serviço principal:** `spr_backend_complete_fixed.py`
- **Backups e versões:** Múltiplas versões preservadas

### JavaScript/Node.js  
- **Arquivos:** 80+ scripts .js
- **Principais:** Ingestão, agentes, APIs, webhooks
- **Modularização:** Bem estruturado por domínio

### TypeScript
- **Frontend:** Código React/TS no /opt/spr/frontend/
- **Tipos:** Definições de contratos e interfaces

### Configurações
- **Nginx:** 15+ arquivos de configuração
- **PM2:** ecosystem.config.js para orquestração
- **Docker:** Containers para PostgreSQL e Redis
- **Environment:** Múltiplos .env por ambiente

---

## 📁 ARQUIVOS GERADOS

Todos os relatórios foram salvos em `/home/cadu/SPRNOVO/_reports/`:

✅ `srv_511012728_tree.txt` - Estrutura completa de diretórios  
✅ `srv_511012728_pm2.json` - Configurações e status PM2  
✅ `srv_511012728_nginx.conf` - Configuração Nginx  
✅ `srv_511012728_routes.txt` - Mapeamento de rotas e portas  
✅ `srv_511012728_cron.txt` - Jobs agendados e ingestão  
✅ `srv_511012728_database_schema.sql` - Schema completo SQLite  
✅ `srv_511012728_python_files.txt` - Catálogo arquivos Python  
✅ `srv_511012728_js_files.txt` - Catálogo arquivos JavaScript  
✅ `srv_511012728_RESUMO_VARREDURA.md` - Este resumo

---

## 🎯 PRÓXIMOS PASSOS RECOMENDADOS

### URGENTE (1-3 dias)
1. **Investigar instabilidade** do spr-real-data (2369 restarts)
2. **Diagnosticar** spr-whatsapp-agent (605 restarts)  
3. **Consolidar configurações** Nginx (eliminar conflitos)
4. **Configurar acesso** PostgreSQL adequadamente

### IMPORTANTE (1 semana)
1. **Limpeza** de processos PM2 parados
2. **Consolidação** de arquivos .env
3. **Documentação** da arquitetura de agentes
4. **Teste** de continuidade dos backups

### MELHORIAS (1 mês)
1. **Monitoramento** avançado (alertas por email/Slack)
2. **Otimização** de recursos (análise de memória)
3. **Disaster recovery** plan
4. **Load balancing** para alta disponibilidade

---

**Varredura executada com sucesso!** 🎉  
Todas as informações críticas do SPR em produção foram mapeadas e documentadas.