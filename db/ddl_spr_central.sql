-- Schema extraído de: /home/cadu/spr-project/data/spr_central.db
-- Data: 1756835521.472481

CREATE INDEX idx_analytics_metrics_type_timestamp 
            ON analytics_metrics(metric_type, timestamp DESC);

CREATE INDEX idx_offers_status_valid 
            ON offers(status, valid_until) WHERE status = 'active';

CREATE INDEX idx_price_history_commodity_timestamp 
            ON price_history(commodity_id, timestamp DESC);

CREATE TABLE agentes_status (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                agent_name TEXT NOT NULL,
                status TEXT NOT NULL,
                last_ping DATETIME,
                performance_score REAL DEFAULT 0.0,
                active_sessions INTEGER DEFAULT 0,
                metadata TEXT,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            );

CREATE TABLE analytics_metrics (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                metric_type TEXT NOT NULL,
                metric_name TEXT NOT NULL,
                metric_value REAL NOT NULL,
                metadata TEXT,
                timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
            );

CREATE TABLE commodities (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                symbol TEXT UNIQUE NOT NULL,
                name TEXT NOT NULL,
                category TEXT NOT NULL,
                unit TEXT NOT NULL,
                exchange TEXT,
                active BOOLEAN DEFAULT 1,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME
            );

CREATE TABLE offers (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                commodity_id INTEGER NOT NULL,
                offer_type TEXT NOT NULL,
                quantity REAL NOT NULL,
                price REAL NOT NULL,
                unit TEXT NOT NULL,
                region TEXT,
                state TEXT,
                contact_phone TEXT,
                contact_name TEXT,
                status TEXT DEFAULT 'active',
                valid_until DATETIME,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (commodity_id) REFERENCES commodities(id)
            );

CREATE TABLE price_history (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                commodity_id INTEGER NOT NULL,
                price REAL NOT NULL,
                price_open REAL,
                price_high REAL,
                price_low REAL,
                price_close REAL,
                volume REAL,
                region TEXT,
                state TEXT,
                source TEXT,
                timestamp DATETIME NOT NULL,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (commodity_id) REFERENCES commodities(id)
            );

CREATE TABLE sqlite_sequence(name,seq);

CREATE TABLE system_config (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                config_key TEXT UNIQUE NOT NULL,
                config_value TEXT NOT NULL,
                config_type TEXT DEFAULT 'string',
                description TEXT,
                updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
            );

CREATE TABLE whatsapp_messages (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                from_number TEXT,
                to_number TEXT,
                message_type TEXT DEFAULT 'text',
                content TEXT,
                status TEXT DEFAULT 'pending',
                timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
                delivered_at DATETIME,
                read_at DATETIME
            );

CREATE TABLE whatsapp_sessions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                session_id TEXT UNIQUE NOT NULL,
                status TEXT DEFAULT 'disconnected',
                qr_code TEXT,
                last_ping DATETIME,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            );

CREATE TABLE whatsapp_users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                phone_number TEXT UNIQUE NOT NULL,
                name TEXT,
                user_type TEXT,
                preferred_commodities TEXT,
                notification_frequency TEXT DEFAULT 'daily',
                active BOOLEAN DEFAULT 1,
                region TEXT,
                state TEXT,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                last_interaction DATETIME
            );

-- INFORMAÇÕES DAS TABELAS

-- Tabela: commodities
-- Registros: 6
-- Colunas:
--   id INTEGER NULL PRIMARY KEY
--   symbol TEXT NOT NULL 
--   name TEXT NOT NULL 
--   category TEXT NOT NULL 
--   unit TEXT NOT NULL 
--   exchange TEXT NULL 
--   active BOOLEAN NULL 
--   created_at DATETIME NULL 
--   updated_at DATETIME NULL 

-- Tabela: sqlite_sequence
-- Registros: 8
-- Colunas:
--   name  NULL 
--   seq  NULL 

-- Tabela: price_history
-- Registros: 6
-- Colunas:
--   id INTEGER NULL PRIMARY KEY
--   commodity_id INTEGER NOT NULL 
--   price REAL NOT NULL 
--   price_open REAL NULL 
--   price_high REAL NULL 
--   price_low REAL NULL 
--   price_close REAL NULL 
--   volume REAL NULL 
--   region TEXT NULL 
--   state TEXT NULL 
--   source TEXT NULL 
--   timestamp DATETIME NOT NULL 
--   created_at DATETIME NULL 

-- Tabela: whatsapp_users
-- Registros: 3
-- Colunas:
--   id INTEGER NULL PRIMARY KEY
--   phone_number TEXT NOT NULL 
--   name TEXT NULL 
--   user_type TEXT NULL 
--   preferred_commodities TEXT NULL 
--   notification_frequency TEXT NULL 
--   active BOOLEAN NULL 
--   region TEXT NULL 
--   state TEXT NULL 
--   created_at DATETIME NULL 
--   last_interaction DATETIME NULL 

-- Tabela: whatsapp_sessions
-- Registros: 2
-- Colunas:
--   id INTEGER NULL PRIMARY KEY
--   session_id TEXT NOT NULL 
--   status TEXT NULL 
--   qr_code TEXT NULL 
--   last_ping DATETIME NULL 
--   created_at DATETIME NULL 

-- Tabela: offers
-- Registros: 3
-- Colunas:
--   id INTEGER NULL PRIMARY KEY
--   commodity_id INTEGER NOT NULL 
--   offer_type TEXT NOT NULL 
--   quantity REAL NOT NULL 
--   price REAL NOT NULL 
--   unit TEXT NOT NULL 
--   region TEXT NULL 
--   state TEXT NULL 
--   contact_phone TEXT NULL 
--   contact_name TEXT NULL 
--   status TEXT NULL 
--   valid_until DATETIME NULL 
--   created_at DATETIME NULL 

-- Tabela: whatsapp_messages
-- Registros: 0
-- Colunas:
--   id INTEGER NULL PRIMARY KEY
--   from_number TEXT NULL 
--   to_number TEXT NULL 
--   message_type TEXT NULL 
--   content TEXT NULL 
--   status TEXT NULL 
--   timestamp DATETIME NULL 
--   delivered_at DATETIME NULL 
--   read_at DATETIME NULL 

-- Tabela: analytics_metrics
-- Registros: 5
-- Colunas:
--   id INTEGER NULL PRIMARY KEY
--   metric_type TEXT NOT NULL 
--   metric_name TEXT NOT NULL 
--   metric_value REAL NOT NULL 
--   metadata TEXT NULL 
--   timestamp DATETIME NULL 

-- Tabela: agentes_status
-- Registros: 4
-- Colunas:
--   id INTEGER NULL PRIMARY KEY
--   agent_name TEXT NOT NULL 
--   status TEXT NOT NULL 
--   last_ping DATETIME NULL 
--   performance_score REAL NULL 
--   active_sessions INTEGER NULL 
--   metadata TEXT NULL 
--   created_at DATETIME NULL 

-- Tabela: system_config
-- Registros: 5
-- Colunas:
--   id INTEGER NULL PRIMARY KEY
--   config_key TEXT NOT NULL 
--   config_value TEXT NOT NULL 
--   config_type TEXT NULL 
--   description TEXT NULL 
--   updated_at DATETIME NULL 
