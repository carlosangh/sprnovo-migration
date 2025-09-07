# SPRNOVO - Deployment Guide

Sistema Preditivo Royal - Nova Geração
Data de Deploy: 2025-01-07

## 🔄 Migração Completa

Este documento descreve a migração completa do antigo SPR para o novo ambiente SPRNOVO com Docker Compose.

### 📋 Resumo da Migração

- ✅ **Serviços antigos removidos** (preservando banco de dados)
- ✅ **Banco de dados legado mantido** como único repositório
- ✅ **Novo ambiente containerizado** com Docker Compose
- ✅ **n8n configurado** para automação (EXECUTIONS_MODE=queue)
- ✅ **SSL/TLS** com LetsEncrypt
- ✅ **Backup automatizado** para DigitalOcean Spaces

## 🏗️ Arquitetura Nova

```
┌─ SPRNOVO Environment ─────────────────────────┐
│                                               │
│ ┌──────────────┐  ┌──────────────┐            │
│ │  PostgreSQL  │  │    Redis     │            │
│ │   (Legacy)   │  │   (Cache)    │            │
│ └──────────────┘  └──────────────┘            │
│                                               │
│ ┌──────────────┐  ┌──────────────┐            │
│ │   Backend    │  │  Frontend    │            │
│ │  (Node.js)   │  │   (Nginx)    │            │
│ └──────────────┘  └──────────────┘            │
│                                               │
│ ┌──────────────┐  ┌──────────────┐            │
│ │ Evolution API│  │     n8n      │            │
│ │ (WhatsApp)   │  │ (Automation) │            │
│ └──────────────┘  └──────────────┘            │
│                                               │
└───────────────────────────────────────────────┘

External:
┌─────────────────────────────────────────────┐
│ Nginx + SSL (Host)                          │
│ ├─ automation.royalnegociosagricolas.com.br │
│ └─ → n8n Container (Port 5678)              │
└─────────────────────────────────────────────┘
```

## 🚀 Instruções de Deploy

### 1. Preparação

```bash
cd /home/cadu/SPRNOVO

# Verificar arquivos necessários
ls -la docker-compose.yml .env
ls -la scripts/
```

### 2. Deploy Completo (Automático)

```bash
# Execute o script de deploy completo
./scripts/deploy-sprnovo.sh
```

### 3. Deploy Manual (Passo a Passo)

Se preferir fazer manualmente:

```bash
# Parar containers antigos
docker stop $(docker ps -q) 2>/dev/null || true

# Fazer backup do banco atual
docker exec spr-postgres pg_dumpall -U spr_user > /tmp/backup_$(date +%Y%m%d).sql

# Iniciar novo ambiente
docker-compose up -d

# Verificar serviços
docker-compose ps

# Restaurar dados (se necessário)
docker-compose exec -T postgres psql -U spr_user -d spr_db < /tmp/backup_$(date +%Y%m%d).sql
```

## 🌐 Configuração de DNS e SSL

### 1. DNS Configuration

Configure o DNS do domínio `automation.royalnegociosagricolas.com.br` para apontar para este servidor:

```
A automation.royalnegociosagricolas.com.br → [IP_DO_SERVIDOR]
```

### 2. SSL Setup

Após configurar o DNS, execute:

```bash
sudo ./scripts/setup-nginx-ssl.sh
```

## 🔧 Serviços e Portas

| Serviço | Porta | URL | Descrição |
|---------|-------|-----|-----------|
| PostgreSQL | 5432 | localhost:5432 | Banco de dados legado |
| Redis | 6379 | localhost:6379 | Cache e filas |
| Backend | 8090 | localhost:8090 | API SPRNOVO |
| Frontend | 8082 | localhost:8082 | Interface WhatsApp |
| Evolution API | 8080 | localhost:8080 | WhatsApp Gateway |
| n8n | 5678 | https://automation.royalnegociosagricolas.com.br | Automação |

## 🔐 Credenciais

### n8n Automation Platform
- **URL**: https://automation.royalnegociosagricolas.com.br
- **Usuário**: admin
- **Senha**: spr_n8n_2025_admin

### Banco de Dados
- **Host**: postgres (internal) / localhost (external)
- **Database**: spr_db
- **User**: spr_user
- **Password**: spr_password_2025

### Evolution API
- **URL**: http://localhost:8080
- **API Key**: spr-evolution-key-2025

## 📦 Backup Automático

### Configuração Rclone (DigitalOcean Spaces)

1. **Instalar Rclone**:
```bash
curl https://rclone.org/install.sh | sudo bash
```

2. **Configurar Rclone**:
```bash
rclone config
# Escolher: DigitalOcean Spaces
# Nome: digitalocean
# Endpoint: nyc3.digitaloceanspaces.com
# Access Key: [SUA_ACCESS_KEY]
# Secret Key: [SUA_SECRET_KEY]
```

3. **Testar Backup**:
```bash
./scripts/backup-daily.sh
```

### Backup Automático Diário

O backup está configurado para rodar automaticamente às 2:00 AM através do cron:

```bash
# Ver crontab
crontab -l

# Logs de backup
tail -f logs/backup.log
```

### O que é Backupado

- **Banco PostgreSQL completo** (schema + dados)
- **Volume n8n_data** (workflows, credenciais, configurações)
- **Metadata de backup** (sumário, tamanhos, status)

### Retenção

- **Local**: 7 dias
- **DigitalOcean Spaces**: 30 dias

## 🔍 Verificação e Monitoramento

### Health Checks

```bash
# Todos os serviços
docker-compose ps

# Backend SPR
curl http://localhost:8090/health

# n8n
curl http://localhost:5678

# Evolution API
curl http://localhost:8080

# PostgreSQL
docker-compose exec postgres pg_isready -U spr_user -d spr_db
```

### Logs

```bash
# Todos os serviços
docker-compose logs -f

# Serviço específico
docker-compose logs -f n8n
docker-compose logs -f backend
docker-compose logs -f evolution-api

# Logs do sistema
tail -f /var/log/nginx/automation.royalnegociosagricolas.com.br.access.log
tail -f /var/log/nginx/automation.royalnegociosagricolas.com.br.error.log
```

## 🔧 Comandos Úteis

### Docker Compose

```bash
# Iniciar todos os serviços
docker-compose up -d

# Parar todos os serviços
docker-compose down

# Rebuild e restart
docker-compose down
docker-compose build --no-cache
docker-compose up -d

# Ver recursos utilizados
docker stats
```

### Manutenção

```bash
# Limpar containers antigos
docker system prune -a

# Backup manual
./scripts/backup-daily.sh

# Verificar espaço em disco
df -h
docker system df
```

### n8n Management

```bash
# Acessar container n8n
docker-compose exec n8n bash

# Resetar senha admin (se necessário)
docker-compose exec n8n n8n user-management:reset --email=admin@royalnegociosagricolas.com.br --password=nova_senha_2025
```

## 🚨 Troubleshooting

### Problemas Comuns

1. **Serviço não inicia**: Verificar logs e dependências
2. **SSL não funciona**: Verificar DNS e executar setup-nginx-ssl.sh
3. **Backup falha**: Verificar configuração do rclone
4. **n8n não conecta ao banco**: Verificar variáveis de ambiente

### Restauração de Backup

Se precisar restaurar backup:

```bash
# Parar serviços
docker-compose down

# Restaurar banco (exemplo)
rclone copy digitalocean:spr-backups-2025/2025/01/07/spr_database_*.sql.gz ./
gunzip spr_database_*.sql.gz
docker-compose up postgres -d
sleep 10
docker-compose exec -T postgres psql -U spr_user -d spr_db < spr_database_*.sql

# Restaurar n8n
rclone copy digitalocean:spr-backups-2025/2025/01/07/n8n_data_*.tar.gz ./
gunzip n8n_data_*.tar.gz
docker volume create sprnovo_n8n_data
docker run --rm -v sprnovo_n8n_data:/target -v $(pwd):/source alpine tar -xzf /source/n8n_data_*.tar -C /target

# Reiniciar tudo
docker-compose up -d
```

## 📞 Suporte

### Contatos
- **Administração**: admin@royalnegociosagricolas.com.br
- **Servidor**: Acesso SSH necessário

### Documentação Adicional
- n8n: https://docs.n8n.io/
- Evolution API: https://doc.evolution-api.com/
- Docker Compose: https://docs.docker.com/compose/

---

## ✅ Status da Migração

- [x] Parar serviços antigos do SPR
- [x] Preservar banco de dados legado  
- [x] Criar Docker Compose completo
- [x] Configurar n8n com volumes persistentes
- [x] Setup Nginx para automation.royalnegociosagricolas.com.br
- [x] Configurar LetsEncrypt SSL
- [x] Criar rotina backup para DB e n8n_data
- [x] Scripts de deploy automatizado
- [x] Documentação completa

**Status**: ✅ **MIGRAÇÃO COMPLETA E PRONTA PARA PRODUÇÃO**

Data: 2025-01-07  
Versão: SPRNOVO v1.0.0