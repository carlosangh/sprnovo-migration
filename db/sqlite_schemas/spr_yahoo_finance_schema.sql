-- Schema extraído de: /home/cadu/projeto_SPR/spr_yahoo_finance.db
-- Data: 1754780417.3923993

CREATE INDEX ix_prices_granularity_ts ON prices (granularity, ts);

CREATE INDEX ix_prices_symbol_ts ON prices (symbol_id, ts);

CREATE TABLE commodities (
	id INTEGER NOT NULL, 
	code VARCHAR(20) NOT NULL, 
	name VARCHAR(100) NOT NULL, 
	PRIMARY KEY (id), 
	UNIQUE (code)
);

CREATE TABLE markets (
	id INTEGER NOT NULL, 
	code VARCHAR(20) NOT NULL, 
	name VARCHAR(100) NOT NULL, 
	timezone VARCHAR(50) NOT NULL, 
	PRIMARY KEY (id), 
	UNIQUE (code)
);

CREATE TABLE prices (
	id INTEGER NOT NULL, 
	symbol_id INTEGER NOT NULL, 
	ts DATETIME NOT NULL, 
	granularity VARCHAR(10) NOT NULL, 
	open FLOAT, 
	high FLOAT, 
	low FLOAT, 
	close FLOAT NOT NULL, 
	adj_close FLOAT, 
	volume FLOAT, 
	source VARCHAR(20) NOT NULL, 
	created_at DATETIME NOT NULL, 
	updated_at DATETIME NOT NULL, 
	PRIMARY KEY (id), 
	CONSTRAINT uq_prices_symbol_ts_granularity UNIQUE (symbol_id, ts, granularity), 
	FOREIGN KEY(symbol_id) REFERENCES symbols (id)
);

CREATE TABLE symbols (
	id INTEGER NOT NULL, 
	commodity_id INTEGER NOT NULL, 
	market_id INTEGER NOT NULL, 
	yf_symbol VARCHAR(20) NOT NULL, 
	currency VARCHAR(10) NOT NULL, 
	mic VARCHAR(10), 
	is_active BOOLEAN NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(commodity_id) REFERENCES commodities (id), 
	FOREIGN KEY(market_id) REFERENCES markets (id), 
	UNIQUE (yf_symbol)
);

-- INFORMAÇÕES DAS TABELAS

-- Tabela: markets
-- Registros: 5
-- Colunas:
--   id INTEGER NOT NULL PRIMARY KEY
--   code VARCHAR(20) NOT NULL 
--   name VARCHAR(100) NOT NULL 
--   timezone VARCHAR(50) NOT NULL 

-- Tabela: commodities
-- Registros: 8
-- Colunas:
--   id INTEGER NOT NULL PRIMARY KEY
--   code VARCHAR(20) NOT NULL 
--   name VARCHAR(100) NOT NULL 

-- Tabela: symbols
-- Registros: 8
-- Colunas:
--   id INTEGER NOT NULL PRIMARY KEY
--   commodity_id INTEGER NOT NULL 
--   market_id INTEGER NOT NULL 
--   yf_symbol VARCHAR(20) NOT NULL 
--   currency VARCHAR(10) NOT NULL 
--   mic VARCHAR(10) NULL 
--   is_active BOOLEAN NOT NULL 

-- Tabela: prices
-- Registros: 0
-- Colunas:
--   id INTEGER NOT NULL PRIMARY KEY
--   symbol_id INTEGER NOT NULL 
--   ts DATETIME NOT NULL 
--   granularity VARCHAR(10) NOT NULL 
--   open FLOAT NULL 
--   high FLOAT NULL 
--   low FLOAT NULL 
--   close FLOAT NOT NULL 
--   adj_close FLOAT NULL 
--   volume FLOAT NULL 
--   source VARCHAR(20) NOT NULL 
--   created_at DATETIME NOT NULL 
--   updated_at DATETIME NOT NULL 
