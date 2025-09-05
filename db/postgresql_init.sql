-- Inicialização do Banco de Dados PostgreSQL para SPR
-- Sistema Preditivo Royal - Commodities Agrícolas

-- Criar extensões necessárias
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Configurar timezone
SET timezone = 'America/Cuiaba';

-- Criar usuário específico para a aplicação se não existir
DO $$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'spr_user') THEN
      CREATE ROLE spr_user LOGIN PASSWORD 'spr_password';
   END IF;
END
$$;

-- Garantir permissões no banco
GRANT ALL PRIVILEGES ON DATABASE spr_db TO spr_user;
GRANT ALL PRIVILEGES ON SCHEMA public TO spr_user;

-- Criar índices específicos para performance de consultas
-- Os índices das tabelas serão criados pelo SQLAlchemy automaticamente

-- Configurações de performance
ALTER SYSTEM SET shared_preload_libraries = 'pg_stat_statements';
ALTER SYSTEM SET pg_stat_statements.track = 'all';

-- Configurar memória para operações de commodities
ALTER SYSTEM SET work_mem = '256MB';
ALTER SYSTEM SET effective_cache_size = '1GB';

-- Log de consultas lentas (> 1 segundo)
ALTER SYSTEM SET log_min_duration_statement = 1000;

-- Comentários informativos
COMMENT ON DATABASE spr_db IS 'Sistema Preditivo Royal - Banco de dados para análise de commodities agrícolas';

-- Função para atualizar timestamps automaticamente
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Função para logging de operações críticas
CREATE OR REPLACE FUNCTION log_price_changes()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO price_change_log (commodity_id, old_price, new_price, change_timestamp)
    VALUES (NEW.commodity_id, OLD.price, NEW.price, CURRENT_TIMESTAMP);
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Criar tabela de log de mudanças de preços
CREATE TABLE IF NOT EXISTS price_change_log (
    id SERIAL PRIMARY KEY,
    commodity_id INTEGER,
    old_price NUMERIC(10,2),
    new_price NUMERIC(10,2),
    change_timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Configurações específicas para o usuário spr_user
ALTER ROLE spr_user SET timezone = 'America/Cuiaba';
ALTER ROLE spr_user SET default_transaction_isolation = 'read committed';

-- Sucesso
SELECT 'SPR Database initialized successfully!' as status;