-- Schema extraído de: /home/cadu/ciclologico_production/backend_v2/clg_historical.db
-- Data: 1756867092.6203122

CREATE INDEX idx_api_usage_model_ts ON api_usage (model, ts);

CREATE INDEX idx_api_usage_user_ts ON api_usage (user_id, ts);

CREATE INDEX idx_cot_category_week ON cot (category, week);

CREATE INDEX idx_cot_market_week ON cot (market, week);

CREATE INDEX idx_export_sales_commodity_week ON export_sales (commodity, week);

CREATE INDEX idx_files_user_ts ON files (user_id, ts);

CREATE INDEX idx_ingest_runs_source_ts ON ingest_runs (source_id, ts_start);

CREATE INDEX idx_news_source_ts ON news (source, ts);

CREATE INDEX idx_news_topic_ts ON news (topic, ts);

CREATE INDEX idx_prices_commodity_ts ON prices(commodity, ts);

CREATE INDEX idx_prices_market_ts ON prices(market, ts);

CREATE INDEX idx_prices_source_ts ON prices(source, ts);

CREATE INDEX idx_prices_ts ON prices(ts);

CREATE INDEX idx_weather_metric_ts ON weather (metric, ts);

CREATE INDEX idx_weather_region_ts ON weather (region, ts);

CREATE INDEX ix_api_usage_id ON api_usage (id);

CREATE INDEX ix_api_usage_ts ON api_usage (ts);

CREATE INDEX ix_cot_category ON cot (category);

CREATE INDEX ix_cot_id ON cot (id);

CREATE INDEX ix_cot_market ON cot (market);

CREATE INDEX ix_cot_week ON cot (week);

CREATE INDEX ix_export_sales_commodity ON export_sales (commodity);

CREATE INDEX ix_export_sales_id ON export_sales (id);

CREATE INDEX ix_export_sales_week ON export_sales (week);

CREATE INDEX ix_files_id ON files (id);

CREATE INDEX ix_files_ts ON files (ts);

CREATE INDEX ix_ingest_runs_id ON ingest_runs (id);

CREATE INDEX ix_ingest_runs_ts_start ON ingest_runs (ts_start);

CREATE INDEX ix_news_id ON news (id);

CREATE INDEX ix_news_topic ON news (topic);

CREATE INDEX ix_news_ts ON news (ts);

CREATE INDEX ix_sources_id ON sources (id);

CREATE INDEX ix_sources_kind ON sources (kind);

CREATE UNIQUE INDEX ix_users_email ON users (email);

CREATE INDEX ix_users_id ON users (id);

CREATE INDEX ix_weather_id ON weather (id);

CREATE INDEX ix_weather_metric ON weather (metric);

CREATE INDEX ix_weather_region ON weather (region);

CREATE INDEX ix_weather_ts ON weather (ts);

CREATE TABLE api_usage (
	id BIGINT NOT NULL, 
	ts DATETIME, 
	model TEXT, 
	prompt_tokens INTEGER, 
	completion_tokens INTEGER, 
	total_tokens INTEGER, 
	cost_usd NUMERIC(10, 4), 
	user_id INTEGER, 
	PRIMARY KEY (id), 
	FOREIGN KEY(user_id) REFERENCES users (id)
);

CREATE TABLE cot (
	id BIGINT NOT NULL, 
	week DATE NOT NULL, 
	market TEXT NOT NULL, 
	category TEXT NOT NULL, 
	long INTEGER, 
	short INTEGER, 
	oi INTEGER, 
	source TEXT, 
	PRIMARY KEY (id), 
	CONSTRAINT unique_cot_record UNIQUE (week, market, category, source)
);

CREATE TABLE export_sales (
	id BIGINT NOT NULL, 
	week DATE NOT NULL, 
	commodity TEXT NOT NULL, 
	volume NUMERIC(18, 6), 
	destination TEXT, 
	source TEXT, 
	PRIMARY KEY (id), 
	CONSTRAINT unique_export_sales_record UNIQUE (week, commodity, destination, source)
);

CREATE TABLE files (
	id BIGINT NOT NULL, 
	ts DATETIME, 
	filename TEXT, 
	mime TEXT, 
	path TEXT, 
	size BIGINT, 
	user_id INTEGER, 
	PRIMARY KEY (id), 
	FOREIGN KEY(user_id) REFERENCES users (id)
);

CREATE TABLE ingest_runs (
	id BIGINT NOT NULL, 
	source_id INTEGER, 
	ts_start DATETIME, 
	ts_end DATETIME, 
	ok BOOLEAN, 
	items INTEGER, 
	message TEXT, 
	PRIMARY KEY (id), 
	FOREIGN KEY(source_id) REFERENCES sources (id)
);

CREATE TABLE news (
	id BIGINT NOT NULL, 
	ts DATETIME NOT NULL, 
	title TEXT, 
	url TEXT, 
	topic TEXT, 
	source TEXT, 
	lang TEXT, 
	PRIMARY KEY (id)
);

CREATE TABLE prices (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                ts DATETIME NOT NULL,
                commodity TEXT NOT NULL,
                market TEXT NOT NULL,
                contract TEXT,
                price REAL,
                currency TEXT,
                source TEXT,
                UNIQUE(ts, commodity, market, contract, source)
            );

CREATE TABLE sources (
	id INTEGER NOT NULL, 
	name TEXT NOT NULL, 
	kind TEXT NOT NULL, 
	url TEXT, 
	enabled BOOLEAN, 
	PRIMARY KEY (id), 
	UNIQUE (name)
);

CREATE TABLE sqlite_sequence(name,seq);

CREATE TABLE users (
	id INTEGER NOT NULL, 
	email TEXT NOT NULL, 
	pass_hash TEXT NOT NULL, 
	created_at DATETIME, 
	PRIMARY KEY (id)
);

CREATE TABLE weather (
	id BIGINT NOT NULL, 
	ts DATETIME NOT NULL, 
	region TEXT, 
	metric TEXT, 
	value NUMERIC(18, 6), 
	unit TEXT, 
	source TEXT, 
	PRIMARY KEY (id)
);

-- INFORMAÇÕES DAS TABELAS

-- Tabela: prices
-- Registros: 22566
-- Colunas:
--   id INTEGER NULL PRIMARY KEY
--   ts DATETIME NOT NULL 
--   commodity TEXT NOT NULL 
--   market TEXT NOT NULL 
--   contract TEXT NULL 
--   price REAL NULL 
--   currency TEXT NULL 
--   source TEXT NULL 

-- Tabela: sqlite_sequence
-- Registros: 1
-- Colunas:
--   name  NULL 
--   seq  NULL 

-- Tabela: users
-- Registros: 1
-- Colunas:
--   id INTEGER NOT NULL PRIMARY KEY
--   email TEXT NOT NULL 
--   pass_hash TEXT NOT NULL 
--   created_at DATETIME NULL 

-- Tabela: sources
-- Registros: 5
-- Colunas:
--   id INTEGER NOT NULL PRIMARY KEY
--   name TEXT NOT NULL 
--   kind TEXT NOT NULL 
--   url TEXT NULL 
--   enabled BOOLEAN NULL 

-- Tabela: weather
-- Registros: 0
-- Colunas:
--   id BIGINT NOT NULL PRIMARY KEY
--   ts DATETIME NOT NULL 
--   region TEXT NULL 
--   metric TEXT NULL 
--   value NUMERIC(18, 6) NULL 
--   unit TEXT NULL 
--   source TEXT NULL 

-- Tabela: news
-- Registros: 0
-- Colunas:
--   id BIGINT NOT NULL PRIMARY KEY
--   ts DATETIME NOT NULL 
--   title TEXT NULL 
--   url TEXT NULL 
--   topic TEXT NULL 
--   source TEXT NULL 
--   lang TEXT NULL 

-- Tabela: export_sales
-- Registros: 0
-- Colunas:
--   id BIGINT NOT NULL PRIMARY KEY
--   week DATE NOT NULL 
--   commodity TEXT NOT NULL 
--   volume NUMERIC(18, 6) NULL 
--   destination TEXT NULL 
--   source TEXT NULL 

-- Tabela: cot
-- Registros: 0
-- Colunas:
--   id BIGINT NOT NULL PRIMARY KEY
--   week DATE NOT NULL 
--   market TEXT NOT NULL 
--   category TEXT NOT NULL 
--   long INTEGER NULL 
--   short INTEGER NULL 
--   oi INTEGER NULL 
--   source TEXT NULL 

-- Tabela: api_usage
-- Registros: 0
-- Colunas:
--   id BIGINT NOT NULL PRIMARY KEY
--   ts DATETIME NULL 
--   model TEXT NULL 
--   prompt_tokens INTEGER NULL 
--   completion_tokens INTEGER NULL 
--   total_tokens INTEGER NULL 
--   cost_usd NUMERIC(10, 4) NULL 
--   user_id INTEGER NULL 

-- Tabela: ingest_runs
-- Registros: 0
-- Colunas:
--   id BIGINT NOT NULL PRIMARY KEY
--   source_id INTEGER NULL 
--   ts_start DATETIME NULL 
--   ts_end DATETIME NULL 
--   ok BOOLEAN NULL 
--   items INTEGER NULL 
--   message TEXT NULL 

-- Tabela: files
-- Registros: 0
-- Colunas:
--   id BIGINT NOT NULL PRIMARY KEY
--   ts DATETIME NULL 
--   filename TEXT NULL 
--   mime TEXT NULL 
--   path TEXT NULL 
--   size BIGINT NULL 
--   user_id INTEGER NULL 
