-- Schema extraído de: /home/cadu/projeto_SPR/data/spr_work.db
-- Data: 1755061209.0914955

CREATE INDEX idx_broadcast_approvals_campaign_status 
    ON broadcast_approvals(campaign_id, status);

CREATE INDEX idx_broadcast_campaigns_creator_status 
    ON broadcast_campaigns(created_by, status);

CREATE INDEX idx_broadcast_campaigns_status_created 
    ON broadcast_campaigns(status, created_at);

CREATE INDEX idx_broadcast_logs_action_entity 
    ON broadcast_logs(action_type, entity_type, entity_id);

CREATE INDEX idx_broadcast_recipients_campaign_status 
    ON broadcast_recipients(campaign_id, message_status);

CREATE INDEX idx_ingest_runs_source_start_time ON ingest_runs(source, start_time);

CREATE INDEX idx_prices_commodity_date ON prices (commodity, timestamp);

CREATE INDEX idx_prices_market_timestamp ON prices(market, timestamp);

CREATE INDEX idx_prices_raw_commodity_timestamp ON prices_raw(commodity, timestamp);

CREATE INDEX idx_prices_raw_source_timestamp ON prices_raw(source, timestamp);

CREATE INDEX idx_prices_source ON prices (source);

CREATE INDEX idx_prices_source_commodity_timestamp ON prices(source, commodity, timestamp);

CREATE INDEX ix_source_priority_type_priority ON source_priority (data_type, priority);

CREATE INDEX ix_us_cftc_data_commodity_date ON us_cftc_data (commodity_code, report_date);

CREATE INDEX ix_us_cftc_data_date ON us_cftc_data (report_date);

CREATE INDEX ix_us_cftc_data_hash ON us_cftc_data (hash);

CREATE INDEX ix_us_drought_data_hash ON us_drought_data (hash);

CREATE INDEX ix_us_drought_data_level_date ON us_drought_data (drought_level, date);

CREATE INDEX ix_us_drought_data_state_date ON us_drought_data (state, date);

CREATE INDEX ix_us_export_sales_commodity_week ON us_export_sales (commodity, week_ending);

CREATE INDEX ix_us_export_sales_destination_week ON us_export_sales (destination, week_ending);

CREATE INDEX ix_us_export_sales_hash ON us_export_sales (hash);

CREATE INDEX ix_us_market_news_commodity_date ON us_market_news (commodity, date);

CREATE INDEX ix_us_market_news_hash ON us_market_news (hash);

CREATE INDEX ix_us_market_news_region_date ON us_market_news (region, date);

CREATE INDEX ix_us_news_category ON us_news (category);

CREATE INDEX ix_us_news_hash ON us_news (hash);

CREATE INDEX ix_us_news_published ON us_news (published_at);

CREATE INDEX ix_us_news_source ON us_news (source);

CREATE INDEX ix_us_reports_date ON us_reports (date);

CREATE INDEX ix_us_reports_hash ON us_reports (hash);

CREATE INDEX ix_us_reports_source_type ON us_reports (source, report_type);

CREATE INDEX ix_us_weather_location_ts ON us_weather (location_code, ts);

CREATE INDEX ix_us_weather_ts ON us_weather (ts);

CREATE TABLE broadcast_approvals (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    campaign_id INTEGER NOT NULL REFERENCES broadcast_campaigns(id) ON DELETE CASCADE,
    approver_username VARCHAR(100) NOT NULL,
    approver_role VARCHAR(50) NOT NULL,
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN (
        'pending', 'approved', 'rejected', 'cancelled'
    )),
    decision_reason TEXT,
    original_message TEXT,
    edited_message TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    decided_at DATETIME,
    
    -- Constraint único
    UNIQUE (campaign_id, approver_username)
);

CREATE TABLE broadcast_campaigns (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name VARCHAR(200) NOT NULL,
    message_content TEXT NOT NULL,
    group_id INTEGER NOT NULL REFERENCES broadcast_groups(id) ON DELETE CASCADE,
    status VARCHAR(50) DEFAULT 'draft' CHECK (status IN (
        'draft', 'pending_approval', 'approved', 'rejected', 
        'scheduled', 'sending', 'sent', 'failed', 'cancelled'
    )),
    priority VARCHAR(20) DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high')),
    scheduled_for DATETIME,
    send_immediately BOOLEAN DEFAULT 0,
    max_recipients INTEGER DEFAULT 50,
    created_by VARCHAR(100) NOT NULL,
    created_by_role VARCHAR(50),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME,
    sent_at DATETIME,
    total_recipients INTEGER DEFAULT 0,
    messages_sent INTEGER DEFAULT 0,
    messages_delivered INTEGER DEFAULT 0,
    messages_failed INTEGER DEFAULT 0,
    change_log TEXT -- JSON como TEXT no SQLite
);

CREATE TABLE broadcast_groups (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    contact_filter TEXT, -- JSON como TEXT no SQLite
    manual_contacts TEXT, -- JSON como TEXT no SQLite
    auto_approve BOOLEAN DEFAULT 0,
    active BOOLEAN DEFAULT 1,
    created_by VARCHAR(100),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME
);

CREATE TABLE broadcast_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    action_type VARCHAR(50) NOT NULL,
    entity_type VARCHAR(50) NOT NULL,
    entity_id INTEGER NOT NULL,
    username VARCHAR(100) NOT NULL,
    user_role VARCHAR(50),
    user_ip VARCHAR(45),
    description TEXT NOT NULL,
    old_data TEXT, -- JSON como TEXT no SQLite
    new_data TEXT, -- JSON como TEXT no SQLite
    metadata TEXT, -- JSON como TEXT no SQLite
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE broadcast_recipients (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    campaign_id INTEGER NOT NULL REFERENCES broadcast_campaigns(id) ON DELETE CASCADE,
    phone_number VARCHAR(20) NOT NULL,
    contact_name VARCHAR(100),
    message_status VARCHAR(20) DEFAULT 'pending' CHECK (message_status IN (
        'pending', 'sent', 'delivered', 'read', 'failed'
    )),
    sent_at DATETIME,
    delivered_at DATETIME,
    read_at DATETIME,
    whatsapp_message_id VARCHAR(100),
    error_message TEXT,
    send_attempts INTEGER DEFAULT 0,
    last_attempt_at DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME
);

CREATE TABLE commodities (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    code TEXT,
    category TEXT,                  -- 'GRAOS', 'CARNES', 'ACUCAR'
    active BOOLEAN DEFAULT TRUE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE ingest_runs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    source TEXT NOT NULL,
    start_time DATETIME NOT NULL,
    end_time DATETIME,
    status TEXT DEFAULT 'running',  -- 'running', 'completed', 'failed'
    records_processed INTEGER DEFAULT 0,
    records_inserted INTEGER DEFAULT 0,
    records_updated INTEGER DEFAULT 0,
    error_message TEXT,
    metadata TEXT,                  -- JSON com informações extras
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE markets (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    code TEXT,
    state TEXT,
    region TEXT,
    active BOOLEAN DEFAULT TRUE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE prices (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    source TEXT NOT NULL,
    commodity TEXT NOT NULL,
    market TEXT,
    price REAL,
    unit TEXT,                     -- 'BRL/SC', 'USD/BUSHEL', etc
    currency TEXT DEFAULT 'BRL',
    timestamp DATETIME NOT NULL,
    quality_score REAL DEFAULT 1.0, -- score de qualidade do dado
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    raw_data_id INTEGER,
    FOREIGN KEY(raw_data_id) REFERENCES prices_raw(id),
    UNIQUE(source, commodity, market, timestamp)
);

CREATE TABLE prices_raw (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    source TEXT NOT NULL,          -- 'CEPEA', 'BCB', 'INMET'
    commodity TEXT NOT NULL,       -- nome da commodity
    market TEXT,                   -- mercado/região
    raw_data TEXT NOT NULL,        -- dados JSON brutos
    timestamp DATETIME NOT NULL,   -- timestamp original do dado
    ingested_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    processed BOOLEAN DEFAULT FALSE,
    UNIQUE(source, commodity, market, timestamp)
);

CREATE TABLE schema_migrations (
                    id TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );

CREATE TABLE source_priority (
	id INTEGER NOT NULL, 
	data_type VARCHAR(50) NOT NULL, 
	source VARCHAR(50) NOT NULL, 
	priority INTEGER NOT NULL, 
	is_active VARCHAR(5), 
	created_at DATETIME, 
	PRIMARY KEY (id), 
	CONSTRAINT uq_source_priority_type_source UNIQUE (data_type, source)
);

CREATE TABLE sqlite_sequence(name,seq);

CREATE TABLE us_cftc_data (
	id INTEGER NOT NULL, 
	report_date DATETIME NOT NULL, 
	commodity_code VARCHAR(20) NOT NULL, 
	commodity_name VARCHAR(50) NOT NULL, 
	commercial_long INTEGER, 
	commercial_short INTEGER, 
	noncommercial_long INTEGER, 
	noncommercial_short INTEGER, 
	nonreportable_long INTEGER, 
	nonreportable_short INTEGER, 
	open_interest INTEGER, 
	data JSON NOT NULL, 
	hash VARCHAR(40) NOT NULL, 
	created_at DATETIME, 
	PRIMARY KEY (id), 
	UNIQUE (hash)
);

CREATE TABLE us_drought_data (
	id INTEGER NOT NULL, 
	date DATETIME NOT NULL, 
	state VARCHAR(10) NOT NULL, 
	county VARCHAR(50), 
	drought_level INTEGER, 
	area_percent FLOAT, 
	data_type VARCHAR(20), 
	data JSON NOT NULL, 
	hash VARCHAR(40) NOT NULL, 
	created_at DATETIME, 
	PRIMARY KEY (id), 
	UNIQUE (hash)
);

CREATE TABLE us_export_sales (
	id INTEGER NOT NULL, 
	commodity VARCHAR(30) NOT NULL, 
	destination VARCHAR(50) NOT NULL, 
	week_ending DATETIME NOT NULL, 
	net_sales FLOAT, 
	exports FLOAT, 
	outstanding_sales FLOAT, 
	unit VARCHAR(20), 
	marketing_year VARCHAR(10), 
	data JSON NOT NULL, 
	hash VARCHAR(40) NOT NULL, 
	created_at DATETIME, 
	PRIMARY KEY (id), 
	UNIQUE (hash)
);

CREATE TABLE us_market_news (
	id INTEGER NOT NULL, 
	report_type VARCHAR(50) NOT NULL, 
	commodity VARCHAR(30) NOT NULL, 
	region VARCHAR(50), 
	date DATETIME NOT NULL, 
	price FLOAT, 
	volume FLOAT, 
	unit VARCHAR(20), 
	grade VARCHAR(50), 
	data JSON NOT NULL, 
	hash VARCHAR(40) NOT NULL, 
	created_at DATETIME, 
	PRIMARY KEY (id), 
	UNIQUE (hash)
);

CREATE TABLE us_news (
	id INTEGER NOT NULL, 
	source VARCHAR(50) NOT NULL, 
	title TEXT NOT NULL, 
	summary TEXT, 
	url TEXT NOT NULL, 
	published_at DATETIME NOT NULL, 
	category VARCHAR(30), 
	language VARCHAR(5), 
	hash VARCHAR(40) NOT NULL, 
	created_at DATETIME, 
	PRIMARY KEY (id), 
	UNIQUE (hash)
);

CREATE TABLE us_reports (
	id INTEGER NOT NULL, 
	source VARCHAR(50) NOT NULL, 
	report_type VARCHAR(50) NOT NULL, 
	date DATETIME NOT NULL, 
	data JSON NOT NULL, 
	hash VARCHAR(40) NOT NULL, 
	created_at DATETIME, 
	updated_at DATETIME, 
	PRIMARY KEY (id), 
	UNIQUE (hash)
);

CREATE TABLE us_weather (
	id INTEGER NOT NULL, 
	location_code VARCHAR(50) NOT NULL, 
	ts DATETIME NOT NULL, 
	"temp" FLOAT, 
	precip FLOAT, 
	wind FLOAT, 
	humidity FLOAT, 
	alert_code VARCHAR(10), 
	data JSON NOT NULL, 
	created_at DATETIME, 
	PRIMARY KEY (id), 
	CONSTRAINT uq_us_weather_location_ts UNIQUE (location_code, ts)
);

-- INFORMAÇÕES DAS TABELAS

-- Tabela: us_reports
-- Registros: 0
-- Colunas:
--   id INTEGER NOT NULL PRIMARY KEY
--   source VARCHAR(50) NOT NULL 
--   report_type VARCHAR(50) NOT NULL 
--   date DATETIME NOT NULL 
--   data JSON NOT NULL 
--   hash VARCHAR(40) NOT NULL 
--   created_at DATETIME NULL 
--   updated_at DATETIME NULL 

-- Tabela: us_weather
-- Registros: 0
-- Colunas:
--   id INTEGER NOT NULL PRIMARY KEY
--   location_code VARCHAR(50) NOT NULL 
--   ts DATETIME NOT NULL 
--   temp FLOAT NULL 
--   precip FLOAT NULL 
--   wind FLOAT NULL 
--   humidity FLOAT NULL 
--   alert_code VARCHAR(10) NULL 
--   data JSON NOT NULL 
--   created_at DATETIME NULL 

-- Tabela: us_news
-- Registros: 0
-- Colunas:
--   id INTEGER NOT NULL PRIMARY KEY
--   source VARCHAR(50) NOT NULL 
--   title TEXT NOT NULL 
--   summary TEXT NULL 
--   url TEXT NOT NULL 
--   published_at DATETIME NOT NULL 
--   category VARCHAR(30) NULL 
--   language VARCHAR(5) NULL 
--   hash VARCHAR(40) NOT NULL 
--   created_at DATETIME NULL 

-- Tabela: source_priority
-- Registros: 16
-- Colunas:
--   id INTEGER NOT NULL PRIMARY KEY
--   data_type VARCHAR(50) NOT NULL 
--   source VARCHAR(50) NOT NULL 
--   priority INTEGER NOT NULL 
--   is_active VARCHAR(5) NULL 
--   created_at DATETIME NULL 

-- Tabela: us_market_news
-- Registros: 0
-- Colunas:
--   id INTEGER NOT NULL PRIMARY KEY
--   report_type VARCHAR(50) NOT NULL 
--   commodity VARCHAR(30) NOT NULL 
--   region VARCHAR(50) NULL 
--   date DATETIME NOT NULL 
--   price FLOAT NULL 
--   volume FLOAT NULL 
--   unit VARCHAR(20) NULL 
--   grade VARCHAR(50) NULL 
--   data JSON NOT NULL 
--   hash VARCHAR(40) NOT NULL 
--   created_at DATETIME NULL 

-- Tabela: us_export_sales
-- Registros: 0
-- Colunas:
--   id INTEGER NOT NULL PRIMARY KEY
--   commodity VARCHAR(30) NOT NULL 
--   destination VARCHAR(50) NOT NULL 
--   week_ending DATETIME NOT NULL 
--   net_sales FLOAT NULL 
--   exports FLOAT NULL 
--   outstanding_sales FLOAT NULL 
--   unit VARCHAR(20) NULL 
--   marketing_year VARCHAR(10) NULL 
--   data JSON NOT NULL 
--   hash VARCHAR(40) NOT NULL 
--   created_at DATETIME NULL 

-- Tabela: us_drought_data
-- Registros: 0
-- Colunas:
--   id INTEGER NOT NULL PRIMARY KEY
--   date DATETIME NOT NULL 
--   state VARCHAR(10) NOT NULL 
--   county VARCHAR(50) NULL 
--   drought_level INTEGER NULL 
--   area_percent FLOAT NULL 
--   data_type VARCHAR(20) NULL 
--   data JSON NOT NULL 
--   hash VARCHAR(40) NOT NULL 
--   created_at DATETIME NULL 

-- Tabela: us_cftc_data
-- Registros: 0
-- Colunas:
--   id INTEGER NOT NULL PRIMARY KEY
--   report_date DATETIME NOT NULL 
--   commodity_code VARCHAR(20) NOT NULL 
--   commodity_name VARCHAR(50) NOT NULL 
--   commercial_long INTEGER NULL 
--   commercial_short INTEGER NULL 
--   noncommercial_long INTEGER NULL 
--   noncommercial_short INTEGER NULL 
--   nonreportable_long INTEGER NULL 
--   nonreportable_short INTEGER NULL 
--   open_interest INTEGER NULL 
--   data JSON NOT NULL 
--   hash VARCHAR(40) NOT NULL 
--   created_at DATETIME NULL 

-- Tabela: schema_migrations
-- Registros: 1
-- Colunas:
--   id TEXT NULL PRIMARY KEY
--   name TEXT NOT NULL 
--   applied_at TIMESTAMP NULL 

-- Tabela: broadcast_groups
-- Registros: 6
-- Colunas:
--   id INTEGER NULL PRIMARY KEY
--   name VARCHAR(100) NOT NULL 
--   description TEXT NULL 
--   contact_filter TEXT NULL 
--   manual_contacts TEXT NULL 
--   auto_approve BOOLEAN NULL 
--   active BOOLEAN NULL 
--   created_by VARCHAR(100) NULL 
--   created_at DATETIME NULL 
--   updated_at DATETIME NULL 

-- Tabela: sqlite_sequence
-- Registros: 7
-- Colunas:
--   name  NULL 
--   seq  NULL 

-- Tabela: broadcast_campaigns
-- Registros: 0
-- Colunas:
--   id INTEGER NULL PRIMARY KEY
--   name VARCHAR(200) NOT NULL 
--   message_content TEXT NOT NULL 
--   group_id INTEGER NOT NULL 
--   status VARCHAR(50) NULL 
--   priority VARCHAR(20) NULL 
--   scheduled_for DATETIME NULL 
--   send_immediately BOOLEAN NULL 
--   max_recipients INTEGER NULL 
--   created_by VARCHAR(100) NOT NULL 
--   created_by_role VARCHAR(50) NULL 
--   created_at DATETIME NULL 
--   updated_at DATETIME NULL 
--   sent_at DATETIME NULL 
--   total_recipients INTEGER NULL 
--   messages_sent INTEGER NULL 
--   messages_delivered INTEGER NULL 
--   messages_failed INTEGER NULL 
--   change_log TEXT NULL 

-- Tabela: broadcast_approvals
-- Registros: 0
-- Colunas:
--   id INTEGER NULL PRIMARY KEY
--   campaign_id INTEGER NOT NULL 
--   approver_username VARCHAR(100) NOT NULL 
--   approver_role VARCHAR(50) NOT NULL 
--   status VARCHAR(50) NULL 
--   decision_reason TEXT NULL 
--   original_message TEXT NULL 
--   edited_message TEXT NULL 
--   created_at DATETIME NULL 
--   decided_at DATETIME NULL 

-- Tabela: broadcast_recipients
-- Registros: 0
-- Colunas:
--   id INTEGER NULL PRIMARY KEY
--   campaign_id INTEGER NOT NULL 
--   phone_number VARCHAR(20) NOT NULL 
--   contact_name VARCHAR(100) NULL 
--   message_status VARCHAR(20) NULL 
--   sent_at DATETIME NULL 
--   delivered_at DATETIME NULL 
--   read_at DATETIME NULL 
--   whatsapp_message_id VARCHAR(100) NULL 
--   error_message TEXT NULL 
--   send_attempts INTEGER NULL 
--   last_attempt_at DATETIME NULL 
--   created_at DATETIME NULL 
--   updated_at DATETIME NULL 

-- Tabela: broadcast_logs
-- Registros: 1
-- Colunas:
--   id INTEGER NULL PRIMARY KEY
--   action_type VARCHAR(50) NOT NULL 
--   entity_type VARCHAR(50) NOT NULL 
--   entity_id INTEGER NOT NULL 
--   username VARCHAR(100) NOT NULL 
--   user_role VARCHAR(50) NULL 
--   user_ip VARCHAR(45) NULL 
--   description TEXT NOT NULL 
--   old_data TEXT NULL 
--   new_data TEXT NULL 
--   metadata TEXT NULL 
--   created_at DATETIME NULL 

-- Tabela: prices_raw
-- Registros: 46438
-- Colunas:
--   id INTEGER NULL PRIMARY KEY
--   source TEXT NOT NULL 
--   commodity TEXT NOT NULL 
--   market TEXT NULL 
--   raw_data TEXT NOT NULL 
--   timestamp DATETIME NOT NULL 
--   ingested_at DATETIME NULL 
--   processed BOOLEAN NULL 

-- Tabela: prices
-- Registros: 46438
-- Colunas:
--   id INTEGER NULL PRIMARY KEY
--   source TEXT NOT NULL 
--   commodity TEXT NOT NULL 
--   market TEXT NULL 
--   price REAL NULL 
--   unit TEXT NULL 
--   currency TEXT NULL 
--   timestamp DATETIME NOT NULL 
--   quality_score REAL NULL 
--   created_at DATETIME NULL 
--   updated_at DATETIME NULL 
--   raw_data_id INTEGER NULL 

-- Tabela: ingest_runs
-- Registros: 7
-- Colunas:
--   id INTEGER NULL PRIMARY KEY
--   source TEXT NOT NULL 
--   start_time DATETIME NOT NULL 
--   end_time DATETIME NULL 
--   status TEXT NULL 
--   records_processed INTEGER NULL 
--   records_inserted INTEGER NULL 
--   records_updated INTEGER NULL 
--   error_message TEXT NULL 
--   metadata TEXT NULL 
--   created_at DATETIME NULL 

-- Tabela: commodities
-- Registros: 7
-- Colunas:
--   id INTEGER NULL PRIMARY KEY
--   name TEXT NOT NULL 
--   code TEXT NULL 
--   category TEXT NULL 
--   active BOOLEAN NULL 
--   created_at DATETIME NULL 

-- Tabela: markets
-- Registros: 8
-- Colunas:
--   id INTEGER NULL PRIMARY KEY
--   name TEXT NOT NULL 
--   code TEXT NULL 
--   state TEXT NULL 
--   region TEXT NULL 
--   active BOOLEAN NULL 
--   created_at DATETIME NULL 
