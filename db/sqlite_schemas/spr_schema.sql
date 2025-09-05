-- Schema extraído de: /home/cadu/projeto_SPR/data/spr.db
-- Data: 1754799517.8167777

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
