CREATE TABLE usuarios (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email VARCHAR(255) UNIQUE NOT NULL,
    senha_hash VARCHAR(255) NOT NULL,
    nome VARCHAR(255) NOT NULL,
    perfil VARCHAR(50) DEFAULT "usuario",
    ativo BOOLEAN DEFAULT 1,
    criado_em DATETIME DEFAULT CURRENT_TIMESTAMP,
    ultimo_login DATETIME,
    empresa VARCHAR(255),
    telefone VARCHAR(20)
);
CREATE TABLE sqlite_sequence(name,seq);
CREATE TABLE whatsapp_sessoes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id VARCHAR(100) UNIQUE NOT NULL,
    status VARCHAR(50) DEFAULT "disconnected",
    qr_code TEXT,
    ultimo_qr DATETIME,
    conectado_em DATETIME,
    desconectado_em DATETIME,
    usuario_id INTEGER,
    FOREIGN KEY (usuario_id) REFERENCES usuarios (id)
);
CREATE TABLE whatsapp_conversas (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id VARCHAR(100),
    numero_telefone VARCHAR(20),
    nome_contato VARCHAR(255),
    mensagem TEXT,
    tipo VARCHAR(20), -- enviada, recebida
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) DEFAULT "entregue",
    FOREIGN KEY (session_id) REFERENCES whatsapp_sessoes (session_id)
);
CREATE TABLE dados_mercado (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    commodity VARCHAR(100) NOT NULL,
    preco DECIMAL(10,2),
    variacao DECIMAL(5,2),
    volume INTEGER,
    data_coleta DATETIME DEFAULT CURRENT_TIMESTAMP,
    fonte VARCHAR(100), -- CEPEA, B3, etc
    regiao VARCHAR(100)
, tendencia VARCHAR(50));
CREATE TABLE pulso_analises (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    usuario_id INTEGER,
    pergunta TEXT,
    resposta TEXT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    sessao_id VARCHAR(100),
    FOREIGN KEY (usuario_id) REFERENCES usuarios (id)
);
CREATE TABLE logs_sistema (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    nivel VARCHAR(20), -- info, warning, error
    modulo VARCHAR(100),
    mensagem TEXT,
    detalhes TEXT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    usuario_id INTEGER,
    ip_address VARCHAR(45)
);
CREATE TABLE configuracoes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    chave VARCHAR(100) UNIQUE NOT NULL,
    valor TEXT,
    descricao TEXT,
    modificado_em DATETIME DEFAULT CURRENT_TIMESTAMP,
    modificado_por INTEGER,
    FOREIGN KEY (modificado_por) REFERENCES usuarios (id)
);
CREATE TABLE agentes_mensagens (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  agent_id TEXT NOT NULL,
  agent_name TEXT NOT NULL,
  message_type TEXT NOT NULL CHECK (message_type IN ('request', 'response', 'error', 'heartbeat')),
  payload TEXT,
  signature TEXT,
  from_agent TEXT,
  to_agent TEXT,
  timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
  processed BOOLEAN DEFAULT 0,
  retry_count INTEGER DEFAULT 0,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed', 'expired'))
);
CREATE TABLE agentes_status (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  agent_id TEXT NOT NULL UNIQUE,
  agent_name TEXT NOT NULL,
  agent_type TEXT NOT NULL CHECK (agent_type IN ('coordinator', 'backend', 'whatsapp', 'frontend', 'ai', 'analytics')),
  port INTEGER NOT NULL,
  url TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'offline' CHECK (status IN ('online', 'offline', 'error', 'starting', 'stopping')),
  last_heartbeat DATETIME,
  capabilities TEXT, -- JSON array of capabilities
  metadata TEXT, -- JSON object with additional info
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE agentes_registro (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  agent_id TEXT NOT NULL UNIQUE,
  agent_name TEXT NOT NULL,
  agent_type TEXT NOT NULL CHECK (agent_type IN ('coordinator', 'backend', 'whatsapp', 'frontend', 'ai', 'analytics')),
  port INTEGER NOT NULL,
  url TEXT NOT NULL,
  capabilities TEXT, -- JSON array
  metadata TEXT, -- JSON object
  version TEXT,
  registered_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  last_seen DATETIME DEFAULT CURRENT_TIMESTAMP,
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'maintenance', 'error'))
);
CREATE TABLE agentes_heartbeats (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  agent_id TEXT NOT NULL,
  timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
  latency_ms INTEGER,
  cpu_percent REAL,
  memory_mb INTEGER,
  queue_size INTEGER DEFAULT 0,
  custom_metrics TEXT, -- JSON object
  status TEXT DEFAULT 'healthy' CHECK (status IN ('healthy', 'warning', 'error', 'timeout')),
  FOREIGN KEY (agent_id) REFERENCES agentes_registro(agent_id) ON DELETE CASCADE
);
CREATE TABLE agentes_alertas (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  agent_id TEXT NOT NULL,
  alert_type TEXT NOT NULL CHECK (alert_type IN ('latency', 'memory', 'cpu', 'offline', 'error', 'custom')),
  severity TEXT NOT NULL CHECK (severity IN ('info', 'warning', 'critical', 'fatal')),
  message TEXT NOT NULL,
  threshold_value REAL,
  current_value REAL,
  triggered_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  resolved_at DATETIME,
  webhook_sent BOOLEAN DEFAULT 0,
  webhook_response_code INTEGER,
  metadata TEXT -- JSON object
);
CREATE TABLE commercial_analyses (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      analysis_type TEXT NOT NULL,  -- price_prediction, market_trend, opportunity
      commodity TEXT,
      region TEXT,
      input_data JSON,
      results JSON,
      confidence_score REAL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      agent_version TEXT DEFAULT '1.0.0'
    );
CREATE TABLE price_alerts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      commodity TEXT NOT NULL,
      region TEXT,
      alert_type TEXT,              -- threshold_breach, trend_change, opportunity
      current_price REAL,
      threshold_price REAL,
      alert_message TEXT,
      contacts JSON,                -- números para notificar
      status TEXT DEFAULT 'active', -- active, sent, expired
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );
CREATE TABLE market_insights (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      insight_type TEXT,            -- trend, forecast, risk
      commodity TEXT,
      region TEXT,
      period_days INTEGER,
      insight_data JSON,
      relevance_score REAL,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );
CREATE TABLE analytics_metrics (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      metric_name TEXT NOT NULL,
      metric_type TEXT,              -- counter, gauge, histogram
      value REAL,
      labels JSON,                   -- tags/dimensões
      source_agent TEXT,
      timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
    );
CREATE TABLE analytics_reports (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      report_name TEXT NOT NULL,
      report_type TEXT,              -- daily, weekly, monthly, custom
      period_start DATETIME,
      period_end DATETIME,
      data JSON,
      insights JSON,
      generated_by TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );
CREATE TABLE analytics_dashboards (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      dashboard_name TEXT UNIQUE,
      config JSON,                   -- configuração dos widgets/charts
      permissions JSON,              -- quem pode ver
      last_updated DATETIME DEFAULT CURRENT_TIMESTAMP
    );
CREATE TABLE automation_workflows (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      workflow_name TEXT UNIQUE NOT NULL,
      workflow_type TEXT,            -- scheduled, triggered, manual
      config JSON,                   -- configuração do workflow
      triggers JSON,                 -- gatilhos (tempo, evento, etc)
      actions JSON,                  -- ações a executar
      status TEXT DEFAULT 'inactive',-- active, inactive, paused, error
      last_run DATETIME,
      next_run DATETIME,
      run_count INTEGER DEFAULT 0,
      success_count INTEGER DEFAULT 0,
      error_count INTEGER DEFAULT 0,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );
CREATE TABLE automation_executions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      workflow_id INTEGER,
      execution_id TEXT UNIQUE,
      status TEXT,                   -- running, completed, failed, cancelled
      started_at DATETIME,
      completed_at DATETIME,
      input_data JSON,
      output_data JSON,
      error_message TEXT,
      step_logs JSON,
      FOREIGN KEY (workflow_id) REFERENCES automation_workflows(id)
    );
CREATE TABLE automation_tasks (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      task_name TEXT,
      task_type TEXT,                -- send_message, generate_report, sync_data
      schedule_pattern TEXT,         -- cron expression
      target_config JSON,
      last_execution DATETIME,
      next_execution DATETIME,
      status TEXT DEFAULT 'active',  -- active, paused, disabled
      execution_count INTEGER DEFAULT 0,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );
CREATE TABLE noticias (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, source TEXT, url TEXT, summary TEXT, published_at TEXT NOT NULL, region TEXT, tags JSON);
CREATE TABLE prices (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      commodity TEXT NOT NULL,
      region TEXT,
      price REAL NOT NULL,
      currency TEXT DEFAULT 'BRL',
      unit TEXT DEFAULT 'saca',
      source TEXT,
      timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
    );
CREATE TABLE api_logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      method TEXT,
      endpoint TEXT,
      user_id INTEGER,
      ip_address TEXT,
      user_agent TEXT,
      status_code INTEGER,
      response_time_ms INTEGER,
      timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
    );
CREATE TABLE system_config (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      config_key TEXT UNIQUE NOT NULL,
      config_value TEXT,
      config_type TEXT DEFAULT 'string',
      description TEXT,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );
CREATE TABLE fx_ticks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    base TEXT NOT NULL,
    pair TEXT NOT NULL, 
    bid DECIMAL(10,6),
    ask DECIMAL(10,6),
    mid DECIMAL(10,6),
    ts_utc TEXT NOT NULL,
    ts_local TEXT NOT NULL,
    UNIQUE(pair, ts_local)
);
CREATE TABLE symbol_map (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    commodity VARCHAR(50) NOT NULL,
    symbol VARCHAR(20) NOT NULL,
    exchange VARCHAR(20) NOT NULL,
    type VARCHAR(20) DEFAULT 'futures',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(commodity, exchange)
);
CREATE TABLE intel_job_status (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    job_name TEXT UNIQUE NOT NULL,
    last_run TIMESTAMP,
    last_success TIMESTAMP,
    last_error TEXT,
    run_count INTEGER DEFAULT 0,
    error_count INTEGER DEFAULT 0,
    status TEXT DEFAULT 'pending',
    config TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE reports_index (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    url TEXT UNIQUE NOT NULL,
    report_type TEXT NOT NULL,
    organization TEXT NOT NULL,
    published_date DATE,
    highlights TEXT,
    file_path TEXT,
    file_size INTEGER,
    ingested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
, source TEXT, period TEXT);
CREATE TABLE us_crop_progress (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    week_ending DATE NOT NULL,
    crop TEXT NOT NULL,
    state TEXT NOT NULL,
    metric TEXT NOT NULL,
    value_percent REAL,
    year_ago_percent REAL,
    avg_5year_percent REAL,
    source_url TEXT,
    ingested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE cftc_cot (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    report_date DATE NOT NULL,
    market_code TEXT NOT NULL,
    market_name TEXT NOT NULL,
    category TEXT NOT NULL,
    trader_type TEXT NOT NULL,
    open_interest INTEGER,
    positions INTEGER,
    change_positions INTEGER,
    percent_oi REAL,
    traders_count INTEGER,
    concentration_4traders REAL,
    concentration_8traders REAL,
    ingested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE us_drought (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    week_ending DATE NOT NULL,
    state_code TEXT NOT NULL,
    state_name TEXT NOT NULL,
    d0_percent REAL DEFAULT 0,
    d1_percent REAL DEFAULT 0,
    d2_percent REAL DEFAULT 0,
    d3_percent REAL DEFAULT 0,
    d4_percent REAL DEFAULT 0,
    no_drought_percent REAL DEFAULT 0,
    population_affected INTEGER,
    area_sq_miles REAL,
    ingested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE eia_ethanol (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    week_ending DATE NOT NULL,
    production_kbd REAL,
    stocks_kb REAL,
    imports_kbd REAL,
    exports_kbd REAL,
    net_inputs_kbd REAL,
    refinery_net_production_kbd REAL,
    days_supply INTEGER,
    utilization_percent REAL,
    source_url TEXT,
    ingested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE cepea_series (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    source TEXT DEFAULT 'CEPEA',
    indicator_id INTEGER,
    commodity TEXT,
    praca TEXT,
    unit TEXT,
    price NUMERIC,
    variation_pct NUMERIC NULL,
    effective_date DATE,
    collected_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    source_url TEXT,
    license TEXT DEFAULT 'CC BY-NC 4.0',
    hash_dedupe TEXT UNIQUE
);
CREATE TABLE cepea_mapping (
    indicator_id INTEGER PRIMARY KEY,
    commodity TEXT,
    praca TEXT,
    unit TEXT
);
CREATE TABLE IF NOT EXISTS "cepea_mapping_temp"(
  "indicator_id" TEXT,
  "commodity" TEXT,
  "praca" TEXT,
  "unit" TEXT
);
CREATE TABLE imea_series (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    commodity TEXT NOT NULL,
    praca TEXT NOT NULL,
    unit TEXT NOT NULL,
    price NUMERIC NOT NULL,
    effective_date DATE NOT NULL,
    source TEXT DEFAULT 'IMEA',
    region TEXT,
    source_url TEXT,
    hash_dedupe TEXT UNIQUE,
    collected_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE offers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    seller TEXT NOT NULL,
    produto TEXT NOT NULL,
    lado TEXT NOT NULL CHECK (lado IN ('buy', 'sell')),
    preco REAL NOT NULL CHECK (preco > 0),
    unidade TEXT NOT NULL DEFAULT 'R$/sc',
    quantidade REAL NOT NULL CHECK (quantidade > 0),
    praca TEXT NOT NULL,
    commodity TEXT NOT NULL,
    fonte TEXT DEFAULT 'SPR',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    deleted_at DATETIME DEFAULT NULL,
    ttl_dias INTEGER DEFAULT 30, buyer_id INTEGER, icr_score INTEGER, icr_sub_json TEXT, parity_used REAL, logistics_used_json TEXT, icr_calc_id TEXT, icr_calculated_at TIMESTAMP,
    UNIQUE(produto, preco, quantidade, seller, praca, created_at) ON CONFLICT IGNORE
);
CREATE TABLE dados_historicos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            fonte TEXT NOT NULL,
            commodity TEXT NOT NULL,
            preco REAL NOT NULL,
            data_pregao TEXT NOT NULL,
            data_coleta TEXT NOT NULL,
            regiao TEXT,
            unidade TEXT,
            volume INTEGER DEFAULT 0,
            variacao REAL DEFAULT 0,
            contrato TEXT,
            vencimento TEXT,
            
            -- Campos específicos para análise de spread
            preco_abertura REAL,
            preco_maximo REAL,
            preco_minimo REAL,
            preco_fechamento REAL,
            
            -- Metadados
            simbolo_original TEXT,
            moeda TEXT DEFAULT 'BRL',
            
            -- Índices para consultas rápidas
            UNIQUE(fonte, commodity, data_pregao, contrato, regiao)
        );
CREATE TABLE analise_historica (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            
            -- Identificação
            data_pregao TEXT NOT NULL,
            commodity TEXT NOT NULL,
            
            -- Preços por fonte (BRL/sc60 para comparação direta)
            preco_b3_brl REAL,
            preco_cepea_brl REAL,
            preco_imea_brl REAL,
            preco_rondonopolis_brl REAL,
            preco_cme_usd REAL,
            
            -- Taxa câmbio para conversão
            usd_brl_rate REAL,
            preco_cme_brl_convertido REAL,
            
            -- Spreads calculados (diferenças)
            spread_b3_cepea REAL,
            spread_cepea_imea REAL,
            spread_imea_rondonopolis REAL,
            spread_b3_cme REAL,
            
            -- Basis (diferença futuro vs físico)
            basis_b3_cepea REAL,  -- B3 futuro vs CEPEA físico
            basis_b3_imea REAL,   -- B3 futuro vs IMEA físico
            
            -- Metadados
            data_atualizacao TEXT NOT NULL,
            fonte_dominante TEXT,  -- Qual fonte tem mais liquidez/volume
            
            UNIQUE(data_pregao, commodity)
        );
CREATE TABLE regions (
                    region_id INTEGER PRIMARY KEY,
                    name TEXT NOT NULL,
                    state TEXT NOT NULL,
                    centroid_lat REAL, 
                    centroid_lon REAL,
                    radius_km INTEGER DEFAULT 50,
                    active INTEGER DEFAULT 1
                );
CREATE TABLE municipalities (
                    muni_id INTEGER PRIMARY KEY,
                    name TEXT NOT NULL,
                    state TEXT NOT NULL,
                    ibge_code TEXT,
                    lat REAL, 
                    lon REAL,
                    region_id INTEGER,
                    FOREIGN KEY(region_id) REFERENCES regions(region_id)
                );
CREATE TABLE comp_offers (
                    offer_id INTEGER PRIMARY KEY,
                    dt DATE NOT NULL,
                    commodity TEXT CHECK(commodity IN ('soja','milho','boi')) NOT NULL,
                    actor TEXT NOT NULL,
                    region_id INTEGER,
                    muni_id INTEGER,
                    price_gross REAL NOT NULL,
                    deductions REAL DEFAULT 0,
                    quality_adj REAL DEFAULT 0,
                    freight_prod_to_origin REAL DEFAULT 0,
                    notes TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, buyer_id INTEGER, freight_to_buyer REAL DEFAULT 0,
                    UNIQUE (dt, commodity, actor, muni_id),
                    FOREIGN KEY(region_id) REFERENCES regions(region_id),
                    FOREIGN KEY(muni_id) REFERENCES municipalities(muni_id)
                );
CREATE TABLE comp_trades (
                    trade_id INTEGER PRIMARY KEY,
                    dt DATE NOT NULL,
                    commodity TEXT NOT NULL,
                    actor TEXT NOT NULL,
                    region_id INTEGER,
                    muni_id INTEGER,
                    price_net REAL NOT NULL,
                    volume REAL,
                    quality_json TEXT,
                    status TEXT CHECK(status IN ('executado','cancelado')) DEFAULT 'executado',
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY(region_id) REFERENCES regions(region_id),
                    FOREIGN KEY(muni_id) REFERENCES municipalities(muni_id)
                );
CREATE TABLE routes (
                    route_id INTEGER PRIMARY KEY,
                    origin_muni_id INTEGER,
                    dest_muni_id INTEGER,
                    km REAL,
                    avg_time_h REAL,
                    FOREIGN KEY(origin_muni_id) REFERENCES municipalities(muni_id),
                    FOREIGN KEY(dest_muni_id) REFERENCES municipalities(muni_id)
                );
CREATE TABLE freight_quotes (
                    freight_id INTEGER PRIMARY KEY,
                    dt DATE NOT NULL,
                    route_id INTEGER NOT NULL,
                    commodity TEXT,
                    price_r_per_t REAL,
                    congestion_index REAL DEFAULT 0,
                    source TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY(route_id) REFERENCES routes(route_id)
                );
CREATE TABLE basis_history (
                    id INTEGER PRIMARY KEY,
                    dt DATE NOT NULL,
                    commodity TEXT NOT NULL,
                    location TEXT NOT NULL,
                    basis_r_per_sc REAL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );
CREATE TABLE fx_rates (
                    dt DATE PRIMARY KEY,
                    usdbrl REAL NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );
CREATE TABLE futures_b3 (
                    id INTEGER PRIMARY KEY,
                    dt DATE NOT NULL,
                    symbol TEXT NOT NULL,
                    last REAL NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );
CREATE TABLE futures_cme (
                    id INTEGER PRIMARY KEY,
                    dt DATE NOT NULL,
                    symbol TEXT NOT NULL,
                    last REAL NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );
CREATE TABLE quality_standards (
                    id INTEGER PRIMARY KEY,
                    commodity TEXT NOT NULL,
                    param TEXT NOT NULL,
                    target REAL,
                    tolerance REAL DEFAULT 0.0
                );
CREATE TABLE quality_observed (
                    id INTEGER PRIMARY KEY,
                    dt DATE NOT NULL,
                    commodity TEXT NOT NULL,
                    region_id INTEGER,
                    muni_id INTEGER,
                    param TEXT NOT NULL,
                    value REAL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );
CREATE TABLE crm_scores (
                    id INTEGER PRIMARY KEY,
                    producer_id TEXT,
                    muni_id INTEGER,
                    recency_score REAL,
                    loyalty_score REAL,
                    satisfaction_score REAL,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );
CREATE TABLE competitiveness_config (
                    key TEXT PRIMARY KEY,
                    value TEXT NOT NULL,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );
CREATE TABLE icr_calculated (
                    id INTEGER PRIMARY KEY,
                    dt DATE NOT NULL,
                    commodity TEXT NOT NULL,
                    region_id INTEGER,
                    muni_id INTEGER,
                    icr INTEGER NOT NULL,
                    pr INTEGER NOT NULL,
                    lg INTEGER NOT NULL,
                    lq INTEGER NOT NULL,
                    ro INTEGER NOT NULL,
                    qs INTEGER NOT NULL,
                    rl INTEGER NOT NULL,
                    royal_net REAL,
                    comp_net_median REAL,
                    parity REAL,
                    advantage_r_per_unit REAL,
                    calculation_meta TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, buyer_id INTEGER, buyer_name TEXT,
                    UNIQUE(dt, commodity, region_id, muni_id)
                );
CREATE TABLE buyers (
    buyer_id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    type TEXT CHECK(type IN ('porto', 'fabrica', 'armazem', 'cooperativa', 'trader')) NOT NULL,
    city TEXT NOT NULL,
    state TEXT NOT NULL,
    country TEXT DEFAULT 'BR',
    lat REAL,
    lon REAL,
    active INTEGER DEFAULT 1,
    commodity_support TEXT, -- JSON array: ["soja", "milho", "boi"]
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE routes_to_buyer (
    route_id INTEGER PRIMARY KEY AUTOINCREMENT,
    origin_muni_id INTEGER NOT NULL,
    buyer_id INTEGER NOT NULL,
    transport_mode TEXT CHECK(transport_mode IN ('rodoviario', 'ferroviario', 'hidroviario', 'multimodal')) DEFAULT 'rodoviario',
    km_total REAL NOT NULL,
    km_rodoviario REAL DEFAULT 0,
    km_ferroviario REAL DEFAULT 0,
    km_hidroviario REAL DEFAULT 0,
    avg_time_hours REAL,
    toll_cost_r REAL DEFAULT 0,
    fuel_cost_r_per_km REAL DEFAULT 2.50,
    active INTEGER DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(origin_muni_id) REFERENCES municipalities(muni_id),
    FOREIGN KEY(buyer_id) REFERENCES buyers(buyer_id),
    UNIQUE(origin_muni_id, buyer_id, transport_mode)
);
CREATE TABLE freight_to_buyer (
    freight_id INTEGER PRIMARY KEY AUTOINCREMENT,
    dt DATE NOT NULL,
    route_id INTEGER NOT NULL,
    commodity TEXT CHECK(commodity IN ('soja','milho','boi')) NOT NULL,
    price_r_per_t REAL NOT NULL,
    fuel_surcharge_pct REAL DEFAULT 0,
    toll_surcharge_r REAL DEFAULT 0,
    congestion_factor REAL DEFAULT 1.0,
    seasonal_factor REAL DEFAULT 1.0,
    source TEXT, -- 'cepea', 'sifreca', 'manual', etc.
    quality TEXT, -- 'estimated', 'quoted', 'contracted'
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(route_id) REFERENCES routes_to_buyer(route_id)
);
CREATE TABLE buyer_configs (
    config_id INTEGER PRIMARY KEY AUTOINCREMENT,
    buyer_id INTEGER NOT NULL,
    config_key TEXT NOT NULL,
    config_value TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(buyer_id) REFERENCES buyers(buyer_id),
    UNIQUE(buyer_id, config_key)
);
CREATE TABLE icr_calculations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    calc_id TEXT NOT NULL UNIQUE,
    dt DATE NOT NULL,
    commodity TEXT NOT NULL,
    region_id INTEGER,
    muni_id INTEGER,
    buyer_id INTEGER,
    origin_muni_id INTEGER,
    
    icr_score INTEGER NOT NULL CHECK(icr_score BETWEEN 0 AND 100),
    
    pr_score INTEGER CHECK(pr_score BETWEEN 0 AND 100),
    lg_score INTEGER CHECK(lg_score BETWEEN 0 AND 100), 
    lq_score INTEGER CHECK(lq_score BETWEEN 0 AND 100),
    ro_score INTEGER CHECK(ro_score BETWEEN 0 AND 100),
    qs_score INTEGER CHECK(qs_score BETWEEN 0 AND 100),
    rl_score INTEGER CHECK(rl_score BETWEEN 0 AND 100),
    
    royal_net REAL,
    comp_net_median REAL,
    parity_value REAL,
    logistics_cost REAL,
    
    calculation_method TEXT DEFAULT 'extended_v2',
    input_params_json TEXT,
    breakdown_json TEXT,
    
    calculated_by TEXT DEFAULT 'system',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (buyer_id) REFERENCES buyers(buyer_id)
);
CREATE TABLE trades (
    trade_id INTEGER PRIMARY KEY AUTOINCREMENT,
    dt DATE NOT NULL,
    commodity TEXT NOT NULL,
    actor TEXT NOT NULL,
    muni_id INTEGER,
    price_net REAL NOT NULL,
    volume REAL NOT NULL,
    quality_json TEXT,
    status TEXT NOT NULL,
    buyer_id INTEGER,
    notes TEXT,
    external_contract_id TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (buyer_id) REFERENCES buyers(buyer_id)
);
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(50) NOT NULL DEFAULT 'viewer',
    active BOOLEAN DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_login DATETIME,
    login_attempts INTEGER DEFAULT 0,
    blocked_until DATETIME,
    token_reset VARCHAR(255),
    token_reset_expira DATETIME, is_active INTEGER DEFAULT 1,
    
    -- Índices para performance
    CHECK (role IN ('admin', 'manager', 'operator', 'viewer'))
);
CREATE TABLE user_sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    token VARCHAR(500) UNIQUE NOT NULL,
    ip_address VARCHAR(45),
    user_agent TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    expires_at DATETIME NOT NULL,
    active BOOLEAN DEFAULT 1,
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
CREATE TABLE auth_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    email VARCHAR(255),
    action VARCHAR(50) NOT NULL,
    success BOOLEAN NOT NULL,
    ip_address VARCHAR(45),
    user_agent TEXT,
    details TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);
CREATE TABLE empresas (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    razao_social TEXT NOT NULL,
    nome_fantasia TEXT,
    doc_hash TEXT NOT NULL UNIQUE, -- CPF/CNPJ tokenizado (hash irreversível) 
    doc_mascarado TEXT NOT NULL, -- Formato mascarado para exibição
    ie TEXT,
    endereco TEXT,
    cidade TEXT,
    uf TEXT,
    cep TEXT,
    telefone TEXT,
    email TEXT,
    dados_bancarios_json TEXT, -- JSON com dados bancários
    pix_chave TEXT,
    logomarca_uri TEXT,
    marca_dagua_uri TEXT,
    ativo BOOLEAN DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE partes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tipo TEXT NOT NULL CHECK (tipo IN ('comprador', 'vendedor')),
    nome_razao TEXT NOT NULL,
    doc_hash TEXT NOT NULL, -- CPF/CNPJ tokenizado
    doc_mascarado TEXT NOT NULL, -- Formato mascarado
    ie TEXT,
    endereco TEXT,
    cidade TEXT,
    uf TEXT,
    cep TEXT,
    telefone TEXT,
    email TEXT,
    obs TEXT,
    ativo BOOLEAN DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE produtos (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    nome TEXT NOT NULL,
    categoria TEXT NOT NULL CHECK (categoria IN ('graos', 'boi', 'algodao', 'subprodutos', 'outros')),
    unidade_precificacao TEXT NOT NULL CHECK (unidade_precificacao IN ('saca60kg', 'ton', 'unidade')),
    comissao_padrao_percent DECIMAL(5,3) DEFAULT NULL, -- Comissão padrão em %
    comissao_padrao_unitaria DECIMAL(10,2) DEFAULT NULL, -- Comissão por unidade
    ativo BOOLEAN DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE ofertas_pin_sequence (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    last_pin INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE ofertas (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    pin_seq INTEGER NOT NULL UNIQUE, -- PIN sequencial único não reaproveitado
    produto_id INTEGER NOT NULL,
    parte_principal_id INTEGER NOT NULL, -- ID da parte que fez a oferta
    tipo_parte_principal TEXT NOT NULL CHECK (tipo_parte_principal IN ('comprador', 'vendedor')),
    quantidade_sacas60 INTEGER, -- Quantidade em sacas de 60kg
    quantidade_ton DECIMAL(10,3), -- Quantidade em toneladas
    preco_unitario DECIMAL(10,2) NOT NULL, -- Preço por unidade
    modalidade TEXT NOT NULL CHECK (modalidade IN ('FOB', 'CIF')),
    local_retirada_entrega TEXT NOT NULL,
    janela_embarque_ini DATE,
    janela_embarque_fim DATE,
    condicao_pagamento_json TEXT, -- JSON com condições de pagamento
    funrural_tipo TEXT CHECK (funrural_tipo IN ('recolhimento_na_comercializacao', 'desconto_inss_folha', NULL)),
    status TEXT NOT NULL DEFAULT 'aberta' CHECK (status IN ('aberta', 'editada', 'cancelada', 'vinculada', 'fechada')),
    motivo_cancelamento TEXT, -- Obrigatório quando status = cancelada
    empresa_id INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    canceled_at TIMESTAMP DEFAULT NULL,
    FOREIGN KEY (produto_id) REFERENCES produtos(id),
    FOREIGN KEY (parte_principal_id) REFERENCES partes(id),
    FOREIGN KEY (empresa_id) REFERENCES empresas(id)
);
CREATE TABLE contratos_sequence (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    last_number INTEGER NOT NULL DEFAULT 0,
    prefixo TEXT NOT NULL DEFAULT 'RO',
    formato TEXT NOT NULL DEFAULT '{prefixo}{MMDD}-{YY}' -- Formato configurável
);
CREATE TABLE negocios (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    contrato_codigo TEXT NOT NULL UNIQUE, -- Código único do contrato
    oferta_id INTEGER NOT NULL,
    contraparte_id INTEGER NOT NULL, -- ID da contraparte que fechou o negócio
    quantidade_sacas60 INTEGER, -- Quantidade final em sacas
    quantidade_ton DECIMAL(10,3), -- Quantidade final em toneladas
    preco_unitario DECIMAL(10,2) NOT NULL, -- Preço final acordado
    valor_total DECIMAL(15,2) NOT NULL, -- Valor total do negócio
    comissao_modo TEXT NOT NULL DEFAULT 'padrao' CHECK (comissao_modo IN ('padrao', 'percentual', 'unitaria', 'personalizada')),
    comissao_valor_percent DECIMAL(5,3), -- % de comissão quando modo percentual
    comissao_valor_unitaria DECIMAL(10,2), -- Valor unitário quando modo unitário
    comissao_total DECIMAL(12,2) NOT NULL, -- Valor total da comissão calculada
    pagamento_regra_json TEXT, -- JSON com regras de pagamento
    embarque_janela_ini DATE,
    embarque_janela_fim DATE,
    funrural_tipo TEXT,
    modalidade TEXT NOT NULL,
    local_retirada_entrega TEXT NOT NULL,
    dados_pagamento_json TEXT, -- JSON com dados para pagamento/PIX
    foro_cidade TEXT DEFAULT 'Rondonópolis',
    foro_uf TEXT DEFAULT 'MT',
    empresa_id INTEGER NOT NULL,
    status_negocio TEXT NOT NULL DEFAULT 'em_confirmacao' CHECK (status_negocio IN ('em_confirmacao', 'confirmado', 'em_execucao', 'encerrado')),
    pdf_gerado BOOLEAN DEFAULT 0,
    pdf_path TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (oferta_id) REFERENCES ofertas(id),
    FOREIGN KEY (contraparte_id) REFERENCES partes(id),
    FOREIGN KEY (empresa_id) REFERENCES empresas(id)
);
CREATE TABLE acompanhamentos (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    negocio_id INTEGER NOT NULL,
    etapa TEXT NOT NULL CHECK (etapa IN ('pagamento', 'embarque', 'nota_fiscal', 'outros')),
    status TEXT NOT NULL DEFAULT 'pendente' CHECK (status IN ('pendente', 'em_andamento', 'concluido')),
    data_prevista DATE,
    data_realizada DATE,
    meta_json TEXT, -- JSON com metadados da etapa
    obs TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (negocio_id) REFERENCES negocios(id)
);
CREATE TABLE comissoes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    negocio_id INTEGER NOT NULL,
    produto_id INTEGER NOT NULL,
    regra_json TEXT, -- JSON com detalhes da regra aplicada
    valor_calculado DECIMAL(12,2) NOT NULL,
    liquidado BOOLEAN DEFAULT 0,
    liquidacao_data DATE,
    dados_recebimento_json TEXT, -- JSON com dados do recebimento
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (negocio_id) REFERENCES negocios(id),
    FOREIGN KEY (produto_id) REFERENCES produtos(id)
);
CREATE TABLE logs_auditoria (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    entidade TEXT NOT NULL, -- Nome da tabela
    entidade_id INTEGER NOT NULL, -- ID do registro
    acao TEXT NOT NULL, -- INSERT, UPDATE, DELETE, CANCEL, etc.
    usuario TEXT, -- Usuário que executou a ação
    ip TEXT, -- IP de origem
    diff_json TEXT, -- JSON com as diferenças (antes/depois)
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE usuarios_permissoes (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                usuario_id INTEGER NOT NULL,
                permissao TEXT NOT NULL,
                ativo BOOLEAN DEFAULT 1,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (usuario_id) REFERENCES users(id) ON DELETE CASCADE
            );
CREATE TABLE logs_auditoria_lgpd (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                usuario_id INTEGER,
                entidade TEXT NOT NULL,
                entidade_id INTEGER,
                acao TEXT NOT NULL,
                ip_address TEXT,
                user_agent TEXT,
                dados_json TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (usuario_id) REFERENCES users(id) ON DELETE SET NULL
            );
CREATE TABLE whatsapp_messages (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          message_id TEXT UNIQUE,
          from_jid TEXT,
          to_jid TEXT,
          message_type TEXT,
          message_content TEXT,
          media_url TEXT,
          timestamp INTEGER,
          status TEXT,
          instance_name TEXT,
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );
CREATE TABLE whatsapp_contacts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          jid TEXT UNIQUE,
          name TEXT,
          phone TEXT,
          profile_pic_url TEXT,
          instance_name TEXT,
          is_business BOOLEAN DEFAULT 0,
          last_seen INTEGER,
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );
CREATE TABLE whatsapp_groups (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          group_jid TEXT UNIQUE,
          group_name TEXT,
          group_description TEXT,
          instance_name TEXT,
          participant_count INTEGER,
          is_admin BOOLEAN DEFAULT 0,
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );
CREATE TABLE whatsapp_sessions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          instance_name TEXT UNIQUE,
          instance_id TEXT,
          connection_status TEXT,
          owner_jid TEXT,
          profile_name TEXT,
          phone_number TEXT,
          last_qr_code TEXT,
          last_connected DATETIME,
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );
CREATE TABLE clima_inmet (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            estacao_codigo VARCHAR(20) NOT NULL,
            estacao_nome VARCHAR(200),
            uf VARCHAR(2) NOT NULL,
            municipio VARCHAR(100),
            temperatura REAL,
            umidade REAL,
            precipitacao REAL,
            vento_velocidade REAL,
            pressao REAL,
            data_coleta DATETIME DEFAULT CURRENT_TIMESTAMP,
            UNIQUE(estacao_codigo, data_coleta)
        );
CREATE TABLE sqlite_stat1(tbl,idx,stat);
CREATE INDEX idx_usuarios_email ON usuarios(email);
CREATE INDEX idx_whatsapp_conversas_numero ON whatsapp_conversas(numero_telefone);
CREATE INDEX idx_whatsapp_conversas_timestamp ON whatsapp_conversas(timestamp);
CREATE INDEX idx_dados_mercado_commodity ON dados_mercado(commodity);
CREATE INDEX idx_dados_mercado_data ON dados_mercado(data_coleta);
CREATE INDEX idx_logs_timestamp ON logs_sistema(timestamp);
CREATE INDEX idx_heartbeats_agent_timestamp ON agentes_heartbeats(agent_id, timestamp DESC);
CREATE INDEX idx_metrics_name_time ON analytics_metrics(metric_name, timestamp DESC);
CREATE INDEX idx_reports_type_period ON analytics_reports(report_type, period_start);
CREATE INDEX idx_workflows_status ON automation_workflows(status);
CREATE INDEX idx_executions_status ON automation_executions(status, started_at);
CREATE INDEX idx_tasks_schedule ON automation_tasks(status, next_execution);
CREATE INDEX idx_noticias_published_at ON noticias(published_at DESC);
CREATE INDEX idx_noticias_region ON noticias(region);
CREATE INDEX idx_noticias_source ON noticias(source);
CREATE INDEX idx_dm_commodity_data ON dados_mercado(commodity, data_coleta DESC);
CREATE INDEX idx_dm_regiao ON dados_mercado(regiao);
CREATE INDEX idx_prices_commodity ON prices(commodity, timestamp DESC);
CREATE INDEX idx_api_logs_user ON api_logs(user_id, timestamp DESC);
CREATE INDEX idx_fx_ticks_pair_ts ON fx_ticks(pair, ts_local DESC);
CREATE INDEX idx_fx_pair_time ON fx_ticks(pair, ts_local DESC);
CREATE UNIQUE INDEX idx_fx_unique_tick ON fx_ticks(pair, ts_local);
CREATE INDEX idx_cepea_series_commodity_praca_date ON cepea_series(commodity, praca, effective_date DESC);
CREATE INDEX idx_dados_mercado_commodity_regiao_date ON dados_mercado(commodity, regiao, data_coleta DESC);
CREATE INDEX idx_imea_commodity_praca_date ON imea_series(commodity, praca, effective_date DESC);
CREATE INDEX idx_imea_hash_dedupe ON imea_series(hash_dedupe);
CREATE INDEX idx_offers_commodity ON offers(commodity);
CREATE INDEX idx_offers_lado ON offers(lado);
CREATE INDEX idx_offers_praca ON offers(praca);
CREATE INDEX idx_offers_created_at ON offers(created_at);
CREATE INDEX idx_offers_deleted_at ON offers(deleted_at);
CREATE INDEX idx_offers_active ON offers(deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX idx_dados_mercado_date_symbol_source ON dados_mercado(data_coleta, commodity, fonte);
CREATE INDEX idx_historicos_fonte_commodity ON dados_historicos(fonte, commodity);
CREATE INDEX idx_historicos_data_pregao ON dados_historicos(data_pregao);
CREATE INDEX idx_historicos_regiao ON dados_historicos(regiao);
CREATE INDEX idx_historicos_spread_analysis ON dados_historicos(commodity, data_pregao, fonte, regiao);
CREATE INDEX idx_analise_data_commodity ON analise_historica(data_pregao, commodity);
CREATE INDEX idx_analise_spreads ON analise_historica(commodity, spread_b3_cepea, spread_cepea_imea);
CREATE INDEX idx_analise_basis ON analise_historica(commodity, basis_b3_cepea, basis_b3_imea);
CREATE INDEX idx_regions_name ON regions(name);
CREATE INDEX idx_muni_region ON municipalities(region_id);
CREATE INDEX idx_comp_offers_dt_comm ON comp_offers(dt, commodity);
CREATE INDEX idx_comp_offers_actor ON comp_offers(actor);
CREATE INDEX idx_comp_trades_dt_comm ON comp_trades(dt, commodity);
CREATE INDEX idx_freight_dt_route ON freight_quotes(dt, route_id);
CREATE INDEX idx_basis_dt_comm_loc ON basis_history(dt, commodity, location);
CREATE INDEX idx_futures_b3_dt_symbol ON futures_b3(dt, symbol);
CREATE INDEX idx_futures_cme_dt_symbol ON futures_cme(dt, symbol);
CREATE INDEX idx_quality_std_comm_param ON quality_standards(commodity, param);
CREATE INDEX idx_quality_obs_dt_comm ON quality_observed(dt, commodity);
CREATE INDEX idx_crm_producer ON crm_scores(producer_id);
CREATE INDEX idx_icr_dt_comm ON icr_calculated(dt, commodity);
CREATE INDEX idx_buyers_type ON buyers(type);
CREATE INDEX idx_buyers_active ON buyers(active);
CREATE INDEX idx_buyers_city_state ON buyers(city, state);
CREATE INDEX idx_routes_buyer_origin ON routes_to_buyer(origin_muni_id, buyer_id);
CREATE INDEX idx_routes_buyer_mode ON routes_to_buyer(transport_mode);
CREATE INDEX idx_freight_buyer_dt_commodity ON freight_to_buyer(dt, commodity);
CREATE INDEX idx_freight_buyer_route ON freight_to_buyer(route_id);
CREATE INDEX idx_comp_offers_buyer ON comp_offers(buyer_id);
CREATE INDEX idx_icr_calculated_buyer ON icr_calculated(buyer_id);
CREATE UNIQUE INDEX idx_icr_calculated_unique_buyer ON icr_calculated(dt, commodity, region_id, COALESCE(muni_id, 0), COALESCE(buyer_id, 0));
CREATE INDEX idx_buyer_configs_buyer_key ON buyer_configs(buyer_id, config_key);
CREATE INDEX idx_icr_calc_dt_commodity ON icr_calculations(dt, commodity);
CREATE INDEX idx_icr_calc_buyer ON icr_calculations(buyer_id, dt);
CREATE INDEX idx_icr_calc_score ON icr_calculations(icr_score DESC);
CREATE INDEX idx_icr_calc_id ON icr_calculations(calc_id);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_active ON users(active);
CREATE INDEX idx_sessions_token ON user_sessions(token);
CREATE INDEX idx_sessions_expires ON user_sessions(expires_at);
CREATE INDEX idx_auth_logs_user_id ON auth_logs(user_id);
CREATE INDEX idx_auth_logs_email ON auth_logs(email);
CREATE INDEX idx_auth_logs_created_at ON auth_logs(created_at);
CREATE INDEX idx_ofertas_pin_seq ON ofertas(pin_seq);
CREATE INDEX idx_ofertas_produto ON ofertas(produto_id);
CREATE INDEX idx_ofertas_status ON ofertas(status);
CREATE INDEX idx_ofertas_parte ON ofertas(parte_principal_id);
CREATE INDEX idx_ofertas_empresa ON ofertas(empresa_id);
CREATE INDEX idx_ofertas_created_at ON ofertas(created_at);
CREATE INDEX idx_negocios_contrato ON negocios(contrato_codigo);
CREATE INDEX idx_negocios_oferta ON negocios(oferta_id);
CREATE INDEX idx_negocios_status ON negocios(status_negocio);
CREATE INDEX idx_negocios_empresa ON negocios(empresa_id);
CREATE INDEX idx_negocios_created_at ON negocios(created_at);
CREATE INDEX idx_partes_doc_hash ON partes(doc_hash);
CREATE INDEX idx_partes_tipo ON partes(tipo);
CREATE INDEX idx_empresas_doc_hash ON empresas(doc_hash);
CREATE INDEX idx_acompanhamentos_negocio ON acompanhamentos(negocio_id);
CREATE INDEX idx_acompanhamentos_etapa ON acompanhamentos(etapa);
CREATE INDEX idx_acompanhamentos_status ON acompanhamentos(status);
CREATE INDEX idx_logs_entidade ON logs_auditoria(entidade, entidade_id);
CREATE INDEX idx_logs_usuario ON logs_auditoria(usuario);
CREATE INDEX idx_logs_created_at ON logs_auditoria(created_at);
CREATE INDEX idx_usuarios_permissoes_usuario_id ON usuarios_permissoes(usuario_id);
CREATE INDEX idx_usuarios_permissoes_permissao ON usuarios_permissoes(permissao);
CREATE INDEX idx_logs_auditoria_lgpd_usuario_id ON logs_auditoria_lgpd(usuario_id);
CREATE INDEX idx_logs_auditoria_lgpd_entidade ON logs_auditoria_lgpd(entidade);
CREATE INDEX idx_logs_auditoria_lgpd_created_at ON logs_auditoria_lgpd(created_at);
CREATE INDEX idx_messages_timestamp ON whatsapp_messages(timestamp);
CREATE INDEX idx_messages_from ON whatsapp_messages(from_jid);
CREATE INDEX idx_contacts_jid ON whatsapp_contacts(jid);
CREATE INDEX idx_groups_jid ON whatsapp_groups(group_jid);
CREATE INDEX idx_clima_inmet_uf_data ON clima_inmet(uf, data_coleta DESC);
CREATE INDEX idx_clima_inmet_municipio ON clima_inmet(municipio);
CREATE VIEW v_cepea_dados AS 
                     SELECT commodity, praca, unit, price, effective_date 
                     FROM cepea_series 
                     ORDER BY effective_date DESC, commodity, praca
/* v_cepea_dados(commodity,praca,unit,price,effective_date) */;
CREATE TRIGGER offers_updated_at
    AFTER UPDATE ON offers
    FOR EACH ROW
BEGIN
    UPDATE offers SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;
CREATE VIEW active_offers AS
SELECT * FROM offers WHERE deleted_at IS NULL
/* active_offers(id,seller,produto,lado,preco,unidade,quantidade,praca,commodity,fonte,created_at,updated_at,deleted_at,ttl_dias,buyer_id,icr_score,icr_sub_json,parity_used,logistics_used_json,icr_calc_id,icr_calculated_at) */;
CREATE VIEW offers_stats AS
SELECT 
    commodity,
    lado,
    COUNT(*) as total_ofertas,
    AVG(preco) as preco_medio,
    MIN(preco) as preco_min,
    MAX(preco) as preco_max,
    SUM(quantidade) as quantidade_total
FROM active_offers
GROUP BY commodity, lado
/* offers_stats(commodity,lado,total_ofertas,preco_medio,preco_min,preco_max,quantidade_total) */;
CREATE VIEW offers_active AS SELECT * FROM offers WHERE deleted_at IS NULL
/* offers_active(id,seller,produto,lado,preco,unidade,quantidade,praca,commodity,fonte,created_at,updated_at,deleted_at,ttl_dias,buyer_id,icr_score,icr_sub_json,parity_used,logistics_used_json,icr_calc_id,icr_calculated_at) */;
CREATE TRIGGER trg_ofertas_updated_at 
    AFTER UPDATE ON ofertas
BEGIN
    UPDATE ofertas SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;
CREATE TRIGGER trg_negocios_updated_at 
    AFTER UPDATE ON negocios
BEGIN
    UPDATE negocios SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;
CREATE TRIGGER trg_partes_updated_at 
    AFTER UPDATE ON partes
BEGIN
    UPDATE partes SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;
CREATE TRIGGER trg_empresas_updated_at 
    AFTER UPDATE ON empresas
BEGIN
    UPDATE empresas SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;
CREATE TRIGGER trg_audit_ofertas_insert 
    AFTER INSERT ON ofertas
BEGIN
    INSERT INTO logs_auditoria (entidade, entidade_id, acao, diff_json)
    VALUES ('ofertas', NEW.id, 'INSERT', 
        json_object('new', json_object(
            'pin_seq', NEW.pin_seq,
            'produto_id', NEW.produto_id,
            'status', NEW.status,
            'preco_unitario', NEW.preco_unitario
        ))
    );
END;
CREATE TRIGGER trg_audit_ofertas_update 
    AFTER UPDATE ON ofertas
BEGIN
    INSERT INTO logs_auditoria (entidade, entidade_id, acao, diff_json)
    VALUES ('ofertas', NEW.id, 'UPDATE', 
        json_object(
            'old', json_object('status', OLD.status, 'preco_unitario', OLD.preco_unitario),
            'new', json_object('status', NEW.status, 'preco_unitario', NEW.preco_unitario)
        )
    );
END;
CREATE TRIGGER trg_audit_negocios_insert 
    AFTER INSERT ON negocios
BEGIN
    INSERT INTO logs_auditoria (entidade, entidade_id, acao, diff_json)
    VALUES ('negocios', NEW.id, 'INSERT',
        json_object('new', json_object(
            'contrato_codigo', NEW.contrato_codigo,
            'valor_total', NEW.valor_total,
            'status_negocio', NEW.status_negocio
        ))
    );
END;
CREATE TRIGGER trg_audit_negocios_update 
    AFTER UPDATE ON negocios
BEGIN
    INSERT INTO logs_auditoria (entidade, entidade_id, acao, diff_json)
    VALUES ('negocios', NEW.id, 'UPDATE',
        json_object(
            'old', json_object('status_negocio', OLD.status_negocio),
            'new', json_object('status_negocio', NEW.status_negocio)
        )
    );
END;
CREATE VIEW vw_ofertas_detalhadas AS
SELECT 
    o.id,
    o.pin_seq,
    o.status,
    p.nome AS produto_nome,
    p.categoria AS produto_categoria,
    pt.nome_razao AS parte_nome,
    pt.doc_mascarado AS parte_documento,
    o.tipo_parte_principal,
    o.quantidade_sacas60,
    o.quantidade_ton,
    o.preco_unitario,
    o.modalidade,
    o.local_retirada_entrega,
    o.janela_embarque_ini,
    o.janela_embarque_fim,
    e.nome_fantasia AS empresa_nome,
    o.created_at
FROM ofertas o
    JOIN produtos p ON o.produto_id = p.id
    JOIN partes pt ON o.parte_principal_id = pt.id
    JOIN empresas e ON o.empresa_id = e.id
/* vw_ofertas_detalhadas(id,pin_seq,status,produto_nome,produto_categoria,parte_nome,parte_documento,tipo_parte_principal,quantidade_sacas60,quantidade_ton,preco_unitario,modalidade,local_retirada_entrega,janela_embarque_ini,janela_embarque_fim,empresa_nome,created_at) */;
CREATE VIEW vw_negocios_detalhados AS
SELECT 
    n.id,
    n.contrato_codigo,
    n.status_negocio,
    o.pin_seq AS oferta_pin,
    p.nome AS produto_nome,
    comprador.nome_razao AS comprador_nome,
    comprador.doc_mascarado AS comprador_documento,
    vendedor.nome_razao AS vendedor_nome,
    vendedor.doc_mascarado AS vendedor_documento,
    n.quantidade_sacas60,
    n.quantidade_ton,
    n.preco_unitario,
    n.valor_total,
    n.comissao_total,
    n.modalidade,
    n.local_retirada_entrega,
    e.nome_fantasia AS empresa_nome,
    n.created_at,
    n.pdf_gerado
FROM negocios n
    JOIN ofertas o ON n.oferta_id = o.id
    JOIN produtos p ON o.produto_id = p.id
    JOIN empresas e ON n.empresa_id = e.id
    JOIN partes comprador ON (
        CASE 
            WHEN o.tipo_parte_principal = 'comprador' THEN o.parte_principal_id = comprador.id
            ELSE n.contraparte_id = comprador.id
        END
    ) AND comprador.tipo = 'comprador'
    JOIN partes vendedor ON (
        CASE 
            WHEN o.tipo_parte_principal = 'vendedor' THEN o.parte_principal_id = vendedor.id
            ELSE n.contraparte_id = vendedor.id
        END
    ) AND vendedor.tipo = 'vendedor'
/* vw_negocios_detalhados(id,contrato_codigo,status_negocio,oferta_pin,produto_nome,comprador_nome,comprador_documento,vendedor_nome,vendedor_documento,quantidade_sacas60,quantidade_ton,preco_unitario,valor_total,comissao_total,modalidade,local_retirada_entrega,empresa_nome,created_at,pdf_gerado) */;
CREATE TRIGGER trg_ofertas_validate_cancelamento
    BEFORE UPDATE ON ofertas
    WHEN NEW.status = 'cancelada' AND NEW.motivo_cancelamento IS NULL
BEGIN
    SELECT RAISE(ABORT, 'Motivo de cancelamento é obrigatório');
END;
CREATE TRIGGER trg_negocios_validate_quantidades
    BEFORE INSERT ON negocios
    WHEN NEW.quantidade_sacas60 IS NULL AND NEW.quantidade_ton IS NULL
BEGIN
    SELECT RAISE(ABORT, 'Pelo menos uma quantidade (sacas ou toneladas) deve ser informada');
END;
CREATE TRIGGER trg_negocios_validate_valor_total
    BEFORE INSERT ON negocios
    WHEN (COALESCE(NEW.quantidade_sacas60, 0) + COALESCE(NEW.quantidade_ton, 0)) * NEW.preco_unitario != NEW.valor_total
BEGIN
    SELECT RAISE(ABORT, 'Valor total não confere com quantidade x preço unitário');
END;
CREATE VIEW v_dados_mercado_with_timestamp AS 
SELECT *, data_coleta as timestamp FROM dados_mercado
/* v_dados_mercado_with_timestamp(id,commodity,preco,variacao,volume,data_coleta,fonte,regiao,tendencia,timestamp) */;
CREATE TRIGGER trigger_anti_mock_imea
    BEFORE INSERT ON imea_series
    FOR EACH ROW
    WHEN NEW.effective_date IN ('1970-01-01', '2000-01-01', '2024-01-01', '2025-01-01')
      OR DATE(NEW.collected_at) IN ('1970-01-01', '2000-01-01', '2024-01-01')
      OR TIME(NEW.collected_at) = '12:00:00'
      OR TIME(NEW.collected_at) = '00:00:00'
      OR NEW.effective_date > DATE('now')
      OR NEW.price <= 0
      OR NEW.price IS NULL
    BEGIN
        SELECT RAISE(ABORT, 'REJECTED: Dados simulados detectados em IMEA Series - Operação Anti-Mock');
    END;
CREATE TRIGGER trigger_anti_mock_inmet  
    BEFORE INSERT ON clima_inmet
    FOR EACH ROW  
    WHEN DATE(NEW.data_coleta) IN ('1970-01-01', '2000-01-01', '2024-01-01')
      OR TIME(NEW.data_coleta) = '12:00:00'
      OR TIME(NEW.data_coleta) = '00:00:00'
      OR NEW.data_coleta > DATETIME('now')
    BEGIN
        SELECT RAISE(ABORT, 'REJECTED: Dados simulados detectados em CLIMA INMET - Operação Anti-Mock');
    END;
CREATE TRIGGER trigger_anti_mock_mercado
    BEFORE INSERT ON dados_mercado
    FOR EACH ROW
    WHEN DATE(NEW.data_coleta) IN ('1970-01-01', '2000-01-01', '2024-01-01')
      OR TIME(NEW.data_coleta) = '12:00:00'
      OR NEW.preco = 0 OR NEW.preco IS NULL
    BEGIN
        SELECT RAISE(ABORT, 'REJECTED: Dados simulados detectados em DADOS MERCADO - Operação Anti-Mock');
    END;
CREATE TRIGGER trigger_anti_mock_noticias
    BEFORE INSERT ON noticias
    FOR EACH ROW
    WHEN LOWER(NEW.titulo) LIKE '%mock%' OR LOWER(NEW.titulo) LIKE '%test%' OR LOWER(NEW.titulo) LIKE '%fake%'
      OR LOWER(NEW.titulo) LIKE '%sample%' OR LOWER(NEW.titulo) LIKE '%simulado%' OR LOWER(NEW.titulo) LIKE '%demo%'
      OR LOWER(NEW.conteudo) LIKE '%mock%' OR LOWER(NEW.conteudo) LIKE '%test%' OR LOWER(NEW.conteudo) LIKE '%fake%'
    BEGIN  
        SELECT RAISE(ABORT, 'REJECTED: Conteúdo simulado detectado em NOTICIAS - Operação Anti-Mock');
    END;
CREATE TRIGGER trigger_anti_mock_ofertas
    BEFORE INSERT ON ofertas
    FOR EACH ROW
    WHEN LOWER(NEW.descricao) LIKE '%mock%' OR LOWER(NEW.descricao) LIKE '%test%' OR LOWER(NEW.descricao) LIKE '%fake%'
      OR LOWER(NEW.descricao) LIKE '%sample%' OR LOWER(NEW.descricao) LIKE '%simulado%' OR LOWER(NEW.descricao) LIKE '%demo%'
      OR NEW.preco_unitario = 0 OR NEW.preco_unitario IS NULL
    BEGIN
        SELECT RAISE(ABORT, 'REJECTED: Oferta simulada detectada - Operação Anti-Mock');
    END;
CREATE TRIGGER prevent_mock_dados_mercado 
BEFORE INSERT ON dados_mercado 
FOR EACH ROW 
WHEN (NEW.preco = 999.99 OR NEW.preco = 123.45 OR NEW.preco = 100.00 OR NEW.commodity LIKE '%TEST%' OR NEW.commodity LIKE '%MOCK%')
BEGIN
  SELECT RAISE(ABORT, 'MOCK DATA BLOCKED: Dados simulados não são permitidos');
END;
CREATE TABLE licenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        license_key TEXT UNIQUE NOT NULL,
        client_id TEXT,
        active BOOLEAN DEFAULT 0,
        plan TEXT DEFAULT 'basic',
        expires_at DATETIME,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );
