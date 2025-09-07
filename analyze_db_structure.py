#!/usr/bin/env python3
"""
Análise de estrutura de banco de dados SPR
"""
import sqlite3
import os
import json
from collections import defaultdict
from pathlib import Path

def analyze_database_structure():
    """Analisa a estrutura dos bancos SQLite do SPR"""
    
    # Banco principal
    main_db = "/home/cadu/spr-project/data/spr_central.db"
    
    analysis = {
        'database_overview': {},
        'entities': {},
        'relationships': [],
        'modules': {},
        'business_rules': []
    }
    
    try:
        conn = sqlite3.connect(main_db)
        cursor = conn.cursor()
        
        # Obter todas as tabelas
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name != 'sqlite_sequence'")
        tables = cursor.fetchall()
        
        analysis['database_overview'] = {
            'main_database': main_db,
            'total_tables': len(tables),
            'table_names': [table[0] for table in tables]
        }
        
        # Analisar cada tabela
        for (table_name,) in tables:
            table_info = analyze_table(cursor, table_name)
            analysis['entities'][table_name] = table_info
            
        # Identificar relacionamentos
        analysis['relationships'] = identify_relationships(cursor, [table[0] for table in tables])
        
        # Identificar módulos de negócio
        analysis['modules'] = identify_business_modules(analysis['entities'])
        
        # Regras de negócio implícitas
        analysis['business_rules'] = identify_business_rules(analysis['entities'])
        
        conn.close()
        
    except Exception as e:
        print(f"Erro ao analisar banco: {e}")
        analysis['error'] = str(e)
    
    return analysis

def analyze_table(cursor, table_name):
    """Analisa estrutura de uma tabela específica"""
    table_info = {
        'name': table_name,
        'columns': [],
        'indexes': [],
        'foreign_keys': [],
        'record_count': 0,
        'purpose': infer_table_purpose(table_name)
    }
    
    try:
        # Informações das colunas
        cursor.execute(f"PRAGMA table_info(`{table_name}`)")
        columns = cursor.fetchall()
        
        for col in columns:
            column_info = {
                'name': col[1],
                'type': col[2],
                'not_null': bool(col[3]),
                'primary_key': bool(col[5]),
                'default_value': col[4]
            }
            table_info['columns'].append(column_info)
        
        # Chaves estrangeiras
        cursor.execute(f"PRAGMA foreign_key_list(`{table_name}`)")
        fks = cursor.fetchall()
        
        for fk in fks:
            fk_info = {
                'column': fk[3],
                'referenced_table': fk[2],
                'referenced_column': fk[4]
            }
            table_info['foreign_keys'].append(fk_info)
        
        # Índices
        cursor.execute(f"PRAGMA index_list(`{table_name}`)")
        indexes = cursor.fetchall()
        
        for idx in indexes:
            if not idx[1].startswith('sqlite_autoindex'):
                cursor.execute(f"PRAGMA index_info(`{idx[1]}`)")
                idx_columns = [col[2] for col in cursor.fetchall()]
                
                index_info = {
                    'name': idx[1],
                    'unique': bool(idx[2]),
                    'columns': idx_columns
                }
                table_info['indexes'].append(index_info)
        
        # Contar registros
        try:
            cursor.execute(f"SELECT COUNT(*) FROM `{table_name}`")
            table_info['record_count'] = cursor.fetchone()[0]
        except:
            table_info['record_count'] = -1
            
    except Exception as e:
        table_info['analysis_error'] = str(e)
    
    return table_info

def infer_table_purpose(table_name):
    """Infere o propósito da tabela baseado no nome"""
    purposes = {
        'commodities': 'Catálogo de commodities agrícolas (produtos base)',
        'offers': 'Ofertas de compra/venda de commodities',
        'price_history': 'Histórico de preços das commodities',
        'whatsapp_users': 'Usuários cadastrados no WhatsApp',
        'whatsapp_messages': 'Mensagens do WhatsApp (log de comunicação)',
        'whatsapp_sessions': 'Sessões ativas do WhatsApp',
        'analytics_metrics': 'Métricas de analytics e monitoramento',
        'agentes_status': 'Status dos agentes do sistema',
        'system_config': 'Configurações do sistema'
    }
    
    return purposes.get(table_name, 'Propósito a ser determinado')

def identify_relationships(cursor, table_names):
    """Identifica relacionamentos entre tabelas"""
    relationships = []
    
    for table_name in table_names:
        try:
            cursor.execute(f"PRAGMA foreign_key_list(`{table_name}`)")
            fks = cursor.fetchall()
            
            for fk in fks:
                relationship = {
                    'from_table': table_name,
                    'from_column': fk[3],
                    'to_table': fk[2],
                    'to_column': fk[4],
                    'type': 'foreign_key',
                    'description': f"{table_name}.{fk[3]} referencia {fk[2]}.{fk[4]}"
                }
                relationships.append(relationship)
        except Exception as e:
            continue
    
    return relationships

def identify_business_modules(entities):
    """Identifica módulos de negócio baseado nas entidades"""
    modules = {
        'commodities_module': {
            'name': 'Módulo de Commodities',
            'description': 'Gerenciamento de produtos agrícolas e preços',
            'tables': ['commodities', 'price_history', 'offers'],
            'purpose': 'Controle do catálogo de produtos e formação de preços'
        },
        'whatsapp_module': {
            'name': 'Módulo WhatsApp',
            'description': 'Comunicação via WhatsApp',
            'tables': ['whatsapp_users', 'whatsapp_messages', 'whatsapp_sessions'],
            'purpose': 'Interface de comunicação com usuários via WhatsApp'
        },
        'analytics_module': {
            'name': 'Módulo de Analytics',
            'description': 'Monitoramento e métricas do sistema',
            'tables': ['analytics_metrics', 'agentes_status'],
            'purpose': 'Observabilidade e performance do sistema'
        },
        'system_module': {
            'name': 'Módulo do Sistema',
            'description': 'Configurações e administração',
            'tables': ['system_config'],
            'purpose': 'Configurações centrais do sistema'
        }
    }
    
    return modules

def identify_business_rules(entities):
    """Identifica regras de negócio implícitas na estrutura"""
    rules = []
    
    # Regras identificadas na estrutura
    rules.append({
        'rule': 'Ofertas têm validade limitada',
        'evidence': 'Campo valid_until na tabela offers',
        'impact': 'Ofertas expiram automaticamente'
    })
    
    rules.append({
        'rule': 'Commodities podem estar ativas/inativas',
        'evidence': 'Campo active na tabela commodities',
        'impact': 'Controle de produtos disponíveis para negociação'
    })
    
    rules.append({
        'rule': 'Usuários WhatsApp têm preferências de commodities',
        'evidence': 'Campo preferred_commodities na tabela whatsapp_users',
        'impact': 'Personalização de notificações por interesse'
    })
    
    rules.append({
        'rule': 'Histórico completo de preços com OHLCV',
        'evidence': 'Campos price_open, price_high, price_low, price_close, volume',
        'impact': 'Análise técnica de preços possível'
    })
    
    rules.append({
        'rule': 'Ofertas são regionalizadas',
        'evidence': 'Campos region e state nas tabelas offers e price_history',
        'impact': 'Preços e ofertas variam por região'
    })
    
    return rules

def main():
    """Função principal"""
    print("Analisando estrutura do banco de dados SPR...")
    
    analysis = analyze_database_structure()
    
    # Salvar análise em JSON
    output_file = "/home/cadu/SPRNOVO/db/database_analysis.json"
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(analysis, f, indent=2, ensure_ascii=False)
    
    print(f"Análise salva em: {output_file}")
    
    # Sumário da análise
    print("\n=== RESUMO DA ANÁLISE ===")
    print(f"Banco principal: {analysis['database_overview']['main_database']}")
    print(f"Total de tabelas: {analysis['database_overview']['total_tables']}")
    
    print("\n=== MÓDULOS IDENTIFICADOS ===")
    for module_id, module_info in analysis['modules'].items():
        print(f"• {module_info['name']}: {len(module_info['tables'])} tabelas")
        print(f"  Propósito: {module_info['purpose']}")
    
    print(f"\n=== RELACIONAMENTOS ===")
    print(f"Total de FKs identificadas: {len(analysis['relationships'])}")
    
    print(f"\n=== REGRAS DE NEGÓCIO IDENTIFICADAS ===")
    for rule in analysis['business_rules']:
        print(f"• {rule['rule']}")
    
    return analysis

if __name__ == "__main__":
    main()