-- SPR CENTRAL DATABASE INITIALIZATION
-- Configuração otimizada para 284K+ registros com WAL mode

-- Configurações de performance
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA cache_size = -64000; -- 64MB cache
PRAGMA temp_store = MEMORY;
PRAGMA mmap_size = 268435456; -- 256MB mmap
PRAGMA page_size = 4096;
PRAGMA wal_autocheckpoint = 1000;
PRAGMA busy_timeout = 8000;

-- Tabela de preços CEPEA
CREATE TABLE IF NOT EXISTS cepea_precos (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    data_coleta DATE NOT NULL,
    timestamp_coleta DATETIME DEFAULT CURRENT_TIMESTAMP,
    commodity TEXT NOT NULL,
    preco_real DECIMAL(10,4),
    preco_dolar DECIMAL(10,4),
    variacao_diaria DECIMAL(5,2),
    volume_negociado INTEGER,
    fonte TEXT DEFAULT 'CEPEA',
    status_processamento TEXT DEFAULT 'new',
    hash_registro TEXT UNIQUE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Tabela de dados IMEA
CREATE TABLE IF NOT EXISTS imea_dados (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    data_referencia DATE NOT NULL,
    timestamp_coleta DATETIME DEFAULT CURRENT_TIMESTAMP,
    regiao TEXT NOT NULL,
    commodity TEXT NOT NULL,
    preco_medio DECIMAL(10,4),
    volume_estimado INTEGER,
    area_plantada INTEGER,
    produtividade DECIMAL(8,2),
    safra TEXT,
    fonte TEXT DEFAULT 'IMEA',
    status_processamento TEXT DEFAULT 'new',
    hash_registro TEXT UNIQUE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Tabela de dados climáticos INMET
CREATE TABLE IF NOT EXISTS clima_dados (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    data_medicao DATE NOT NULL,
    timestamp_coleta DATETIME DEFAULT CURRENT_TIMESTAMP,
    codigo_estacao TEXT NOT NULL,
    nome_estacao TEXT,
    uf TEXT,
    municipio TEXT,
    latitude DECIMAL(10,6),
    longitude DECIMAL(10,6),
    temperatura_max DECIMAL(5,2),
    temperatura_min DECIMAL(5,2),
    temperatura_media DECIMAL(5,2),
    umidade_relativa DECIMAL(5,2),
    precipitacao DECIMAL(8,2),
    velocidade_vento DECIMAL(5,2),
    pressao_atmosferica DECIMAL(8,2),
    radiacao_solar DECIMAL(8,2),
    fonte TEXT DEFAULT 'INMET',
    status_processamento TEXT DEFAULT 'new',
    hash_registro TEXT UNIQUE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Tabela de controle de ingestão
CREATE TABLE IF NOT EXISTS ingest_control (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    fonte TEXT NOT NULL,
    data_execucao DATETIME NOT NULL,
    data_inicio DATE,
    data_fim DATE,
    registros_processados INTEGER DEFAULT 0,
    registros_inseridos INTEGER DEFAULT 0,
    registros_atualizados INTEGER DEFAULT 0,
    tempo_execucao_ms INTEGER,
    status TEXT NOT NULL, -- running, completed, failed
    erro_detalhes TEXT,
    pid INTEGER,
    hostname TEXT,
    version TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Tabela de métricas de performance
CREATE TABLE IF NOT EXISTS performance_metrics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    fonte TEXT NOT NULL,
    timestamp_metric DATETIME DEFAULT CURRENT_TIMESTAMP,
    latencia_ms INTEGER,
    throughput_regs_sec INTEGER,
    db_size_mb INTEGER,
    wal_size_mb DECIMAL(8,2),
    concurrent_connections INTEGER,
    lock_waits INTEGER DEFAULT 0,
    memory_usage_mb INTEGER,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Índices para otimização
CREATE INDEX IF NOT EXISTS idx_cepea_data_commodity ON cepea_precos(data_coleta, commodity);
CREATE INDEX IF NOT EXISTS idx_cepea_timestamp ON cepea_precos(timestamp_coleta);
CREATE INDEX IF NOT EXISTS idx_cepea_hash ON cepea_precos(hash_registro);

CREATE INDEX IF NOT EXISTS idx_imea_data_regiao ON imea_dados(data_referencia, regiao, commodity);
CREATE INDEX IF NOT EXISTS idx_imea_timestamp ON imea_dados(timestamp_coleta);
CREATE INDEX IF NOT EXISTS idx_imea_hash ON imea_dados(hash_registro);

CREATE INDEX IF NOT EXISTS idx_clima_data_estacao ON clima_dados(data_medicao, codigo_estacao);
CREATE INDEX IF NOT EXISTS idx_clima_uf_municipio ON clima_dados(uf, municipio);
CREATE INDEX IF NOT EXISTS idx_clima_timestamp ON clima_dados(timestamp_coleta);
CREATE INDEX IF NOT EXISTS idx_clima_hash ON clima_dados(hash_registro);

CREATE INDEX IF NOT EXISTS idx_ingest_fonte_data ON ingest_control(fonte, data_execucao);
CREATE INDEX IF NOT EXISTS idx_ingest_status ON ingest_control(status, data_execucao);

CREATE INDEX IF NOT EXISTS idx_perf_fonte_timestamp ON performance_metrics(fonte, timestamp_metric);

-- Trigger para updated_at automático
CREATE TRIGGER IF NOT EXISTS update_cepea_timestamp 
    AFTER UPDATE ON cepea_precos
    BEGIN
        UPDATE cepea_precos 
        SET updated_at = CURRENT_TIMESTAMP 
        WHERE id = NEW.id;
    END;

CREATE TRIGGER IF NOT EXISTS update_imea_timestamp 
    AFTER UPDATE ON imea_dados
    BEGIN
        UPDATE imea_dados 
        SET updated_at = CURRENT_TIMESTAMP 
        WHERE id = NEW.id;
    END;

CREATE TRIGGER IF NOT EXISTS update_clima_timestamp 
    AFTER UPDATE ON clima_dados
    BEGIN
        UPDATE clima_dados 
        SET updated_at = CURRENT_TIMESTAMP 
        WHERE id = NEW.id;
    END;

-- Views para análises rápidas
CREATE VIEW IF NOT EXISTS vw_daily_ingestion_summary AS
SELECT 
    fonte,
    DATE(data_execucao) as data,
    COUNT(*) as execucoes,
    SUM(registros_inseridos) as total_inseridos,
    AVG(tempo_execucao_ms) as tempo_medio_ms,
    SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) as execucoes_falhas
FROM ingest_control 
GROUP BY fonte, DATE(data_execucao);

CREATE VIEW IF NOT EXISTS vw_latest_data_status AS
SELECT 
    'CEPEA' as fonte,
    MAX(data_coleta) as ultima_data,
    COUNT(*) as total_registros,
    MAX(timestamp_coleta) as ultima_coleta
FROM cepea_precos
UNION ALL
SELECT 
    'IMEA' as fonte,
    MAX(data_referencia) as ultima_data,
    COUNT(*) as total_registros,
    MAX(timestamp_coleta) as ultima_coleta
FROM imea_dados
UNION ALL
SELECT 
    'INMET' as fonte,
    MAX(data_medicao) as ultima_data,
    COUNT(*) as total_registros,
    MAX(timestamp_coleta) as ultima_coleta
FROM clima_dados;

-- Procedure para limpeza WAL
CREATE TRIGGER IF NOT EXISTS cleanup_wal_trigger
    AFTER INSERT ON ingest_control
    WHEN (SELECT COUNT(*) FROM ingest_control) % 100 = 0
    BEGIN
        PRAGMA wal_checkpoint(TRUNCATE);
    END;

-- Inserir registro inicial de controle
INSERT OR IGNORE INTO ingest_control 
(fonte, data_execucao, status, registros_processados, tempo_execucao_ms)
VALUES 
('INIT', CURRENT_TIMESTAMP, 'completed', 0, 0);

-- Verificação final
SELECT 'Database initialized successfully' as status,
       PRAGMA_journal_mode() as journal_mode,
       PRAGMA_synchronous() as synchronous,
       PRAGMA_cache_size() as cache_size,
       PRAGMA_busy_timeout() as busy_timeout;