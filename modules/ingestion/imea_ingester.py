#!/usr/bin/env python3
"""
SPR - IMEA Data Ingester
Coleta de dados IMEA com SQLite otimizado e controle de contenção
"""

import sqlite3
import logging
import json
import hashlib
import time
import os
import sys
import fcntl
from datetime import datetime, date, timedelta
from typing import Dict, List, Optional, Tuple
from pathlib import Path
import requests
from contextlib import contextmanager
import random

# Configuração de logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/opt/spr/logs/imea_ingest.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger('imea_ingester')

class IMEAIngester:
    def __init__(self, db_path: str = '/opt/spr/data/spr_central.db'):
        self.db_path = db_path
        self.source = 'IMEA'
        self.lock_file = f'/tmp/imea_ingest.lock'
        self.max_retries = 3
        self.base_url = 'https://imea.com.br/api'
        
    @contextmanager
    def exclusive_lock(self):
        """Controle de concorrência com flock"""
        lock_fd = None
        try:
            lock_fd = os.open(self.lock_file, os.O_CREAT | os.O_WRONLY | os.O_TRUNC)
            fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            logger.info(f"🔒 Lock adquirido: {self.lock_file}")
            yield
        except BlockingIOError:
            logger.warning("⚠️ Processo IMEA já em execução, saindo...")
            sys.exit(0)
        except Exception as e:
            logger.error(f"❌ Erro no lock IMEA: {e}")
            sys.exit(1)
        finally:
            if lock_fd:
                fcntl.flock(lock_fd, fcntl.LOCK_UN)
                os.close(lock_fd)
                try:
                    os.unlink(self.lock_file)
                except:
                    pass
                logger.info("🔓 Lock IMEA liberado")

    def get_optimized_connection(self) -> sqlite3.Connection:
        """Conexão SQLite otimizada"""
        conn = sqlite3.connect(
            self.db_path,
            timeout=8.0,
            isolation_level=None  # Autocommit mode
        )
        
        # Configurações de performance
        conn.execute("PRAGMA journal_mode = WAL")
        conn.execute("PRAGMA synchronous = NORMAL")
        conn.execute("PRAGMA busy_timeout = 8000")
        conn.execute("PRAGMA cache_size = -32000")  # 32MB cache
        conn.execute("PRAGMA temp_store = MEMORY")
        
        return conn

    def create_data_hash(self, data: Dict) -> str:
        """Cria hash único para detecção de duplicatas"""
        key_data = f"{data.get('data_referencia')}-{data.get('regiao')}-{data.get('commodity')}-{data.get('safra')}"
        return hashlib.md5(key_data.encode()).hexdigest()

    def fetch_imea_data(self, start_date: date, end_date: date) -> List[Dict]:
        """Coleta dados da API IMEA (simulado)"""
        logger.info(f"🌾 Coletando dados IMEA: {start_date} a {end_date}")
        
        # Regiões do Mato Grosso
        regioes = [
            'NORTE', 'NORDESTE', 'CENTRO', 'SUL', 'SUDESTE', 
            'OESTE', 'NOROESTE', 'MEDIO_NORTE'
        ]
        
        commodities = ['SOJA', 'MILHO', 'ALGODAO', 'SORGO']
        safras = ['2023/24', '2024/25']
        
        data = []
        current_date = start_date
        
        while current_date <= end_date:
            # IMEA publica dados semanalmente
            if current_date.weekday() == 4:  # Sexta-feira
                for regiao in regioes:
                    for commodity in commodities:
                        for safra in safras:
                            # Simula dados IMEA
                            base_prices = {
                                'SOJA': 145.0, 'MILHO': 72.0, 
                                'ALGODAO': 275.0, 'SORGO': 68.0
                            }
                            
                            base_areas = {
                                'SOJA': 12000000, 'MILHO': 6000000,
                                'ALGODAO': 1800000, 'SORGO': 400000
                            }
                            
                            # Variações regionais
                            regional_factor = random.uniform(0.9, 1.1)
                            price = base_prices[commodity] * regional_factor
                            area = int(base_areas[commodity] / len(regioes) * regional_factor)
                            
                            record = {
                                'data_referencia': current_date.isoformat(),
                                'regiao': regiao,
                                'commodity': commodity,
                                'safra': safra,
                                'preco_medio': round(price, 4),
                                'volume_estimado': random.randint(50000, 500000),
                                'area_plantada': area,
                                'produtividade': round(random.uniform(55.0, 65.0), 2),  # sc/ha
                            }
                            data.append(record)
                            
            current_date += timedelta(days=1)
        
        logger.info(f"✅ {len(data)} registros IMEA coletados")
        return data

    def insert_batch(self, conn: sqlite3.Connection, records: List[Dict]) -> Tuple[int, int]:
        """Insere lote de dados com controle de duplicatas"""
        inserted = 0
        updated = 0
        
        try:
            conn.execute("BEGIN TRANSACTION")
            
            for record in records:
                # Cria hash para controle de duplicatas
                record['hash_registro'] = self.create_data_hash(record)
                
                # Verifica se já existe
                cursor = conn.execute(
                    "SELECT id FROM imea_dados WHERE hash_registro = ?",
                    (record['hash_registro'],)
                )
                existing = cursor.fetchone()
                
                if existing:
                    # Atualiza registro existente
                    conn.execute("""
                        UPDATE imea_dados SET
                            preco_medio = ?, volume_estimado = ?, area_plantada = ?,
                            produtividade = ?, updated_at = CURRENT_TIMESTAMP
                        WHERE hash_registro = ?
                    """, (
                        record['preco_medio'], record['volume_estimado'],
                        record['area_plantada'], record['produtividade'],
                        record['hash_registro']
                    ))
                    updated += 1
                else:
                    # Insere novo registro
                    conn.execute("""
                        INSERT INTO imea_dados 
                        (data_referencia, regiao, commodity, safra, preco_medio,
                         volume_estimado, area_plantada, produtividade, hash_registro)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """, (
                        record['data_referencia'], record['regiao'], record['commodity'],
                        record['safra'], record['preco_medio'], record['volume_estimado'],
                        record['area_plantada'], record['produtividade'], 
                        record['hash_registro']
                    ))
                    inserted += 1
            
            conn.execute("COMMIT")
            logger.info(f"💾 IMEA - Inseridos: {inserted}, Atualizados: {updated}")
            
        except Exception as e:
            conn.execute("ROLLBACK")
            logger.error(f"❌ Erro no lote IMEA: {e}")
            raise
            
        return inserted, updated

    def log_execution(self, conn: sqlite3.Connection, status: str, 
                     start_time: float, processed: int, inserted: int, 
                     updated: int, error: Optional[str] = None):
        """Registra execução no controle"""
        execution_time = int((time.time() - start_time) * 1000)
        
        conn.execute("""
            INSERT INTO ingest_control 
            (fonte, data_execucao, status, registros_processados, 
             registros_inseridos, registros_atualizados, tempo_execucao_ms, 
             erro_detalhes, pid, hostname)
            VALUES (?, CURRENT_TIMESTAMP, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            self.source, status, processed, inserted, updated,
            execution_time, error, os.getpid(), os.uname().nodename
        ))

    def collect_performance_metrics(self, conn: sqlite3.Connection, 
                                  latency_ms: int, throughput: int):
        """Coleta métricas de performance"""
        cursor = conn.execute("PRAGMA database_list")
        main_db = cursor.fetchone()[2]
        
        db_size_mb = 0
        wal_size_mb = 0
        
        try:
            db_size_mb = os.path.getsize(main_db) / (1024 * 1024)
            wal_file = main_db + '-wal'
            if os.path.exists(wal_file):
                wal_size_mb = os.path.getsize(wal_file) / (1024 * 1024)
        except:
            pass
            
        conn.execute("""
            INSERT INTO performance_metrics 
            (fonte, latencia_ms, throughput_regs_sec, db_size_mb, wal_size_mb)
            VALUES (?, ?, ?, ?, ?)
        """, (self.source, latency_ms, throughput, db_size_mb, wal_size_mb))

    def run_ingestion(self, days_back: int = 14) -> Dict:
        """Executa coleta principal"""
        with self.exclusive_lock():
            start_time = time.time()
            conn = None
            
            try:
                logger.info(f"🚀 Iniciando ingestão IMEA (últimos {days_back} dias)")
                
                # Conecta ao banco
                conn = self.get_optimized_connection()
                
                # Define período (IMEA tem dados semanais)
                end_date = date.today()
                start_date = end_date - timedelta(days=days_back)
                
                # Coleta dados
                raw_data = self.fetch_imea_data(start_date, end_date)
                
                if not raw_data:
                    logger.warning("⚠️ Nenhum dado IMEA coletado")
                    return {'status': 'no_data', 'processed': 0}
                
                # Processa em lotes menores (IMEA tem menos volume)
                batch_size = 500
                total_inserted = 0
                total_updated = 0
                
                for i in range(0, len(raw_data), batch_size):
                    batch = raw_data[i:i + batch_size]
                    inserted, updated = self.insert_batch(conn, batch)
                    total_inserted += inserted
                    total_updated += updated
                    
                    logger.info(f"📈 IMEA processados {i + len(batch)}/{len(raw_data)}")
                
                # Métricas de performance
                execution_time_ms = int((time.time() - start_time) * 1000)
                throughput = len(raw_data) / max((execution_time_ms / 1000), 1)
                
                self.collect_performance_metrics(
                    conn, execution_time_ms, int(throughput)
                )
                
                # Log da execução
                self.log_execution(
                    conn, 'completed', start_time, len(raw_data),
                    total_inserted, total_updated
                )
                
                result = {
                    'status': 'success',
                    'processed': len(raw_data),
                    'inserted': total_inserted,
                    'updated': total_updated,
                    'execution_time_ms': execution_time_ms,
                    'throughput_rps': throughput
                }
                
                logger.info(f"✅ Ingestão IMEA concluída: {result}")
                return result
                
            except Exception as e:
                error_msg = f"Erro na ingestão IMEA: {e}"
                logger.error(f"❌ {error_msg}")
                
                if conn:
                    self.log_execution(
                        conn, 'failed', start_time, 0, 0, 0, error_msg
                    )
                
                return {'status': 'error', 'error': error_msg}
                
            finally:
                if conn:
                    conn.close()

def main():
    """Função principal para execução via cron"""
    import argparse
    
    parser = argparse.ArgumentParser(description='IMEA Data Ingester')
    parser.add_argument('--days', type=int, default=14, 
                       help='Dias históricos para coletar (padrão: 14)')
    parser.add_argument('--db-path', type=str, 
                       default='/opt/spr/data/spr_central.db',
                       help='Caminho do banco SQLite')
    
    args = parser.parse_args()
    
    # Adiciona jitter para evitar execuções simultâneas
    jitter = random.randint(0, 300)  # 0-5 minutos
    if jitter > 0:
        logger.info(f"⏱️ IMEA Jitter: aguardando {jitter} segundos...")
        time.sleep(jitter)
    
    ingester = IMEAIngester(args.db_path)
    result = ingester.run_ingestion(args.days)
    
    # Exit code baseado no resultado
    if result['status'] == 'success':
        sys.exit(0)
    else:
        sys.exit(1)

if __name__ == '__main__':
    main()