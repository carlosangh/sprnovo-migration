-- SPR Sistema Preditivo Royal - Schema Completo
-- Extensão do schema para suportar todos os módulos

-- =====================================================
-- TABELAS DE ANÁLISES E RESEARCH
-- =====================================================

-- Tabela de análises de mercado
CREATE TABLE IF NOT EXISTS market_analyses (
    id SERIAL PRIMARY KEY,
    commodity VARCHAR(50) NOT NULL,
    analysis_type VARCHAR(50) NOT NULL, -- trend, forecast, risk, opportunity
    region VARCHAR(100),
    data JSONB NOT NULL,
    confidence_score DECIMAL(3,2) CHECK (confidence_score >= 0 AND confidence_score <= 1),
    insights TEXT[],
    recommendations TEXT[],
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    agent_id VARCHAR(50),
    tenant VARCHAR(50) DEFAULT 'royal_spr'
);

-- Tabela de sinais de trading
CREATE TABLE IF NOT EXISTS trading_signals (
    id SERIAL PRIMARY KEY,
    commodity VARCHAR(50) NOT NULL,
    signal_type VARCHAR(10) NOT NULL CHECK (signal_type IN ('BUY', 'SELL', 'HOLD')),
    target_price DECIMAL(10,2) NOT NULL,
    stop_loss DECIMAL(10,2),
    confidence DECIMAL(3,2) CHECK (confidence >= 0 AND confidence <= 1),
    reasoning TEXT[],
    valid_until TIMESTAMP,
    status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMP DEFAULT NOW(),
    agent_id VARCHAR(50),
    tenant VARCHAR(50) DEFAULT 'royal_spr'
);

-- Tabela de relatórios de pesquisa
CREATE TABLE IF NOT EXISTS research_reports (
    id SERIAL PRIMARY KEY,
    topic VARCHAR(255) NOT NULL,
    scope VARCHAR(100), -- market_analysis, price_forecast, etc
    sources JSONB, -- Array de fontes pesquisadas
    key_findings TEXT[],
    market_impact TEXT,
    sentiment_score DECIMAL(3,2), -- -1 to 1
    relevance_score DECIMAL(3,2), -- 0 to 1  
    raw_data JSONB,
    created_at TIMESTAMP DEFAULT NOW(),
    agent_id VARCHAR(50),
    tenant VARCHAR(50) DEFAULT 'royal_spr'
);

-- =====================================================
-- TABELAS OCR E DOCUMENTOS
-- =====================================================

-- Tabela de documentos processados por OCR
CREATE TABLE IF NOT EXISTS ocr_documents (
    id SERIAL PRIMARY KEY,
    filename VARCHAR(255) NOT NULL,
    file_path TEXT,
    file_hash VARCHAR(64) UNIQUE,
    file_size INTEGER,
    mime_type VARCHAR(100),
    document_type VARCHAR(50), -- commodity_report, price_list, contract, etc
    ocr_results JSONB, -- Resultados brutos do OCR
    analysis_results JSONB, -- Resultados da análise inteligente
    extracted_data JSONB, -- Dados estruturados extraídos
    confidence_scores JSONB, -- Scores de confiança por tipo de dado
    processing_status VARCHAR(20) DEFAULT 'pending',
    processing_time DECIMAL(6,3),
    created_at TIMESTAMP DEFAULT NOW(),
    processed_at TIMESTAMP,
    agent_id VARCHAR(50),
    tenant VARCHAR(50) DEFAULT 'royal_spr'
);

-- Tabela de análises de consultas inteligentes
CREATE TABLE IF NOT EXISTS query_analyses (
    id SERIAL PRIMARY KEY,
    query TEXT NOT NULL,
    query_type VARCHAR(50), -- search, analysis, prediction
    intent_classification JSONB,
    processing_method VARCHAR(20), -- local, openai, hybrid
    results JSONB,
    context_used JSONB,
    response_text TEXT,
    confidence DECIMAL(3,2),
    processing_time DECIMAL(6,3),
    created_at TIMESTAMP DEFAULT NOW(),
    agent_id VARCHAR(50),
    tenant VARCHAR(50) DEFAULT 'royal_spr'
);

-- =====================================================
-- TABELAS DE INGESTÃO DE DADOS
-- =====================================================

-- Tabela de logs de ingestão
CREATE TABLE IF NOT EXISTS ingestion_logs (
    id SERIAL PRIMARY KEY,
    source VARCHAR(50) NOT NULL, -- cepea, imea, clima
    ingestion_type VARCHAR(50), -- daily, weekly, monthly
    status VARCHAR(20) NOT NULL, -- success, error, partial
    records_processed INTEGER DEFAULT 0,
    records_inserted INTEGER DEFAULT 0,
    records_updated INTEGER DEFAULT 0,
    records_failed INTEGER DEFAULT 0,
    processing_time DECIMAL(8,3),
    error_details TEXT,
    metadata JSONB,
    started_at TIMESTAMP DEFAULT NOW(),
    completed_at TIMESTAMP,
    agent_id VARCHAR(50)
);

-- Tabela de dados climáticos INMET
CREATE TABLE IF NOT EXISTS climate_data (
    id SERIAL PRIMARY KEY,
    station_code VARCHAR(20) NOT NULL,
    station_name VARCHAR(255),
    region VARCHAR(100),
    date DATE NOT NULL,
    temperature_avg DECIMAL(5,2),
    temperature_max DECIMAL(5,2),
    temperature_min DECIMAL(5,2),
    humidity DECIMAL(5,2),
    precipitation DECIMAL(7,2),
    wind_speed DECIMAL(5,2),
    atmospheric_pressure DECIMAL(7,2),
    solar_radiation DECIMAL(8,2),
    raw_data JSONB,
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(station_code, date)
);

-- =====================================================
-- TABELAS DE PERFORMANCE E MONITORAMENTO
-- =====================================================

-- Tabela de métricas de performance
CREATE TABLE IF NOT EXISTS performance_metrics (
    id SERIAL PRIMARY KEY,
    metric_name VARCHAR(100) NOT NULL,
    metric_type VARCHAR(50), -- counter, gauge, histogram
    value DECIMAL(15,6),
    labels JSONB, -- Tags/dimensões
    source_component VARCHAR(100),
    source_agent VARCHAR(50),
    timestamp TIMESTAMP DEFAULT NOW()
);

-- Tabela de logs de sistema
CREATE TABLE IF NOT EXISTS system_logs (
    id SERIAL PRIMARY KEY,
    level VARCHAR(20) NOT NULL, -- debug, info, warning, error, critical
    component VARCHAR(100),
    agent_id VARCHAR(50),
    message TEXT NOT NULL,
    details JSONB,
    stack_trace TEXT,
    user_id INTEGER,
    tenant VARCHAR(50),
    timestamp TIMESTAMP DEFAULT NOW()
);

-- Tabela de status dos agentes
CREATE TABLE IF NOT EXISTS agent_status (
    id SERIAL PRIMARY KEY,
    agent_id VARCHAR(50) NOT NULL UNIQUE,
    agent_name VARCHAR(100),
    agent_type VARCHAR(50), -- coordinator, executor
    specialization VARCHAR(100),
    status VARCHAR(20) DEFAULT 'offline', -- online, offline, error, maintenance
    current_task VARCHAR(255),
    capabilities TEXT[],
    last_heartbeat TIMESTAMP,
    performance_metrics JSONB,
    error_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- =====================================================
-- TABELAS DE BUSINESS INTELLIGENCE
-- =====================================================

-- Tabela de KPIs de negócio
CREATE TABLE IF NOT EXISTS business_kpis (
    id SERIAL PRIMARY KEY,
    kpi_name VARCHAR(100) NOT NULL,
    kpi_category VARCHAR(50), -- sales, operations, market, financial
    value DECIMAL(15,6),
    target_value DECIMAL(15,6),
    unit VARCHAR(20),
    period_type VARCHAR(20), -- daily, weekly, monthly, quarterly
    period_start DATE,
    period_end DATE,
    calculation_method TEXT,
    data_sources TEXT[],
    created_at TIMESTAMP DEFAULT NOW(),
    tenant VARCHAR(50) DEFAULT 'royal_spr'
);

-- Tabela de dashboards
CREATE TABLE IF NOT EXISTS dashboards (
    id SERIAL PRIMARY KEY,
    dashboard_name VARCHAR(100) NOT NULL,
    dashboard_type VARCHAR(50), -- executive, operational, analytical
    config JSONB NOT NULL, -- Configuração dos widgets
    permissions JSONB, -- Permissões de acesso
    is_active BOOLEAN DEFAULT true,
    created_by INTEGER,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    tenant VARCHAR(50) DEFAULT 'royal_spr'
);

-- =====================================================
-- ÍNDICES PARA PERFORMANCE
-- =====================================================

-- Índices para market_analyses
CREATE INDEX IF NOT EXISTS idx_market_analyses_commodity ON market_analyses(commodity);
CREATE INDEX IF NOT EXISTS idx_market_analyses_type ON market_analyses(analysis_type);
CREATE INDEX IF NOT EXISTS idx_market_analyses_created_at ON market_analyses(created_at);
CREATE INDEX IF NOT EXISTS idx_market_analyses_tenant ON market_analyses(tenant);

-- Índices para trading_signals
CREATE INDEX IF NOT EXISTS idx_trading_signals_commodity ON trading_signals(commodity);
CREATE INDEX IF NOT EXISTS idx_trading_signals_type ON trading_signals(signal_type);
CREATE INDEX IF NOT EXISTS idx_trading_signals_status ON trading_signals(status);
CREATE INDEX IF NOT EXISTS idx_trading_signals_created_at ON trading_signals(created_at);

-- Índices para research_reports
CREATE INDEX IF NOT EXISTS idx_research_reports_topic ON research_reports(topic);
CREATE INDEX IF NOT EXISTS idx_research_reports_scope ON research_reports(scope);
CREATE INDEX IF NOT EXISTS idx_research_reports_created_at ON research_reports(created_at);

-- Índices para ocr_documents
CREATE INDEX IF NOT EXISTS idx_ocr_documents_hash ON ocr_documents(file_hash);
CREATE INDEX IF NOT EXISTS idx_ocr_documents_type ON ocr_documents(document_type);
CREATE INDEX IF NOT EXISTS idx_ocr_documents_status ON ocr_documents(processing_status);
CREATE INDEX IF NOT EXISTS idx_ocr_documents_created_at ON ocr_documents(created_at);

-- Índices para query_analyses
CREATE INDEX IF NOT EXISTS idx_query_analyses_type ON query_analyses(query_type);
CREATE INDEX IF NOT EXISTS idx_query_analyses_method ON query_analyses(processing_method);
CREATE INDEX IF NOT EXISTS idx_query_analyses_created_at ON query_analyses(created_at);

-- Índices para climate_data
CREATE INDEX IF NOT EXISTS idx_climate_data_station_date ON climate_data(station_code, date);
CREATE INDEX IF NOT EXISTS idx_climate_data_region ON climate_data(region);
CREATE INDEX IF NOT EXISTS idx_climate_data_date ON climate_data(date);

-- Índices para performance_metrics
CREATE INDEX IF NOT EXISTS idx_performance_metrics_name ON performance_metrics(metric_name);
CREATE INDEX IF NOT EXISTS idx_performance_metrics_timestamp ON performance_metrics(timestamp);
CREATE INDEX IF NOT EXISTS idx_performance_metrics_component ON performance_metrics(source_component);

-- Índices para system_logs
CREATE INDEX IF NOT EXISTS idx_system_logs_level ON system_logs(level);
CREATE INDEX IF NOT EXISTS idx_system_logs_component ON system_logs(component);
CREATE INDEX IF NOT EXISTS idx_system_logs_timestamp ON system_logs(timestamp);

-- =====================================================
-- TRIGGERS PARA ATUALIZAÇÃO AUTOMÁTICA
-- =====================================================

-- Trigger para updated_at em market_analyses
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_market_analyses_updated_at 
    BEFORE UPDATE ON market_analyses 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_agent_status_updated_at 
    BEFORE UPDATE ON agent_status 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_dashboards_updated_at 
    BEFORE UPDATE ON dashboards 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- VIEWS ÚTEIS
-- =====================================================

-- View de resumo de análises por commodity
CREATE OR REPLACE VIEW vw_market_analysis_summary AS
SELECT 
    commodity,
    COUNT(*) as total_analyses,
    AVG(confidence_score) as avg_confidence,
    MAX(created_at) as last_analysis,
    array_agg(DISTINCT analysis_type) as analysis_types
FROM market_analyses 
WHERE created_at > NOW() - INTERVAL '30 days'
GROUP BY commodity;

-- View de sinais de trading ativos
CREATE OR REPLACE VIEW vw_active_trading_signals AS
SELECT 
    ts.*,
    ma.confidence_score as analysis_confidence,
    ma.created_at as analysis_date
FROM trading_signals ts
LEFT JOIN market_analyses ma ON ts.commodity = ma.commodity 
    AND ma.created_at = (
        SELECT MAX(created_at) 
        FROM market_analyses ma2 
        WHERE ma2.commodity = ts.commodity
    )
WHERE ts.status = 'active' 
    AND (ts.valid_until IS NULL OR ts.valid_until > NOW());

-- View de performance dos agentes
CREATE OR REPLACE VIEW vw_agent_performance AS
SELECT 
    agent_id,
    agent_name,
    status,
    last_heartbeat,
    EXTRACT(EPOCH FROM (NOW() - last_heartbeat))/60 as minutes_since_heartbeat,
    error_count,
    current_task
FROM agent_status
ORDER BY last_heartbeat DESC;

-- =====================================================
-- DADOS DE EXEMPLO PARA TESTES
-- =====================================================

-- Inserir alguns dados de exemplo
INSERT INTO market_analyses (commodity, analysis_type, region, data, confidence_score, insights, recommendations) VALUES
('SOJA', 'trend', 'MT', '{"price_trend": "bullish", "volume": "high", "volatility": "medium"}', 0.85, 
 ARRAY['Tendência de alta confirmada', 'Volume acima da média'], 
 ARRAY['Manter posições compradas', 'Monitorar resistência em R$ 150']),
('MILHO', 'forecast', 'PR', '{"forecast_30d": "stable", "risk_level": "low"}', 0.78,
 ARRAY['Preços estáveis esperados', 'Baixo risco de volatilidade'],
 ARRAY['Posição neutra recomendada', 'Aguardar sinais mais claros']);

INSERT INTO trading_signals (commodity, signal_type, target_price, stop_loss, confidence, reasoning) VALUES
('SOJA', 'BUY', 148.50, 142.00, 0.82, ARRAY['Breakout confirmado', 'Volume crescente', 'Fundamentais positivos']),
('MILHO', 'HOLD', 74.20, 70.50, 0.68, ARRAY['Consolidação lateral', 'Aguardando definição', 'Volume médio']);

INSERT INTO research_reports (topic, scope, key_findings, market_impact, sentiment_score, relevance_score) VALUES
('Safra Soja 2024/25', 'production_forecast', 
 ARRAY['Produção estimada 15% maior', 'Condições climáticas favoráveis', 'Área plantada recorde'],
 'Pressão baixista nos preços esperada para Q2 2025', 0.3, 0.9),
('Mercado Milho Exportação', 'trade_analysis',
 ARRAY['Demanda chinesa crescente', 'Competição com Argentina', 'Logística melhorada'],
 'Suporte para preços no médio prazo', 0.6, 0.85);

-- Inserir status dos agentes
INSERT INTO agent_status (agent_id, agent_name, agent_type, specialization, status, capabilities) VALUES
('spr_orchestrator', 'Orchestrator Master', 'coordinator', 'Coordenação Geral', 'online', 
 ARRAY['project_management', 'quality_control', 'integration']),
('spr_data_engineer', 'Data Engineer', 'executor', 'Engenharia de Dados', 'online',
 ARRAY['etl', 'data_ingestion', 'cepea', 'imea', 'climate_data']),
('spr_quant_analyst', 'Quantitative Analyst', 'executor', 'Análise Quantitativa', 'online',
 ARRAY['financial_modeling', 'trading_signals', 'risk_analysis', 'backtesting']),
('spr_research_agent', 'Research Agent', 'executor', 'Pesquisa', 'online',
 ARRAY['web_scraping', 'market_research', 'news_analysis', 'data_collection']);

COMMIT;
