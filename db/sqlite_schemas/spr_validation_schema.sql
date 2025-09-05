-- Schema extraído de: /home/cadu/projeto_SPR/spr_validation.db
-- Data: 1754829572.2210488

CREATE INDEX idx_ingest_runs_source_status ON ingest_runs(source, status, started_at DESC);

CREATE INDEX idx_prices_commodity_timestamp ON prices(commodity, timestamp DESC);

CREATE INDEX idx_prices_raw_commodity_timestamp ON prices_raw(commodity, timestamp DESC);

CREATE INDEX idx_prices_raw_source ON prices_raw(source, timestamp DESC);

CREATE TABLE commodities (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    symbol VARCHAR(20) UNIQUE NOT NULL,
    name VARCHAR(200) NOT NULL,
    category VARCHAR(100) NOT NULL,
    unit VARCHAR(50) NOT NULL,
    exchange VARCHAR(100),
    description TEXT,
    metadata TEXT DEFAULT "{}",
    active BOOLEAN DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE ingest_runs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    source VARCHAR(100) NOT NULL,
    run_type VARCHAR(50) NOT NULL,
    status VARCHAR(50) NOT NULL,
    started_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    finished_at DATETIME,
    records_processed INTEGER DEFAULT 0,
    records_inserted INTEGER DEFAULT 0,
    records_updated INTEGER DEFAULT 0,
    error_message TEXT,
    metadata TEXT DEFAULT "{}"
);

CREATE TABLE prices (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    commodity VARCHAR(100) NOT NULL,
    market VARCHAR(200),
    price_open REAL,
    price_high REAL,
    price_low REAL,
    price_close REAL NOT NULL,
    volume REAL,
    avg_price REAL,
    region VARCHAR(200),
    state VARCHAR(100),
    source VARCHAR(100) NOT NULL,
    timestamp DATETIME NOT NULL,
    price_currency VARCHAR(10) DEFAULT "BRL",
    confidence_level INTEGER,
    outlier_flag BOOLEAN DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE prices_raw (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    commodity VARCHAR(100) NOT NULL,
    market VARCHAR(200),
    price REAL NOT NULL,
    price_currency VARCHAR(10) DEFAULT "BRL",
    volume REAL,
    region VARCHAR(200),
    state VARCHAR(100),
    source VARCHAR(100) NOT NULL,
    timestamp DATETIME NOT NULL,
    collection_timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    quality_score INTEGER,
    raw_data TEXT DEFAULT "{}",
    processed BOOLEAN DEFAULT 0
);

CREATE TABLE sqlite_sequence(name,seq);

-- INFORMAÇÕES DAS TABELAS

-- Tabela: commodities
-- Registros: 6
-- Colunas:
--   id INTEGER NULL PRIMARY KEY
--   symbol VARCHAR(20) NOT NULL 
--   name VARCHAR(200) NOT NULL 
--   category VARCHAR(100) NOT NULL 
--   unit VARCHAR(50) NOT NULL 
--   exchange VARCHAR(100) NULL 
--   description TEXT NULL 
--   metadata TEXT NULL 
--   active BOOLEAN NULL 
--   created_at DATETIME NULL 
--   updated_at DATETIME NULL 

-- Tabela: sqlite_sequence
-- Registros: 1
-- Colunas:
--   name  NULL 
--   seq  NULL 

-- Tabela: prices_raw
-- Registros: 0
-- Colunas:
--   id INTEGER NULL PRIMARY KEY
--   commodity VARCHAR(100) NOT NULL 
--   market VARCHAR(200) NULL 
--   price REAL NOT NULL 
--   price_currency VARCHAR(10) NULL 
--   volume REAL NULL 
--   region VARCHAR(200) NULL 
--   state VARCHAR(100) NULL 
--   source VARCHAR(100) NOT NULL 
--   timestamp DATETIME NOT NULL 
--   collection_timestamp DATETIME NULL 
--   quality_score INTEGER NULL 
--   raw_data TEXT NULL 
--   processed BOOLEAN NULL 

-- Tabela: prices
-- Registros: 0
-- Colunas:
--   id INTEGER NULL PRIMARY KEY
--   commodity VARCHAR(100) NOT NULL 
--   market VARCHAR(200) NULL 
--   price_open REAL NULL 
--   price_high REAL NULL 
--   price_low REAL NULL 
--   price_close REAL NOT NULL 
--   volume REAL NULL 
--   avg_price REAL NULL 
--   region VARCHAR(200) NULL 
--   state VARCHAR(100) NULL 
--   source VARCHAR(100) NOT NULL 
--   timestamp DATETIME NOT NULL 
--   price_currency VARCHAR(10) NULL 
--   confidence_level INTEGER NULL 
--   outlier_flag BOOLEAN NULL 
--   created_at DATETIME NULL 
--   updated_at DATETIME NULL 

-- Tabela: ingest_runs
-- Registros: 0
-- Colunas:
--   id INTEGER NULL PRIMARY KEY
--   source VARCHAR(100) NOT NULL 
--   run_type VARCHAR(50) NOT NULL 
--   status VARCHAR(50) NOT NULL 
--   started_at DATETIME NULL 
--   finished_at DATETIME NULL 
--   records_processed INTEGER NULL 
--   records_inserted INTEGER NULL 
--   records_updated INTEGER NULL 
--   error_message TEXT NULL 
--   metadata TEXT NULL 
