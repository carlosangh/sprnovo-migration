#!/usr/bin/env python3
"""
Script para extrair schemas completos de bancos SQLite do SPR
"""
import sqlite3
import os
import sys
from pathlib import Path

# Lista de bancos encontrados
databases = [
    "/home/cadu/spr-project/data/spr_central.db",
    "/home/cadu/ciclologico_production/backend_v2/clg_test.db", 
    "/home/cadu/ciclologico_production/backend_v2/clg_historical.db",
    "/home/cadu/spr_deployment/spr_broadcast.db",
    "/home/cadu/projeto_SPR/spr_users.db",
    "/home/cadu/projeto_SPR/data/spr.db",
    "/home/cadu/projeto_SPR/data/spr_backup.db",
    "/home/cadu/projeto_SPR/data/spr_work.db",
    "/home/cadu/projeto_SPR/spr_broadcast.db",
    "/home/cadu/projeto_SPR/spr_whatsapp.db",
    "/home/cadu/projeto_SPR/spr_validation.db",
    "/home/cadu/projeto_SPR/spr_yahoo_finance.db"
]

def extract_schema(db_path, output_dir):
    """Extrai schema completo de um banco SQLite"""
    if not os.path.exists(db_path):
        print(f"AVISO: Banco {db_path} não encontrado")
        return None
        
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        # Nome do arquivo de saída
        db_name = Path(db_path).stem
        output_file = os.path.join(output_dir, f"{db_name}_schema.sql")
        
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(f"-- Schema extraído de: {db_path}\n")
            f.write(f"-- Data: {os.path.getctime(db_path) if os.path.exists(db_path) else 'N/A'}\n\n")
            
            # Obter schema completo
            cursor.execute("SELECT sql FROM sqlite_master WHERE sql IS NOT NULL ORDER BY type, name")
            schemas = cursor.fetchall()
            
            for schema in schemas:
                if schema[0]:
                    f.write(schema[0] + ";\n\n")
            
            # Obter informações das tabelas
            cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
            tables = cursor.fetchall()
            
            f.write("-- INFORMAÇÕES DAS TABELAS\n")
            for table in tables:
                table_name = table[0]
                f.write(f"\n-- Tabela: {table_name}\n")
                
                # Contar registros (apenas para informação)
                try:
                    cursor.execute(f"SELECT COUNT(*) FROM `{table_name}`")
                    count = cursor.fetchone()[0]
                    f.write(f"-- Registros: {count}\n")
                except:
                    f.write("-- Registros: N/A\n")
                
                # Informações das colunas
                cursor.execute(f"PRAGMA table_info(`{table_name}`)")
                columns = cursor.fetchall()
                f.write("-- Colunas:\n")
                for col in columns:
                    f.write(f"--   {col[1]} {col[2]} {'NOT NULL' if col[3] else 'NULL'} {'PRIMARY KEY' if col[5] else ''}\n")
        
        conn.close()
        print(f"Schema extraído: {output_file}")
        
        # Retornar informações básicas
        return {
            'db_path': db_path,
            'db_name': db_name,
            'output_file': output_file,
            'tables': [t[0] for t in tables],
            'table_count': len(tables)
        }
        
    except Exception as e:
        print(f"ERRO ao extrair {db_path}: {e}")
        return None

def main():
    output_dir = "/home/cadu/SPRNOVO/db/sqlite_schemas"
    os.makedirs(output_dir, exist_ok=True)
    
    results = []
    
    for db_path in databases:
        result = extract_schema(db_path, output_dir)
        if result:
            results.append(result)
    
    # Gerar relatório resumido
    with open("/home/cadu/SPRNOVO/db/sqlite_extraction_report.txt", 'w', encoding='utf-8') as f:
        f.write("RELATÓRIO DE EXTRAÇÃO DE SCHEMAS SQLite - SPR\n")
        f.write("=" * 50 + "\n\n")
        
        for result in results:
            f.write(f"Banco: {result['db_name']}\n")
            f.write(f"Caminho: {result['db_path']}\n")
            f.write(f"Schema salvo em: {result['output_file']}\n")
            f.write(f"Número de tabelas: {result['table_count']}\n")
            f.write(f"Tabelas: {', '.join(result['tables'])}\n\n")
    
    print(f"\nExtração concluída! {len(results)} bancos processados.")
    print("Relatório salvo em: /home/cadu/SPRNOVO/db/sqlite_extraction_report.txt")

if __name__ == "__main__":
    main()