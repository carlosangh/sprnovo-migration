# SPR Sistema - Mapa Operacional

## Visão Geral

Este documento mapeia toda a infraestrutura operacional do Sistema SPR, incluindo configurações de serviços, scripts de deployment, monitoramento e automação.

## Estrutura de Diretórios Operacionais

```
/home/cadu/SPRNOVO/ops/
├── pm2/                    # Configurações PM2
├── nginx/                  # Configurações Nginx
├── docker/                 # Containers Docker (se aplicável)
├── ci-cd/                  # Scripts de CI/CD e Deploy
├── monitoring/             # Configurações de Monitoramento
└── cron/                   # Jobs Agendados

/home/cadu/SPRNOVO/secrets/templates/
├── .env.production.template
├── .env.staging.template
├── database-secrets.template
├── ssl-certificates.template
└── api-keys.template
```

## Configurações PM2

### Arquivos Principais
- **ecosystem.production.config.js**: Configuração para produção
- **ecosystem.staging.config.js**: Configuração para staging
- **pm2-startup.sh**: Script de inicialização automática
- **pm2-deploy.sh**: Script de deployment com PM2

### Portas e Serviços
| Ambiente | Serviço | Porta | Configuração |
|----------|---------|-------|--------------|
| Production | Backend | 3002 | ecosystem.production.config.js |
| Staging | Backend | 3003 | ecosystem.staging.config.js |
| Production | Analytics | 8000 | Proxy via nginx |
| Staging | Analytics | 8001 | Proxy via nginx |

### Configurações de Performance
- **Memory Limit**: 512MB (produção), 256MB (staging)
- **Restart Policy**: 5 tentativas máximas
- **Min Uptime**: 10s (produção), 5s (staging)
- **Restart Delay**: 4s (produção), 2s (staging)

## Configurações Nginx

### Sites Disponíveis
- **spr-production**: Configuração para produção com SSL
- **spr-staging**: Configuração para staging

### Recursos Implementados
- **SSL/TLS**: Let's Encrypt com renovação automática
- **Compression**: Gzip e Brotli (opcional)
- **Rate Limiting**: Por IP e endpoint
- **Load Balancing**: Upstream para backend e analytics
- **Security Headers**: HSTS, CSP, XSS Protection
- **Caching**: Assets estáticos com cache longo

### Upstreams Configurados
```nginx
upstream spr_backend {
    least_conn;
    server 127.0.0.1:3002;
}

upstream spr_analytics {
    least_conn;
    server 127.0.0.1:8000;
}
```

## Scripts de CI/CD

### Build e Deploy
- **build_frontend.sh**: Build otimizado do React com validação
- **deploy.sh**: Script principal de deployment com rollback

### Funcionalidades do Deploy
- ✅ Backup automático antes do deploy
- ✅ Testes automatizados (opcional)
- ✅ Health checks pós-deploy
- ✅ Rollback automático em caso de falha
- ✅ Notificações de status

### Variáveis de Ambiente
```bash
ENVIRONMENT=production|staging|development
SKIP_TESTS=true|false
SKIP_BACKUP=true|false
PROJECT_ROOT=/opt/spr
```

## Jobs Agendados (Cron)

### Scripts Implementados

#### 1. Backup de Banco de Dados
- **Arquivo**: `backup-database.sh`
- **Frequência**: Diário às 2:00
- **Retenção**: 30 dias
- **Suporte**: PostgreSQL, MySQL, SQLite
- **Upload**: S3 (opcional)

#### 2. Rotação de Logs
- **Arquivo**: `log-rotation.sh`
- **Frequência**: Diário às 3:00
- **Limite**: 100MB por arquivo
- **Compressão**: Automática
- **Retenção**: 30 dias

#### 3. Monitor de Saúde
- **Arquivo**: `health-monitor.sh`
- **Frequência**: A cada 5 minutos
- **Monitoramento**: CPU, Memória, Disco, Serviços
- **Alertas**: Email e Slack
- **Thresholds**: CPU 80%, Memória 85%, Disco 90%

#### 4. Limpeza do Sistema
- **Arquivo**: `system-cleanup.sh`
- **Frequência**: Semanal aos domingos às 4:00
- **Tarefas**: Temp files, cache, packages, logs antigos

### Template de Crontab
```bash
# Backup diário
0 2 * * * /opt/spr/ops/cron/backup-database.sh

# Rotação de logs
0 3 * * * /opt/spr/ops/cron/log-rotation.sh

# Monitoramento
*/5 * * * * /opt/spr/ops/cron/health-monitor.sh

# Limpeza semanal
0 4 * * 0 /opt/spr/ops/cron/system-cleanup.sh
```

## Monitoramento

### Prometheus
- **Configuração**: `prometheus.yml`
- **Targets**: Sistema, aplicação, nginx, database
- **Alertas**: `alert_rules.yml`
- **Métricas**: CPU, memória, disco, response time

### Grafana
- **Dashboard**: `grafana-dashboard.json`
- **Painéis**: Overview, CPU, memória, response time
- **Refresh**: 30 segundos

### Logs
| Serviço | Log Location | Formato |
|---------|--------------|---------|
| PM2 | `/opt/spr/logs/` | JSON com timestamp |
| Nginx | `/var/log/nginx/` | Combined + custom |
| Sistema | `/var/log/spr/` | Text com timestamp |

## Segurança e Secrets

### Templates de Configuração
- **Produção**: `.env.production.template`
- **Staging**: `.env.staging.template`
- **Database**: `database-secrets.template`
- **SSL**: `ssl-certificates.template`
- **APIs**: `api-keys.template`

### Práticas de Segurança
- ✅ Secrets separados por ambiente
- ✅ Chaves criptográficas fortes
- ✅ SSL/TLS obrigatório em produção
- ✅ Headers de segurança configurados
- ✅ Rate limiting implementado

## Dependências e Requisitos

### Sistema Base
- **OS**: Linux (testado no Ubuntu/Debian)
- **Node.js**: v16+ (para PM2 e frontend)
- **Python**: v3.8+ (para backend)
- **Nginx**: v1.18+
- **PostgreSQL**: v12+ (recomendado)

### Ferramentas Opcionais
- **Docker**: Para containerização
- **Prometheus**: Para métricas
- **Grafana**: Para dashboards
- **Certbot**: Para SSL gratuito
- **Redis**: Para cache e sessões

## Portas de Rede

| Serviço | Porta | Protocolo | Acesso |
|---------|-------|-----------|---------|
| Nginx | 80 | HTTP | Público (redirect) |
| Nginx | 443 | HTTPS | Público |
| Backend | 3002 | HTTP | Local |
| Backend Staging | 3003 | HTTP | Local |
| Analytics | 8000 | HTTP | Local |
| Analytics Staging | 8001 | HTTP | Local |
| PostgreSQL | 5432 | TCP | Local |
| Redis | 6379 | TCP | Local |
| Prometheus | 9090 | HTTP | Local |
| Grafana | 3000 | HTTP | Local |

## Comandos Úteis

### PM2
```bash
# Deploy produção
./ops/pm2/pm2-deploy.sh production

# Deploy staging
./ops/pm2/pm2-deploy.sh staging

# Status dos processos
pm2 status

# Logs em tempo real
pm2 logs spr-backend-production
```

### Nginx
```bash
# Testar configuração
nginx -t

# Recarregar configuração
systemctl reload nginx

# Setup SSL
./ops/nginx/ssl-setup.sh yourdomain.com
```

### Deploy
```bash
# Deploy completo
./ops/ci-cd/deploy.sh production

# Deploy sem testes
SKIP_TESTS=true ./ops/ci-cd/deploy.sh production

# Rollback
./ops/ci-cd/deploy.sh rollback
```

### Monitoramento
```bash
# Verificar saúde
./ops/cron/health-monitor.sh

# Relatório de sistema
./ops/cron/system-cleanup.sh --report

# Analisar logs
./ops/cron/log-rotation.sh --analyze
```

## Troubleshooting

### Problemas Comuns

#### 1. Serviço PM2 não inicia
- Verificar permissões dos arquivos
- Conferir path do Python no ecosystem config
- Verificar se as portas estão disponíveis

#### 2. Nginx erro 502
- Verificar se o backend está rodando (`pm2 status`)
- Confirmar portas no upstream
- Checar logs: `tail -f /var/log/nginx/error.log`

#### 3. SSL não funciona
- Verificar certificados: `./ops/nginx/ssl-setup.sh --help`
- Testar renovação: `certbot renew --dry-run`
- Conferir firewall nas portas 80 e 443

#### 4. Alto uso de recursos
- Executar: `./ops/cron/health-monitor.sh --system`
- Limpar cache: `./ops/cron/system-cleanup.sh --cache`
- Analisar logs: `./ops/cron/log-rotation.sh --analyze`

### Logs de Troubleshooting
- **Sistema**: `/var/log/spr/`
- **PM2**: `/opt/spr/logs/`
- **Nginx**: `/var/log/nginx/`
- **Deploy**: Saída do script com timestamps

## Manutenção

### Diária (Automatizada)
- Backup do banco de dados
- Rotação de logs
- Verificação de saúde do sistema
- Renovação SSL (se necessário)

### Semanal
- Limpeza do sistema
- Relatório de uso de recursos
- Verificação de backups
- Restart programado (opcional)

### Mensal
- Revisão de alertas e thresholds
- Atualização de dependências
- Análise de performance
- Auditoria de segurança

---

**Data da Última Atualização**: 2025-09-05  
**Versão do Sistema**: SPR v1.0  
**Ambiente**: Produção e Staging  

Para suporte técnico, consulte os logs relevantes e execute os scripts de diagnóstico apropriados.