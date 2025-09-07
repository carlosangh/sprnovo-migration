# Checklist de Segurança - Evolution API SPR
**Security Level: HIGH | Environment: Production**  
**Responsible: Marcus Silva - Security & DevOps Team**

---

## 🔐 1. Configuração de Segredos

### ✅ Segredos Criptográficos
- [x] **API Key Evolution** (64 chars hex): `c79255bd93a0cec5f569f92df6ed93f3d1c45925fb817d5f6cb74bf267e24e3c`
- [x] **Webhook Token** (48 chars hex): `2c3d60cec62b50a72078424f2b1d96656a9f9d2943fad757`
- [x] **JWT Secret** (64 chars hex): `aaec297f89d3f0098780c515c7a655b2595eff1975c178a1e99cb4c0ed7e75a6`
- [x] **Session Secret** (64 chars hex): `78f83d029a680ac1e87521039709618959af2e27181113c79a84c0879bfde705`

### ⚠️ Armazenamento Seguro
- [x] Arquivo `./secrets/evolution.env` criado com permissões restritas (600)
- [ ] **AÇÃO NECESSÁRIA**: Verificar se arquivo está no `.gitignore`
- [ ] **AÇÃO NECESSÁRIA**: Backup seguro dos segredos em local criptografado
- [ ] **AÇÃO NECESSÁRIA**: Rotação de segredos programada (90 dias)

---

## 🌐 2. Configuração de Rede e Proxy

### ✅ Nginx Configuration
- [x] **Server Block** criado para `evo.royalnegociosagricolas.com.br`
- [x] **Rate Limiting** implementado:
  - API endpoints: 30 req/min
  - Webhooks: 100 req/min  
  - Geral: 60 req/min
- [x] **Connection Limiting**: máx 20 conexões por IP
- [x] **Security Headers** implementados:
  - HSTS com preload
  - X-Content-Type-Options
  - X-Frame-Options: DENY
  - CSP Policy configurado
- [x] **Proxy Configuration**: 127.0.0.1:8080 (interno apenas)

### 🔒 SSL/TLS
- [x] **Script SSL Setup** criado: `/home/cadu/SPRNOVO/ops/nginx/ssl-setup.sh`
- [ ] **AÇÃO NECESSÁRIA**: Executar certbot para certificado SSL
- [ ] **AÇÃO NECESSÁRIA**: Configurar auto-renewal do certificado
- [ ] **AÇÃO NECESSÁRIA**: Testar SSL Labs Score (A+ esperado)

---

## 🐳 3. Docker & Container Security

### ✅ Docker Compose
- [x] **Multi-stage security** implementado
- [x] **User permissions**: containers não rodam como root
- [x] **Security opts**: `no-new-privileges:true`
- [x] **Capability dropping**: CAP_DROP ALL configurado
- [x] **Network isolation**: rede bridge dedicada
- [x] **Health checks**: configurados para todos os serviços

### ✅ Volume Security
- [x] **Bind mounts** seguros para `/opt/spr/data`
- [x] **tmpfs** para dados temporários
- [x] **Permissions** restritas nos volumes

### ⚠️ Container Monitoring
- [x] **Watchtower** configurado para atualizações automáticas
- [ ] **AÇÃO NECESSÁRIA**: Configurar email SMTP para notificações
- [ ] **AÇÃO NECESSÁRIA**: Testar alertas do Watchtower

---

## 🗄️ 4. Database Security

### ✅ PostgreSQL
- [x] **Authentication**: SCRAM-SHA-256 configurado
- [x] **User permissions**: spr_evolution com privilégios mínimos
- [x] **Audit logging**: tabela audit_log implementada
- [x] **Row Level Security**: habilitado
- [x] **Connection limits**: configurado via Docker
- [x] **Listening**: apenas localhost (127.0.0.1:5432)

### ✅ Redis
- [x] **Password protection**: SPRevol2024redis
- [x] **Memory limits**: 256MB maxmemory
- [x] **Persistence**: AOF habilitado
- [x] **Listening**: apenas localhost (127.0.0.1:6379)

---

## 📊 5. Logging e Monitoring

### ✅ Log Configuration
- [x] **Docker logging**: json-file driver com rotação
- [x] **Nginx logs**: access/error logs configurados
- [x] **Application logs**: ERROR level configurado
- [x] **Centralized logging**: `/var/log/spr/` criado

### ✅ Monitoring Scripts
- [x] **Health Monitor**: `/home/cadu/SPRNOVO/scripts/evolution-monitor.sh`
- [x] **Startup Script**: `/home/cadu/SPRNOVO/scripts/evolution-start.sh`
- [x] **Shutdown Script**: `/home/cadu/SPRNOVO/scripts/evolution-stop.sh`

### ⚠️ Monitoring Setup
- [ ] **AÇÃO NECESSÁRIA**: Configurar alertas para recursos (CPU/RAM/Disk)
- [ ] **AÇÃO NECESSÁRIA**: Configurar SIEM/log analysis
- [ ] **AÇÃO NECESSÁRIA**: Implementar dashboard de monitoramento

---

## 🔍 6. API Security

### ✅ Evolution API Configuration
- [x] **API Key Authentication** obrigatório
- [x] **Rate limiting interno** configurado
- [x] **CORS** configurado adequadamente
- [x] **Webhook security** com token de validação
- [x] **Instance cleanup** automático configurado
- [x] **Language**: pt-BR configurado

### ⚠️ API Hardening
- [ ] **AÇÃO NECESSÁRIA**: Implementar IP whitelist se necessário
- [ ] **AÇÃO NECESSÁRIA**: Configurar WAF (Web Application Firewall)
- [ ] **AÇÃO NECESSÁRIA**: Testar todos os endpoints com ferramentas de segurança

---

## 🚨 7. Incident Response

### ⚠️ Procedures
- [ ] **AÇÃO NECESSÁRIA**: Documentar procedimento de incident response
- [ ] **AÇÃO NECESSÁRIA**: Definir contatos de emergência
- [ ] **AÇÃO NECESSÁRIA**: Criar playbook de recuperação
- [ ] **AÇÃO NECESSÁRIA**: Implementar alertas de segurança em tempo real

---

## ✅ 8. Compliance & Audit

### ✅ Data Protection
- [x] **LGPD Compliance**: dados processados apenas no Brasil
- [x] **Data encryption**: em trânsito (TLS) e em repouso
- [x] **Access logging**: todas as operações logadas
- [x] **Data retention**: configurado para 30 dias

### ⚠️ Security Testing
- [ ] **AÇÃO NECESSÁRIA**: Executar penetration testing
- [ ] **AÇÃO NECESSÁRIA**: Vulnerability assessment
- [ ] **AÇÃO NECESSÁRIA**: Code security review
- [ ] **AÇÃO NECESSÁRIA**: Dependency security scan

---

## 📋 9. Deployment Checklist

### Pré-Deploy
- [ ] Verificar se todos os segredos estão gerados
- [ ] Validar configuração do nginx
- [ ] Testar docker-compose localmente
- [ ] Verificar disponibilidade do domínio
- [ ] Backup dos dados existentes (se aplicável)

### Deploy
- [ ] Executar `./scripts/evolution-start.sh`
- [ ] Executar `./ops/nginx/ssl-setup.sh`
- [ ] Configurar certificado SSL
- [ ] Testar todos os endpoints
- [ ] Verificar logs por erros

### Pós-Deploy
- [ ] Executar `./scripts/evolution-monitor.sh`
- [ ] Configurar monitoring/alerting
- [ ] Documentar informações de acesso
- [ ] Treinar equipe operacional
- [ ] Agendar revisão de segurança em 30 dias

---

## 🔧 10. Scripts de Gerenciamento

### ✅ Scripts Criados
```bash
# Inicialização segura
./scripts/evolution-start.sh

# Parada graceful
./scripts/evolution-stop.sh [--graceful|--force|--clean]

# Monitoramento
./scripts/evolution-monitor.sh [--watch|--once]

# Setup SSL
./ops/nginx/ssl-setup.sh
```

---

## 📞 11. Contatos de Emergência

```
Security Team Lead: Marcus Silva
Email: security@royalnegociosagricolas.com.br
Phone: +55 (XX) XXXX-XXXX

DevOps Team:
Email: devops@royalnegociosagricolas.com.br
Slack: #spr-security-alerts
```

---

## ⚡ 12. Comandos Rápidos

```bash
# Status dos serviços
docker-compose ps

# Logs em tempo real
docker-compose logs -f evolution-api

# Monitoramento contínuo
./scripts/evolution-monitor.sh --watch

# Reiniciar serviço específico
docker-compose restart evolution-api

# Backup manual da base
docker-compose exec postgres-evolution pg_dump -U spr_evolution evolution_db > backup.sql
```

---

**⚠️ IMPORTANTE**: Este checklist deve ser revisado e atualizado a cada deployment e mensalmente pela equipe de segurança.

**Última atualização**: 2025-09-05  
**Próxima revisão**: 2025-10-05  
**Responsável**: Marcus Silva - Security & DevOps SPR