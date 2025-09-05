-- Schema extraído de: /home/cadu/projeto_SPR/spr_broadcast.db
-- Data: 1754016440.121275

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

CREATE INDEX idx_commodity_prediction_date ON price_predictions (commodity_id, prediction_date);

CREATE INDEX idx_commodity_region_timestamp ON price_history (commodity_id, region, timestamp);

CREATE INDEX idx_commodity_target_date ON price_predictions (commodity_id, target_date);

CREATE INDEX idx_commodity_timestamp ON price_history (commodity_id, timestamp);

CREATE INDEX idx_region_timestamp ON weather_data (region, timestamp);

CREATE INDEX idx_source_commodity_timestamp ON government_data (source, commodity, timestamp);

CREATE INDEX idx_source_type_region ON government_data (source, dataset_type, region);

CREATE INDEX idx_station_timestamp ON weather_data (station_id, timestamp);

CREATE INDEX ix_commodities_id ON commodities (id);

CREATE UNIQUE INDEX ix_commodities_symbol ON commodities (symbol);

CREATE INDEX ix_government_data_id ON government_data (id);

CREATE INDEX ix_government_data_timestamp ON government_data (timestamp);

CREATE INDEX ix_market_alerts_id ON market_alerts (id);

CREATE INDEX ix_price_history_id ON price_history (id);

CREATE INDEX ix_price_history_timestamp ON price_history (timestamp);

CREATE INDEX ix_price_predictions_id ON price_predictions (id);

CREATE INDEX ix_weather_data_id ON weather_data (id);

CREATE INDEX ix_weather_data_station_id ON weather_data (station_id);

CREATE INDEX ix_weather_data_timestamp ON weather_data (timestamp);

CREATE INDEX ix_whatsapp_users_id ON whatsapp_users (id);

CREATE UNIQUE INDEX ix_whatsapp_users_phone_number ON whatsapp_users (phone_number);

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
	id INTEGER NOT NULL, 
	symbol VARCHAR(10) NOT NULL, 
	name VARCHAR(100) NOT NULL, 
	category VARCHAR(50) NOT NULL, 
	unit VARCHAR(20) NOT NULL, 
	exchange VARCHAR(50), 
	active BOOLEAN, 
	created_at DATETIME DEFAULT (CURRENT_TIMESTAMP), 
	updated_at DATETIME, 
	PRIMARY KEY (id)
);

CREATE TABLE government_data (
	id INTEGER NOT NULL, 
	source VARCHAR(50) NOT NULL, 
	dataset_type VARCHAR(100) NOT NULL, 
	commodity VARCHAR(50), 
	region VARCHAR(100), 
	state VARCHAR(50), 
	municipality VARCHAR(100), 
	value FLOAT NOT NULL, 
	unit VARCHAR(50), 
	reference_period VARCHAR(50), 
	data_metadata JSON, 
	timestamp DATETIME NOT NULL, 
	created_at DATETIME DEFAULT (CURRENT_TIMESTAMP), 
	PRIMARY KEY (id)
);

CREATE TABLE market_alerts (
	id INTEGER NOT NULL, 
	commodity_id INTEGER NOT NULL, 
	alert_type VARCHAR(50) NOT NULL, 
	threshold_value FLOAT NOT NULL, 
	comparison_period INTEGER, 
	active BOOLEAN, 
	triggered BOOLEAN, 
	last_triggered DATETIME, 
	user_phone VARCHAR(20), 
	user_email VARCHAR(100), 
	notification_method VARCHAR(50), 
	created_at DATETIME DEFAULT (CURRENT_TIMESTAMP), 
	updated_at DATETIME, 
	PRIMARY KEY (id), 
	FOREIGN KEY(commodity_id) REFERENCES commodities (id)
);

CREATE TABLE price_history (
	id INTEGER NOT NULL, 
	commodity_id INTEGER NOT NULL, 
	price FLOAT NOT NULL, 
	price_open FLOAT, 
	price_high FLOAT, 
	price_low FLOAT, 
	price_close FLOAT, 
	volume FLOAT, 
	region VARCHAR(100), 
	state VARCHAR(50), 
	source VARCHAR(100), 
	timestamp DATETIME NOT NULL, 
	created_at DATETIME DEFAULT (CURRENT_TIMESTAMP), 
	PRIMARY KEY (id), 
	FOREIGN KEY(commodity_id) REFERENCES commodities (id)
);

CREATE TABLE price_predictions (
	id INTEGER NOT NULL, 
	commodity_id INTEGER NOT NULL, 
	predicted_price FLOAT NOT NULL, 
	confidence_score FLOAT, 
	prediction_horizon INTEGER, 
	model_name VARCHAR(100), 
	model_version VARCHAR(50), 
	features_used JSON, 
	lower_bound FLOAT, 
	upper_bound FLOAT, 
	prediction_date DATETIME NOT NULL, 
	target_date DATETIME NOT NULL, 
	created_at DATETIME DEFAULT (CURRENT_TIMESTAMP), 
	validated BOOLEAN, 
	actual_price FLOAT, 
	PRIMARY KEY (id), 
	FOREIGN KEY(commodity_id) REFERENCES commodities (id)
);

CREATE TABLE sqlite_sequence(name,seq);

CREATE TABLE weather_data (
	id INTEGER NOT NULL, 
	station_id VARCHAR(50), 
	latitude FLOAT, 
	longitude FLOAT, 
	region VARCHAR(100), 
	state VARCHAR(50), 
	temperature FLOAT, 
	humidity FLOAT, 
	precipitation FLOAT, 
	wind_speed FLOAT, 
	pressure FLOAT, 
	ndvi FLOAT, 
	evapotranspiration FLOAT, 
	timestamp DATETIME NOT NULL, 
	created_at DATETIME DEFAULT (CURRENT_TIMESTAMP), 
	source VARCHAR(100), 
	PRIMARY KEY (id)
);

CREATE TABLE whatsapp_users (
	id INTEGER NOT NULL, 
	phone_number VARCHAR(20) NOT NULL, 
	name VARCHAR(100), 
	user_type VARCHAR(50), 
	preferred_commodities JSON, 
	notification_frequency VARCHAR(50), 
	active BOOLEAN, 
	region VARCHAR(100), 
	state VARCHAR(50), 
	created_at DATETIME DEFAULT (CURRENT_TIMESTAMP), 
	last_interaction DATETIME, 
	PRIMARY KEY (id)
);

-- INFORMAÇÕES DAS TABELAS

-- Tabela: broadcast_groups
-- Registros: 3
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
-- Registros: 2
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

-- Tabela: commodities
-- Registros: 14
-- Colunas:
--   id INTEGER NOT NULL PRIMARY KEY
--   symbol VARCHAR(10) NOT NULL 
--   name VARCHAR(100) NOT NULL 
--   category VARCHAR(50) NOT NULL 
--   unit VARCHAR(20) NOT NULL 
--   exchange VARCHAR(50) NULL 
--   active BOOLEAN NULL 
--   created_at DATETIME NULL 
--   updated_at DATETIME NULL 

-- Tabela: weather_data
-- Registros: 0
-- Colunas:
--   id INTEGER NOT NULL PRIMARY KEY
--   station_id VARCHAR(50) NULL 
--   latitude FLOAT NULL 
--   longitude FLOAT NULL 
--   region VARCHAR(100) NULL 
--   state VARCHAR(50) NULL 
--   temperature FLOAT NULL 
--   humidity FLOAT NULL 
--   precipitation FLOAT NULL 
--   wind_speed FLOAT NULL 
--   pressure FLOAT NULL 
--   ndvi FLOAT NULL 
--   evapotranspiration FLOAT NULL 
--   timestamp DATETIME NOT NULL 
--   created_at DATETIME NULL 
--   source VARCHAR(100) NULL 

-- Tabela: government_data
-- Registros: 0
-- Colunas:
--   id INTEGER NOT NULL PRIMARY KEY
--   source VARCHAR(50) NOT NULL 
--   dataset_type VARCHAR(100) NOT NULL 
--   commodity VARCHAR(50) NULL 
--   region VARCHAR(100) NULL 
--   state VARCHAR(50) NULL 
--   municipality VARCHAR(100) NULL 
--   value FLOAT NOT NULL 
--   unit VARCHAR(50) NULL 
--   reference_period VARCHAR(50) NULL 
--   data_metadata JSON NULL 
--   timestamp DATETIME NOT NULL 
--   created_at DATETIME NULL 

-- Tabela: whatsapp_users
-- Registros: 1
-- Colunas:
--   id INTEGER NOT NULL PRIMARY KEY
--   phone_number VARCHAR(20) NOT NULL 
--   name VARCHAR(100) NULL 
--   user_type VARCHAR(50) NULL 
--   preferred_commodities JSON NULL 
--   notification_frequency VARCHAR(50) NULL 
--   active BOOLEAN NULL 
--   region VARCHAR(100) NULL 
--   state VARCHAR(50) NULL 
--   created_at DATETIME NULL 
--   last_interaction DATETIME NULL 

-- Tabela: price_history
-- Registros: 30
-- Colunas:
--   id INTEGER NOT NULL PRIMARY KEY
--   commodity_id INTEGER NOT NULL 
--   price FLOAT NOT NULL 
--   price_open FLOAT NULL 
--   price_high FLOAT NULL 
--   price_low FLOAT NULL 
--   price_close FLOAT NULL 
--   volume FLOAT NULL 
--   region VARCHAR(100) NULL 
--   state VARCHAR(50) NULL 
--   source VARCHAR(100) NULL 
--   timestamp DATETIME NOT NULL 
--   created_at DATETIME NULL 

-- Tabela: market_alerts
-- Registros: 1
-- Colunas:
--   id INTEGER NOT NULL PRIMARY KEY
--   commodity_id INTEGER NOT NULL 
--   alert_type VARCHAR(50) NOT NULL 
--   threshold_value FLOAT NOT NULL 
--   comparison_period INTEGER NULL 
--   active BOOLEAN NULL 
--   triggered BOOLEAN NULL 
--   last_triggered DATETIME NULL 
--   user_phone VARCHAR(20) NULL 
--   user_email VARCHAR(100) NULL 
--   notification_method VARCHAR(50) NULL 
--   created_at DATETIME NULL 
--   updated_at DATETIME NULL 

-- Tabela: price_predictions
-- Registros: 0
-- Colunas:
--   id INTEGER NOT NULL PRIMARY KEY
--   commodity_id INTEGER NOT NULL 
--   predicted_price FLOAT NOT NULL 
--   confidence_score FLOAT NULL 
--   prediction_horizon INTEGER NULL 
--   model_name VARCHAR(100) NULL 
--   model_version VARCHAR(50) NULL 
--   features_used JSON NULL 
--   lower_bound FLOAT NULL 
--   upper_bound FLOAT NULL 
--   prediction_date DATETIME NOT NULL 
--   target_date DATETIME NOT NULL 
--   created_at DATETIME NULL 
--   validated BOOLEAN NULL 
--   actual_price FLOAT NULL 
