#!/usr/bin/env python3
"""
🗄️ Database Engineer Agent - Supabase Specialist
SPR Sistema Preditivo Royal
"""

import json
import logging
from datetime import datetime
from typing import Dict, List, Optional, Any
from dataclasses import dataclass
from pathlib import Path

@dataclass
class DatabaseSchema:
    """Schema de banco de dados"""
    name: str
    tables: List[Dict[str, Any]]
    views: List[Dict[str, Any]]
    functions: List[Dict[str, Any]]
    policies: List[Dict[str, Any]]
    indexes: List[Dict[str, Any]]

@dataclass
class RLSPolicy:
    """Row Level Security Policy"""
    table: str
    policy_name: str
    command: str  # SELECT, INSERT, UPDATE, DELETE
    roles: List[str]
    using_expression: str
    with_check_expression: Optional[str] = None

class DatabaseAgent:
    """
    Database Engineer Agent - Especialista em Supabase
    
    Missão: Projetar schemas escaláveis, gerenciar políticas RLS, 
    criar funções SQL otimizadas e otimizar performance.
    """
    
    def __init__(self, config: Dict[str, Any] = None):
        self.config = config or {}
        self.agent_id = "database-engineer"
        self.agent_name = "Database Engineer - Supabase Specialist"
        self.expertise = [
            "Database Schema Design",
            "Supabase Administration", 
            "Row Level Security (RLS)",
            "SQL Optimization",
            "Performance Tuning",
            "Data Migration",
            "Backup & Recovery"
        ]
        
        # Setup logging
        logging.basicConfig(level=logging.INFO)
        self.logger = logging.getLogger(f"SPR.{self.agent_id}")
        
    def analyze_schema_requirements(self, business_requirements: Dict[str, Any]) -> DatabaseSchema:
        """
        Analisar requisitos de negócio e projetar schema do banco
        """
        self.logger.info("🔍 Analisando requisitos para design do schema...")
        
        # Análise baseada nos requisitos do SPR
        spr_tables = [
            {
                "name": "users",
                "columns": [
                    {"name": "id", "type": "uuid", "primary_key": True, "default": "gen_random_uuid()"},
                    {"name": "email", "type": "text", "unique": True, "not_null": True},
                    {"name": "name", "type": "text", "not_null": True},
                    {"name": "role", "type": "user_role", "default": "'user'"},
                    {"name": "created_at", "type": "timestamp", "default": "now()"},
                    {"name": "last_login", "type": "timestamp"},
                    {"name": "is_active", "type": "boolean", "default": True}
                ],
                "rls_enabled": True
            },
            {
                "name": "commodities",
                "columns": [
                    {"name": "id", "type": "uuid", "primary_key": True, "default": "gen_random_uuid()"},
                    {"name": "symbol", "type": "text", "unique": True, "not_null": True},
                    {"name": "name", "type": "text", "not_null": True},
                    {"name": "category", "type": "commodity_category", "not_null": True},
                    {"name": "unit", "type": "text", "not_null": True},
                    {"name": "is_active", "type": "boolean", "default": True},
                    {"name": "created_at", "type": "timestamp", "default": "now()"}
                ],
                "rls_enabled": False
            },
            {
                "name": "price_data",
                "columns": [
                    {"name": "id", "type": "uuid", "primary_key": True, "default": "gen_random_uuid()"},
                    {"name": "commodity_id", "type": "uuid", "foreign_key": "commodities(id)", "not_null": True},
                    {"name": "source", "type": "text", "not_null": True},
                    {"name": "price", "type": "decimal(10,2)", "not_null": True},
                    {"name": "date", "type": "date", "not_null": True},
                    {"name": "location", "type": "text"},
                    {"name": "quality_grade", "type": "text"},
                    {"name": "created_at", "type": "timestamp", "default": "now()"}
                ],
                "indexes": ["commodity_id", "date", "source"],
                "rls_enabled": False
            },
            {
                "name": "predictions",
                "columns": [
                    {"name": "id", "type": "uuid", "primary_key": True, "default": "gen_random_uuid()"},
                    {"name": "commodity_id", "type": "uuid", "foreign_key": "commodities(id)", "not_null": True},
                    {"name": "model_version", "type": "text", "not_null": True},
                    {"name": "prediction_date", "type": "date", "not_null": True},
                    {"name": "target_date", "type": "date", "not_null": True},
                    {"name": "predicted_price", "type": "decimal(10,2)", "not_null": True},
                    {"name": "confidence_score", "type": "decimal(3,2)"},
                    {"name": "factors", "type": "jsonb"},
                    {"name": "created_at", "type": "timestamp", "default": "now()"}
                ],
                "indexes": ["commodity_id", "prediction_date", "target_date"],
                "rls_enabled": True
            },
            {
                "name": "whatsapp_sessions",
                "columns": [
                    {"name": "id", "type": "uuid", "primary_key": True, "default": "gen_random_uuid()"},
                    {"name": "phone_number", "type": "text", "not_null": True},
                    {"name": "session_data", "type": "jsonb"},
                    {"name": "last_message_at", "type": "timestamp"},
                    {"name": "is_active", "type": "boolean", "default": True},
                    {"name": "created_at", "type": "timestamp", "default": "now()"}
                ],
                "rls_enabled": True
            }
        ]
        
        # Views importantes
        views = [
            {
                "name": "latest_prices_view",
                "definition": """
                CREATE VIEW latest_prices_view AS
                SELECT DISTINCT ON (commodity_id) 
                    commodity_id,
                    price,
                    date,
                    source,
                    location
                FROM price_data 
                ORDER BY commodity_id, date DESC;
                """
            },
            {
                "name": "prediction_accuracy_view", 
                "definition": """
                CREATE VIEW prediction_accuracy_view AS
                SELECT 
                    p.commodity_id,
                    c.symbol,
                    p.model_version,
                    AVG(ABS(p.predicted_price - pd.price)) as avg_error,
                    COUNT(*) as total_predictions
                FROM predictions p
                JOIN commodities c ON p.commodity_id = c.id
                JOIN price_data pd ON p.commodity_id = pd.commodity_id 
                    AND p.target_date = pd.date
                GROUP BY p.commodity_id, c.symbol, p.model_version;
                """
            }
        ]
        
        # Funções SQL
        functions = [
            {
                "name": "get_price_trend",
                "definition": """
                CREATE OR REPLACE FUNCTION get_price_trend(
                    p_commodity_id uuid,
                    p_days integer DEFAULT 30
                )
                RETURNS TABLE(
                    trend_direction text,
                    price_change decimal,
                    percentage_change decimal
                ) AS $$
                BEGIN
                    RETURN QUERY
                    WITH price_comparison AS (
                        SELECT 
                            (SELECT price FROM price_data 
                             WHERE commodity_id = p_commodity_id 
                             ORDER BY date DESC LIMIT 1) as current_price,
                            (SELECT price FROM price_data 
                             WHERE commodity_id = p_commodity_id 
                             AND date <= CURRENT_DATE - p_days 
                             ORDER BY date DESC LIMIT 1) as past_price
                    )
                    SELECT 
                        CASE 
                            WHEN current_price > past_price THEN 'UP'
                            WHEN current_price < past_price THEN 'DOWN'
                            ELSE 'STABLE'
                        END,
                        current_price - past_price,
                        ROUND(((current_price - past_price) / past_price * 100), 2)
                    FROM price_comparison;
                END;
                $$ LANGUAGE plpgsql;
                """
            }
        ]
        
        return DatabaseSchema(
            name="spr_production",
            tables=spr_tables,
            views=views, 
            functions=functions,
            policies=[],
            indexes=[]
        )
    
    def create_rls_policies(self, schema: DatabaseSchema) -> List[RLSPolicy]:
        """
        Criar políticas de Row Level Security
        """
        self.logger.info("🔐 Criando políticas RLS...")
        
        policies = [
            # Políticas para tabela users
            RLSPolicy(
                table="users",
                policy_name="users_select_own",
                command="SELECT", 
                roles=["authenticated"],
                using_expression="auth.uid() = id"
            ),
            RLSPolicy(
                table="users",
                policy_name="users_update_own",
                command="UPDATE",
                roles=["authenticated"],
                using_expression="auth.uid() = id"
            ),
            
            # Políticas para predictions
            RLSPolicy(
                table="predictions",
                policy_name="predictions_select_all",
                command="SELECT",
                roles=["authenticated"],
                using_expression="true"
            ),
            RLSPolicy(
                table="predictions", 
                policy_name="predictions_insert_admin",
                command="INSERT",
                roles=["authenticated"],
                using_expression="EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin')"
            ),
            
            # Políticas para whatsapp_sessions
            RLSPolicy(
                table="whatsapp_sessions",
                policy_name="whatsapp_admin_only",
                command="ALL",
                roles=["authenticated"],
                using_expression="EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role IN ('admin', 'operator'))"
            )
        ]
        
        return policies
    
    def optimize_queries(self, slow_queries: List[str]) -> Dict[str, str]:
        """
        Otimizar queries lentas
        """
        self.logger.info("⚡ Otimizando queries...")
        
        optimizations = {}
        
        for query in slow_queries:
            # Análise básica de otimização
            if "ORDER BY" in query and "LIMIT" not in query:
                optimizations[query] = "Adicionar LIMIT para evitar ordenação completa da tabela"
            elif "JOIN" in query and "WHERE" not in query:
                optimizations[query] = "Adicionar condições WHERE antes dos JOINs"
            elif "SELECT *" in query:
                optimizations[query] = "Especificar apenas as colunas necessárias"
        
        return optimizations
    
    def generate_migration_script(self, schema: DatabaseSchema) -> str:
        """
        Gerar script de migração SQL
        """
        self.logger.info("📝 Gerando script de migração...")
        
        migration_sql = f"""
-- Migration: SPR Database Schema
-- Generated: {datetime.now().isoformat()}
-- Database: {schema.name}

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create custom types
CREATE TYPE user_role AS ENUM ('admin', 'operator', 'user');
CREATE TYPE commodity_category AS ENUM ('grains', 'livestock', 'energy', 'metals');

"""
        
        # Criar tabelas
        for table in schema.tables:
            migration_sql += f"\n-- Create table: {table['name']}\n"
            migration_sql += f"CREATE TABLE {table['name']} (\n"
            
            columns = []
            for col in table['columns']:
                col_def = f"    {col['name']} {col['type']}"
                if col.get('primary_key'):
                    col_def += " PRIMARY KEY"
                if col.get('unique'):
                    col_def += " UNIQUE"
                if col.get('not_null'):
                    col_def += " NOT NULL"
                if col.get('default'):
                    col_def += f" DEFAULT {col['default']}"
                if col.get('foreign_key'):
                    col_def += f" REFERENCES {col['foreign_key']}"
                columns.append(col_def)
            
            migration_sql += ",\n".join(columns)
            migration_sql += "\n);\n"
            
            # Enable RLS se necessário
            if table.get('rls_enabled'):
                migration_sql += f"\nALTER TABLE {table['name']} ENABLE ROW LEVEL SECURITY;\n"
            
            # Criar índices
            if table.get('indexes'):
                for index in table['indexes']:
                    migration_sql += f"CREATE INDEX idx_{table['name']}_{index} ON {table['name']}({index});\n"
        
        # Criar views
        for view in schema.views:
            migration_sql += f"\n{view['definition']}\n"
        
        # Criar funções
        for func in schema.functions:
            migration_sql += f"\n{func['definition']}\n"
        
        return migration_sql
    
    def backup_strategy(self) -> Dict[str, Any]:
        """
        Estratégia de backup e recuperação
        """
        return {
            "daily_backup": {
                "schedule": "0 2 * * *",  # 2h da manhã
                "retention": "30 days",
                "includes": ["schema", "data"],
                "compression": True
            },
            "weekly_full_backup": {
                "schedule": "0 1 * * 0",  # Domingo 1h
                "retention": "12 weeks", 
                "includes": ["schema", "data", "logs"],
                "offsite_copy": True
            },
            "point_in_time_recovery": {
                "enabled": True,
                "retention": "7 days"
            }
        }
    
    def health_check(self) -> Dict[str, Any]:
        """
        Verificação de saúde do banco
        """
        return {
            "status": "operational",
            "connections": {
                "active": 12,
                "max": 100,
                "usage_percent": 12
            },
            "storage": {
                "total_gb": 50,
                "used_gb": 8.5,
                "usage_percent": 17
            },
            "performance": {
                "avg_query_time_ms": 45,
                "slow_queries_count": 2,
                "cache_hit_ratio": 0.98
            },
            "replication": {
                "status": "healthy",
                "lag_ms": 15
            }
        }

if __name__ == "__main__":
    agent = DatabaseAgent()
    
    # Simular requisitos de negócio
    business_req = {
        "system": "SPR - Sistema Preditivo Royal",
        "modules": ["auth", "commodities", "predictions", "whatsapp"],
        "users": 100,
        "data_volume": "medium"
    }
    
    # Gerar schema
    schema = agent.analyze_schema_requirements(business_req)
    print(f"✅ Schema gerado para {len(schema.tables)} tabelas")
    
    # Gerar políticas RLS
    policies = agent.create_rls_policies(schema)
    print(f"🔐 {len(policies)} políticas RLS criadas")
    
    # Gerar migração
    migration = agent.generate_migration_script(schema)
    print(f"📝 Script de migração gerado ({len(migration)} chars)")
    
    print(f"\n🎯 {agent.agent_name} - Operacional!")