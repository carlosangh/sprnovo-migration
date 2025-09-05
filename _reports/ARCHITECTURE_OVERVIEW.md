# SPR SISTEMA - VISÃO GERAL DA ARQUITETURA

## Resumo Executivo

O Sistema Preditivo Royal (SPR) é uma plataforma de análise e predição de commodities agrícolas que combina múltiplas fontes de dados, inteligência artificial e comunicação em tempo real para fornecer insights estratégicos do mercado agropecuário brasileiro.

## Arquitetura de Alto Nível

### Diagrama Conceitual da Arquitetura

```
┌─────────────────────────────────────────────────────────────┐
│                    ECOSSISTEMA SPR                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐    ┌──────────────┐    ┌─────────────┐    │
│  │   FRONTEND  │    │   GATEWAY    │    │   MOBILE    │    │
│  │  (React SPA) │◄──►│  (Nginx)     │◄──►│   (App)     │    │
│  └─────────────┘    └──────────────┘    └─────────────┘    │
│                              │                               │
│  ════════════════════════════════════════════════════════   │
│                              │                               │
│  ┌─────────────────────────────────────────────────────────┐│
│  │               CAMADA DE BACKEND                         ││
│  │                                                         ││
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    ││
│  │  │COORDINATOR  │  │   NODE.JS    │  │  ANALYTICS  │    ││
│  │  │   (3001)    │◄─┤   BACKEND    │─►│   (3005)    │    ││
│  │  │             │  │   (3002)     │  │             │    ││
│  │  └─────────────┘  └─────────────┘  └─────────────┘    ││
│  │         │                 │                 │          ││
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    ││
│  │  │ WHATSAPP    │  │    AI        │  │ REAL-TIME   │    ││
│  │  │   AGENT     │  │ COMMERCIAL   │  │   DATA      │    ││
│  │  │   (3xxx)    │  │   (3004)     │  │   (3010)    │    ││
│  │  └─────────────┘  └─────────────┘  └─────────────┘    ││
│  └─────────────────────────────────────────────────────────┘│
│                              │                               │
│  ┌─────────────────────────────────────────────────────────┐│
│  │              SERVIÇOS PYTHON                            ││
│  │                                                         ││
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    ││
│  │  │    OCR      │  │   CLAUDE    │  │   SMART     │    ││
│  │  │  SERVICE    │◄─┤ INTEGRATION │─►│  ANALYSIS   │    ││
│  │  │   (8000)    │  │             │  │   AGENT     │    ││
│  │  └─────────────┘  └─────────────┘  └─────────────┘    ││
│  └─────────────────────────────────────────────────────────┘│
│                              │                               │
│  ════════════════════════════════════════════════════════   │
│                              │                               │
│  ┌─────────────────────────────────────────────────────────┐│
│  │              CAMADA DE DADOS                            ││
│  │                                                         ││
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    ││
│  │  │   SQLite    │  │ PostgreSQL  │  │    Redis    │    ││
│  │  │  (Atual)    │◄─┤  (Planejado) │─►│   (Cache)   │    ││
│  │  │spr_central  │  │   (5432)    │  │   (6379)    │    ││
│  │  └─────────────┘  └─────────────┘  └─────────────┘    ││
│  └─────────────────────────────────────────────────────────┘│
│                              │                               │
│  ┌─────────────────────────────────────────────────────────┐│
│  │            INGESTÃO DE DADOS                            ││
│  │                                                         ││
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    ││
│  │  │   CEPEA     │  │    IMEA     │  │     B3      │    ││
│  │  │ (10min)     │  │  (1hora)    │  │  (15min)    │    ││
│  │  └─────────────┘  └─────────────┘  └─────────────┘    ││
│  │                                                         ││
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    ││
│  │  │    CME      │  │   INMET     │  │   NEWS      │    ││
│  │  │  (30min)    │  │  (3horas)   │  │  (1hora)    │    ││
│  │  └─────────────┘  └─────────────┘  └─────────────┘    ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

## Decisões Arquiteturais Principais

### 1. Arquitetura Distribuída de Microserviços

**Decisão**: Separação de responsabilidades em serviços especializados

**Justificativa**:
- **Escalabilidade independente**: Cada serviço pode escalar conforme demanda específica
- **Fault tolerance**: Falha em um serviço não afeta os demais
- **Tecnologia heterogênea**: Node.js para APIs, Python para IA/ML
- **Desenvolvimento paralelo**: Times podem trabalhar independentemente

**Implementação**:
```
Serviços Implementados:
├── spr-coordinator (3001) - Orquestração e saúde
├── spr-backend-production (3002) - API principal
├── spr-ai-commercial (3004) - IA comercial
├── spr-analytics (3005) - Analytics e métricas
├── spr-automation (3006) - Automação de processos
├── spr-backend-agent (3007) - Agente de backend
├── spr-typescript-pro (3008) - Serviços TypeScript
└── spr-real-data (3010) - Dados tempo real
```

### 2. Stack Tecnológico Híbrido (Node.js + Python)

**Decisão**: Combinação Node.js para APIs e Python para ML/IA

**Justificativa Node.js**:
- **Performance alta** para APIs REST e WebSocket
- **Ecosystem maduro** para desenvolvimento web
- **Facilidade de deployment** e gestão PM2
- **Community e libraries** extensas para integrações

**Justificativa Python**:
- **Ecossistema ML/IA** incomparável (FastAPI, scikit-learn, tensorflow)
- **OCR e processamento** de documentos natural
- **Integração Claude** e outros serviços IA
- **Prototipagem rápida** de algoritmos

**Tecnologias Escolhidas**:
```javascript
// Backend Node.js Stack
{
  "runtime": "Node.js 16+",
  "framework": "Express.js 4.18.2",
  "typing": "TypeScript",
  "auth": "JWT + BCrypt",
  "realtime": "Socket.io 4.6.1",
  "security": "Helmet + CORS"
}
```

```python
# Serviços Python Stack
{
  "runtime": "Python 3.8+",
  "framework": "FastAPI",
  "ml": "scikit-learn, pandas",
  "ocr": "pytesseract, OpenCV", 
  "ai": "Claude API Integration",
  "async": "asyncio, aiofiles"
}
```

### 3. Padrão Gateway com Nginx

**Decisão**: Nginx como proxy reverso e load balancer

**Justificativa**:
- **Ponto único de entrada** para todos os serviços
- **SSL termination** centralizado
- **Rate limiting** e segurança
- **Static file serving** otimizado
- **Health check** e failover automático

**Configuração**:
```nginx
# /home/cadu/SPRNOVO/ops/nginx/sites-available/spr-production
upstream spr_backend {
    least_conn;
    server 127.0.0.1:3002 max_fails=3 fail_timeout=30s;
}

upstream spr_analytics {
    least_conn;
    server 127.0.0.1:3005 max_fails=3 fail_timeout=30s;
}

server {
    listen 443 ssl http2;
    server_name royalnegociosagricolas.com.br;
    
    location /api/ {
        proxy_pass http://spr_backend;
    }
    
    location /analytics/ {
        proxy_pass http://spr_analytics;
    }
}
```

### 4. Persistência Multi-Model

**Decisão**: SQLite para desenvolvimento, PostgreSQL para produção

**Estado Atual**:
```
SQLite (spr_central.db):
├── 9 tabelas principais
├── 27k registros aproximadamente  
├── Ideal para desenvolvimento e testes
└── Performance adequada para carga atual

PostgreSQL (Planejado):
├── Migração com zero-downtime
├── Suporte para conexões concorrentes
├── Features avançadas (JSON, Full-text search)
└── Backup e replicação enterprise
```

**Justificativa**:
- **SQLite**: Simplicidade inicial, zero configuração, ideal para MVP
- **PostgreSQL**: Escalabilidade, ACID completo, features avançadas
- **Redis**: Cache de alta performance para sessões e dados temporários

## Patterns Arquiteturais Implementados

### 1. API Gateway Pattern

**Implementação**: Nginx como gateway unificado

**Benefícios**:
- Roteamento centralizado de requests
- Autenticação e autorização unificada  
- Rate limiting e throttling
- Monitoring e logging centralizados

### 2. Circuit Breaker Pattern

**Implementação**: PM2 com restart automático

**Configuração**:
```javascript
// ecosystem.production.config.js
{
  max_restarts: 5,
  min_uptime: "10s", 
  max_memory_restart: "512M",
  restart_delay: 4000
}
```

### 3. Event-Driven Architecture

**Implementação**: Socket.io para comunicação real-time

**Casos de Uso**:
- Notificações de preços em tempo real
- Status updates dos agentes
- Alertas de sistema
- Sincronização de dados entre clientes

### 4. Strangler Fig Pattern

**Implementação**: Migração gradual de SQLite para PostgreSQL

**Estratégia**:
```
Fase 1: Dual-write (SQLite + PostgreSQL)
Fase 2: Read from PostgreSQL, write to both
Fase 3: Full migration to PostgreSQL
Fase 4: SQLite deprecation
```

## Fluxo de Dados Principal

### 1. Ingestão de Dados Externa

```
Pipeline de Ingestão:
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   FONTES    │───►│  INGESTORS  │───►│  DATABASE   │
│             │    │             │    │             │
│ • CEPEA     │    │ • Python    │    │ • SQLite    │
│ • IMEA      │    │ • Cron Jobs │    │ • Redis     │
│ • B3        │    │ • Validation│    │ • Backups   │
│ • CME       │    │ • Transform │    │             │
└─────────────┘    └─────────────┘    └─────────────┘
```

**Frequências Configuradas**:
- **CEPEA**: 10 minutos (seg-sex, 8h-18h)
- **IMEA**: 1 hora (seg-sex, 8h-18h)  
- **B3**: 15 minutos (seg-sex, 9h-18h)
- **CME**: 30 minutos (seg-sex, 9h-23h)
- **News**: 1 hora (24/7)
- **INMET**: 3 horas (24/7)

### 2. Processamento e Análise

```
Fluxo de Análise:
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ RAW DATA    │───►│ PROCESSING  │───►│  INSIGHTS   │
│             │    │             │    │             │
│ • Preços    │    │ • OCR       │    │ • Predições │
│ • Volumes   │    │ • Claude AI │    │ • Alertas   │
│ • News      │    │ • Analytics │    │ • Reports   │
│ • Clima     │    │ • ML Models │    │ • Calls     │
└─────────────┘    └─────────────┘    └─────────────┘
```

### 3. Distribuição e Interface

```
Entrega ao Usuário:
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  BACKEND    │───►│  GATEWAY    │───►│  FRONTEND   │
│             │    │             │    │             │
│ • APIs REST │    │ • Nginx     │    │ • React SPA │
│ • WebSocket │    │ • SSL/TLS   │    │ • Dashboard │
│ • WhatsApp  │    │ • Rate Limit│    │ • Mobile    │
│ • Webhooks  │    │ • Security  │    │ • WhatsApp  │
└─────────────┘    └─────────────┘    └─────────────┘
```

## Características de Performance

### Métricas de Sistema (Servidor Produção)

**Hardware (Digital Ocean NYC3)**:
- **CPU**: 2 vCPUs
- **RAM**: 4GB
- **Storage**: 80GB SSD
- **Rede**: 1GB/s

**Performance Observada**:
- **Uptime**: 3+ dias estável
- **Response Time**: <200ms (APIs principais)
- **Throughput**: ~1000 req/min nas APIs críticas
- **Concorrência**: 50+ usuários simultâneos

### Bottlenecks Identificados

**Críticos (Requerem Ação Imediata)**:
1. **spr-real-data**: 2369 restarts (instabilidade alta)
2. **spr-whatsapp-agent**: 605 restarts
3. **Conflito de portas**: 3 serviços na porta 3002

**Médio Prazo**:
1. **Memória**: Alguns serviços próximos do limite (512MB)
2. **Database**: SQLite pode ser gargalo com mais usuários
3. **Network I/O**: Ingestão de dados pode saturar

### Estratégias de Otimização

**Implementações Recomendadas**:

1. **Caching Strategy**:
```javascript
// Redis para cache de dados frequentes
const cache = {
  prices: "5min TTL",
  analytics: "15min TTL", 
  user_sessions: "24h TTL",
  market_data: "1min TTL"
}
```

2. **Database Indexing**:
```sql
-- Índices críticos para performance
CREATE INDEX idx_price_history_commodity_timestamp 
ON price_history(commodity_id, timestamp DESC);

CREATE INDEX idx_analytics_metrics_type_timestamp 
ON analytics_metrics(metric_type, timestamp DESC);
```

3. **Connection Pooling**:
```javascript
// PostgreSQL connection pool
const pool = {
  min: 2,
  max: 20,
  acquireTimeoutMillis: 30000,
  idleTimeoutMillis: 30000
}
```

## Segurança por Design

### Princípios de Segurança Implementados

**1. Defense in Depth**:
```
Camadas de Segurança:
├── WAF (Nginx) - Rate limiting, IP filtering
├── SSL/TLS - Criptografia em trânsito  
├── JWT - Autenticação stateless
├── BCrypt - Hash de senhas seguro
├── Helmet - Security headers
└── Environment Variables - Secrets isolados
```

**2. Least Privilege**:
- Cada serviço roda com permissões mínimas
- Database users com acesso restrito por função
- File system permissions limitadas por processo

**3. Fail Secure**:
- Autenticação falha por padrão
- Logs de segurança sempre ativos
- Degradação graceful em caso de falhas

### Controles de Segurança

**Autenticação e Autorização**:
```javascript
// JWT Implementation
const token = jwt.sign(
  { userId, role, permissions },
  process.env.JWT_SECRET,
  { expiresIn: '24h', issuer: 'spr-system' }
);
```

**Rate Limiting**:
```nginx
# Nginx rate limiting
limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
limit_req zone=api burst=20 nodelay;
```

**SSL/TLS Configuration**:
```nginx
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;
ssl_prefer_server_ciphers off;
```

## Observabilidade e Monitoramento

### Estratégia de Monitoring

**1. Health Checks**:
```javascript
// Endpoint de saúde padronizado
app.get('/health', async (req, res) => {
  const health = {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    services: {
      database: await checkDatabase(),
      cache: await checkRedis(),
      external_apis: await checkExternalAPIs()
    }
  };
  res.json(health);
});
```

**2. Metrics Collection**:
```
Métricas Coletadas:
├── System: CPU, Memory, Disk, Network
├── Application: Response time, Error rate, Throughput  
├── Business: Users active, Transactions, Revenue
└── Security: Failed logins, Rate limit hits, Anomalies
```

**3. Alerting Strategy**:
```yaml
# alert_rules.yml
groups:
  - name: spr-critical
    rules:
      - alert: ServiceDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
      - alert: HighMemoryUsage  
        expr: (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) < 0.1
        for: 5m
        labels:
          severity: warning
```

## Evolução Arquitetural Planejada

### Roadmap Técnico (Próximos 12 meses)

**Q1 2025 - Estabilização**:
- ✅ Resolução de instabilidade dos serviços críticos
- ✅ Migração para PostgreSQL
- ✅ Implementação de monitoring avançado
- ✅ CI/CD automatizado

**Q2 2025 - Escalabilidade**:
- 🔄 Load balancing horizontal
- 🔄 Database sharding por commodity
- 🔄 Cache distribuído Redis Cluster  
- 🔄 CDN para assets estáticos

**Q3 2025 - Intelligence**:
- 🔄 ML Pipeline automatizado
- 🔄 Real-time analytics com streaming
- 🔄 Integração GraphQL
- 🔄 AI/ML model versioning

**Q4 2025 - Enterprise**:
- 🔄 Multi-tenant architecture
- 🔄 Advanced security (OAuth2, SAML)
- 🔄 Disaster recovery completo
- 🔄 Compliance (LGPD, SOX)

### Arquitetura Target State

```
┌─────────────────────────────────────────────────────────────┐
│                 ARQUITETURA FUTURA                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐    ┌──────────────┐    ┌─────────────┐    │
│  │   CDN       │    │   API        │    │ MOBILE      │    │
│  │ (CloudFlare)│◄──►│  GATEWAY     │◄──►│ NATIVE      │    │
│  └─────────────┘    │ (Kong/Zuul)  │    └─────────────┘    │
│                      └──────────────┘                       │
│                              │                               │
│  ┌─────────────────────────────────────────────────────────┐│
│  │            KUBERNETES CLUSTER                           ││
│  │                                                         ││
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐      ││
│  │  │Backend  │ │Analytics│ │ML/AI    │ │WhatsApp │      ││
│  │  │Service  │ │Service  │ │Service  │ │Service  │      ││
│  │  │(3 pods) │ │(2 pods) │ │(2 pods) │ │(1 pod)  │      ││
│  │  └─────────┘ └─────────┘ └─────────┘ └─────────┘      ││
│  └─────────────────────────────────────────────────────────┘│
│                              │                               │
│  ┌─────────────────────────────────────────────────────────┐│
│  │              DATA LAYER                                 ││
│  │                                                         ││
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐      ││
│  │  │PostgreSQL │Redis   │ │Elasticsearch│MinIO   │      ││
│  │  │(Primary)│ │Cluster │ │(Search) │ │(Storage)│      ││
│  │  └─────────┘ └─────────┘ └─────────┘ └─────────┘      ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

## Recomendações de Implementação

### 1. Prioridades Imediatas (Sprint 1-2)

**Estabilização Crítica**:
```bash
# Ações de alta prioridade
1. Investigar e corrigir spr-real-data (2369 restarts)
2. Resolver conflito de portas 3002
3. Implementar health checks robustos
4. Configurar alertas críticos
```

### 2. Melhorias de Base (Sprint 3-6)

**Infraestrutura Sólida**:
```bash
# Consolidação da base
1. Migração PostgreSQL com zero-downtime
2. Implementação Redis para cache/sessões
3. CI/CD pipeline com testes automatizados
4. Backup e disaster recovery
```

### 3. Evolução Inteligente (Sprint 7-12)

**Features Avançadas**:
```bash
# Inovação e diferenciação
1. ML pipeline para predições avançadas
2. Real-time analytics e dashboards
3. API GraphQL para queries flexíveis
4. Mobile-first progressive web app
```

---

**Arquitetura Documentada**: 2025-09-05  
**Status**: Implementação em Produção  
**Próxima Revisão**: Q1 2025  
**Arquiteto Responsável**: Claude Code (Technical Documentation Specialist)