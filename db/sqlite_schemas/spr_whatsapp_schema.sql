-- Schema extraído de: /home/cadu/projeto_SPR/spr_whatsapp.db
-- Data: 1755062951.8461554

CREATE TABLE commodities_cache (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                commodity TEXT NOT NULL,
                region TEXT,
                price REAL,
                currency TEXT DEFAULT 'BRL',
                unit TEXT,
                source TEXT NOT NULL,
                data TEXT,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                expires_at DATETIME
            );

CREATE TABLE messages (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                session_id TEXT NOT NULL,
                phone_number TEXT NOT NULL,
                contact_name TEXT,
                message_body TEXT NOT NULL,
                message_type TEXT DEFAULT 'received',
                roy_response TEXT,
                intent TEXT,
                needs_human BOOLEAN DEFAULT 0,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                processed_at DATETIME,
                status TEXT DEFAULT 'pending'
            );

CREATE TABLE sessions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                session_id TEXT UNIQUE NOT NULL,
                phone_number TEXT,
                status TEXT DEFAULT 'disconnected',
                qr_code TEXT,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                last_activity DATETIME DEFAULT CURRENT_TIMESTAMP
            );

CREATE TABLE sqlite_sequence(name,seq);

CREATE TABLE system_logs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                level TEXT NOT NULL,
                component TEXT NOT NULL,
                message TEXT NOT NULL,
                data TEXT,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            );

-- INFORMAÇÕES DAS TABELAS

-- Tabela: messages
-- Registros: 0
-- Colunas:
--   id INTEGER NULL PRIMARY KEY
--   session_id TEXT NOT NULL 
--   phone_number TEXT NOT NULL 
--   contact_name TEXT NULL 
--   message_body TEXT NOT NULL 
--   message_type TEXT NULL 
--   roy_response TEXT NULL 
--   intent TEXT NULL 
--   needs_human BOOLEAN NULL 
--   created_at DATETIME NULL 
--   processed_at DATETIME NULL 
--   status TEXT NULL 

-- Tabela: sqlite_sequence
-- Registros: 2
-- Colunas:
--   name  NULL 
--   seq  NULL 

-- Tabela: sessions
-- Registros: 1
-- Colunas:
--   id INTEGER NULL PRIMARY KEY
--   session_id TEXT NOT NULL 
--   phone_number TEXT NULL 
--   status TEXT NULL 
--   qr_code TEXT NULL 
--   created_at DATETIME NULL 
--   last_activity DATETIME NULL 

-- Tabela: system_logs
-- Registros: 2441
-- Colunas:
--   id INTEGER NULL PRIMARY KEY
--   level TEXT NOT NULL 
--   component TEXT NOT NULL 
--   message TEXT NOT NULL 
--   data TEXT NULL 
--   created_at DATETIME NULL 

-- Tabela: commodities_cache
-- Registros: 0
-- Colunas:
--   id INTEGER NULL PRIMARY KEY
--   commodity TEXT NOT NULL 
--   region TEXT NULL 
--   price REAL NULL 
--   currency TEXT NULL 
--   unit TEXT NULL 
--   source TEXT NOT NULL 
--   data TEXT NULL 
--   created_at DATETIME NULL 
--   expires_at DATETIME NULL 
