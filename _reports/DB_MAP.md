# MAPA COMPLETO DOS BANCOS DE DADOS - SPR (Sistema Preditivo Royal)

## Resumo Executivo

Este documento mapeia a estrutura completa dos bancos de dados do SPR, incluindo schemas, relacionamentos e arquitetura de dados.

### Bancos Identificados

| Banco | Localização | Tipo | Status | Tabelas |
|-------|-------------|------|--------|---------|
| **spr_central** | /home/cadu/spr-project/data/spr_central.db | SQLite | 🟢 Ativo | 9 |
| spr_broadcast | /home/cadu/spr_deployment/spr_broadcast.db | SQLite | 🔍 Encontrado | - |
| spr_users | /home/cadu/projeto_SPR/spr_users.db | SQLite | 🔍 Encontrado | - |
| spr | /home/cadu/projeto_SPR/data/spr.db | SQLite | 🔍 Encontrado | - |
| spr_backup | /home/cadu/projeto_SPR/data/spr_backup.db | SQLite | 🔍 Encontrado | - |
| spr_work | /home/cadu/projeto_SPR/data/spr_work.db | SQLite | 🔍 Encontrado | - |
| spr_whatsapp | /home/cadu/projeto_SPR/spr_whatsapp.db | SQLite | 🔍 Encontrado | - |
| spr_validation | /home/cadu/projeto_SPR/spr_validation.db | SQLite | 🔍 Encontrado | - |
| spr_yahoo_finance | /home/cadu/projeto_SPR/spr_yahoo_finance.db | SQLite | 🔍 Encontrado | - |
| clg_test | /home/cadu/ciclologico_production/backend_v2/clg_test.db | SQLite | 🔍 Encontrado | - |
| clg_historical | /home/cadu/ciclologico_production/backend_v2/clg_historical.db | SQLite | 🔍 Encontrado | - |
| **PostgreSQL** | Docker Compose | PostgreSQL 15 | 📋 Planejado | - |

## Banco Principal: spr_central.db

### Visão Geral
- **Localização**: `/home/cadu/spr-project/data/spr_central.db`
- **Tipo**: SQLite
- **Tabelas**: 9 entidades principais
- **Registros Totais**: ~27 registros distribuídos

### Arquitetura Modular

#### 🌾 MÓDULO COMMODITIES
Gerenciamento de produtos agrícolas e formação de preços.

**Entidades:**
- `commodities` (6 registros)
- `price_history` (6 registros) 
- `offers` (3 registros)

**Relacionamentos:**
```
commodities (1) ----< price_history (N)
commodities (1) ----< offers (N)
```

#### 📱 MÓDULO WHATSAPP
Interface de comunicação via WhatsApp.

**Entidades:**
- `whatsapp_users` (3 registros)
- `whatsapp_sessions` (2 registros)
- `whatsapp_messages` (0 registros)

#### 📊 MÓDULO ANALYTICS
Observabilidade e métricas do sistema.

**Entidades:**
- `analytics_metrics` (5 registros)
- `agentes_status` (4 registros)

#### ⚙️ MÓDULO SISTEMA
Configurações centrais.

**Entidades:**
- `system_config` (5 registros)

## Esquema Detalhado das Entidades

### commodities
Catálogo de commodities agrícolas (produtos base).

```sql
CREATE TABLE commodities (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    symbol TEXT UNIQUE NOT NULL,           -- Símbolo do produto (ex: SOJA, MILHO)
    name TEXT NOT NULL,                    -- Nome completo
    category TEXT NOT NULL,                -- Categoria (grãos, carnes, etc)
    unit TEXT NOT NULL,                    -- Unidade de medida
    exchange TEXT,                         -- Bolsa de valores
    active BOOLEAN DEFAULT 1,             -- Status ativo/inativo
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME
);
```

### price_history
Histórico de preços com dados OHLCV para análise técnica.

```sql
CREATE TABLE price_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    commodity_id INTEGER NOT NULL,        -- FK para commodities
    price REAL NOT NULL,                  -- Preço principal
    price_open REAL,                      -- Preço de abertura
    price_high REAL,                      -- Máxima do período
    price_low REAL,                       -- Mínima do período
    price_close REAL,                     -- Preço de fechamento
    volume REAL,                          -- Volume negociado
    region TEXT,                          -- Região geográfica
    state TEXT,                           -- Estado
    source TEXT,                          -- Fonte dos dados
    timestamp DATETIME NOT NULL,          -- Data/hora do preço
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (commodity_id) REFERENCES commodities(id)
);
```

### offers
Ofertas de compra/venda de commodities com validade.

```sql
CREATE TABLE offers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    commodity_id INTEGER NOT NULL,        -- FK para commodities
    offer_type TEXT NOT NULL,             -- 'buy' ou 'sell'
    quantity REAL NOT NULL,               -- Quantidade oferecida
    price REAL NOT NULL,                  -- Preço da oferta
    unit TEXT NOT NULL,                   -- Unidade
    region TEXT,                          -- Região
    state TEXT,                           -- Estado
    contact_phone TEXT,                   -- Contato
    contact_name TEXT,                    -- Nome do contato
    status TEXT DEFAULT 'active',        -- Status da oferta
    valid_until DATETIME,                -- Data de expiração
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (commodity_id) REFERENCES commodities(id)
);
```

### whatsapp_users
Usuários cadastrados no WhatsApp com preferências.

```sql
CREATE TABLE whatsapp_users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    phone_number TEXT UNIQUE NOT NULL,    -- Número do WhatsApp
    name TEXT,                            -- Nome do usuário
    user_type TEXT,                       -- Tipo de usuário
    preferred_commodities TEXT,           -- Commodities de interesse
    notification_frequency TEXT DEFAULT 'daily', -- Frequência de notificações
    active BOOLEAN DEFAULT 1,            -- Status ativo
    region TEXT,                          -- Região do usuário
    state TEXT,                           -- Estado
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_interaction DATETIME             -- Última interação
);
```

## Índices de Performance

```sql
-- Busca eficiente de métricas por tipo e data
CREATE INDEX idx_analytics_metrics_type_timestamp 
ON analytics_metrics(metric_type, timestamp DESC);

-- Busca rápida de ofertas ativas
CREATE INDEX idx_offers_status_valid 
ON offers(status, valid_until) WHERE status = 'active';

-- Consulta de histórico de preços por commodity
CREATE INDEX idx_price_history_commodity_timestamp 
ON price_history(commodity_id, timestamp DESC);
```

## Regras de Negócio Identificadas

### 1. Gestão de Ofertas
- ✅ **Validade limitada**: Ofertas possuem `valid_until` para expiração automática
- ✅ **Status controlado**: Campo `status` permite ativação/desativação
- ✅ **Regionalização**: Ofertas são específicas por região/estado

### 2. Controle de Commodities
- ✅ **Ativação/Desativação**: Campo `active` controla disponibilidade
- ✅ **Símbolos únicos**: Constraint UNIQUE em `symbol`
- ✅ **Categorização**: Organização por categorias de produtos

### 3. Personalização WhatsApp
- ✅ **Preferências**: Usuários têm `preferred_commodities`
- ✅ **Frequência**: Controle de `notification_frequency`
- ✅ **Regionalização**: Notificações podem ser regionalizadas

### 4. Análise de Preços
- ✅ **OHLCV completo**: Suporte para análise técnica
- ✅ **Múltiplas fontes**: Campo `source` para rastreabilidade
- ✅ **Timestamp preciso**: Controle temporal dos preços

## Arquitetura de Deploy

### Ambiente Atual (SQLite)
```
spr-project/
├── data/
│   └── spr_central.db    ← Banco principal
└── apps/
    ├── backend/          ← API Python
    └── frontend/         ← React App
```

### Arquitetura Planejada (PostgreSQL)
```yaml
services:
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: spr_db
      POSTGRES_USER: spr_user
      POSTGRES_PASSWORD: spr_password
  
  spr-backend:
    environment:
      DATABASE_URL: postgresql://spr_user:spr_password@postgres:5432/spr_db
```

## Scripts de Migração Identificados

### 1. PostgreSQL Setup
- **Local**: `/home/cadu/projeto_SPR/database/init.sql`
- **Funcionalidades**:
  - Criação de usuário `spr_user`
  - Configuração de timezone (America/Cuiaba)
  - Otimizações de performance
  - Triggers para auditoria

### 2. Migration Manager
- **Local**: `/home/cadu/projeto_SPR/database/migrations/migration_manager.py`
- **Recursos**:
  - Zero-downtime migrations
  - Rollback automático
  - Lock distribuído via Redis
  - Múltiplas estratégias (online, shadow table, dual-write)

## Monitoramento e Backup

### Métricas do Sistema
A tabela `analytics_metrics` captura:
- Performance de agentes
- Métricas de uso
- Indicadores de saúde

### Status dos Agentes
A tabela `agentes_status` monitora:
- Status de conectividade
- Score de performance
- Sessões ativas
- Metadados de execução

## Recomendações Operacionais

### 1. Backup Strategy
```bash
# SQLite backup atual
sqlite3 /path/to/spr_central.db ".backup backup_$(date +%Y%m%d_%H%M%S).db"

# PostgreSQL backup futuro
pg_dump -h postgres -U spr_user spr_db > backup_$(date +%Y%m%d_%H%M%S).sql
```

### 2. Replicação
- **Atual**: Não implementada
- **Recomendado**: PostgreSQL streaming replication para HA

### 3. Monitoramento
- **Conexões**: Monitorar conexões ativas
- **Locks**: Alertas para locks de longa duração  
- **Replication lag**: Se implementar replicação
- **Tamanho do banco**: Crescimento das tabelas principais

### 4. Manutenção
```sql
-- SQLite maintenance
VACUUM;
ANALYZE;

-- PostgreSQL maintenance
VACUUM ANALYZE;
REINDEX;
```

## Arquivo de Configuração

Os schemas completos estão salvos em:
- **DDL Principal**: `/home/cadu/SPRNOVO/db/ddl_spr_central.sql`
- **Schemas Individuais**: `/home/cadu/SPRNOVO/db/sqlite_schemas/`
- **Relatório de Extração**: `/home/cadu/SPRNOVO/db/sqlite_extraction_report.txt`
- **Análise JSON**: `/home/cadu/SPRNOVO/db/database_analysis.json`

---

**Gerado em**: $(date)  
**Versão**: SPR 1.1  
**Status**: Estrutura atual mapeada - Pronto para migração PostgreSQL