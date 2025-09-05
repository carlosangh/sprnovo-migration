#!/usr/bin/env python3
"""
SPR - Climate Data Ingester (INMET)
Coleta de dados climáticos com SQLite otimizado e controle de contenção
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
        logging.FileHandler('/opt/spr/logs/clima_ingest.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger('clima_ingester')

class CLIMAIngester:
    def __init__(self, db_path: str = '/opt/spr/data/spr_central.db'):
        self.db_path = db_path
        self.source = 'INMET'
        self.lock_file = f'/tmp/clima_ingest.lock'
        self.max_retries = 3
        self.base_url = 'https://apitempo.inmet.gov.br/api'
        
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
            logger.warning("⚠️ Processo CLIMA já em execução, saindo...")
            sys.exit(0)
        except Exception as e:
            logger.error(f"❌ Erro no lock CLIMA: {e}")
            sys.exit(1)
        finally:
            if lock_fd:
                fcntl.flock(lock_fd, fcntl.LOCK_UN)
                os.close(lock_fd)
                try:
                    os.unlink(self.lock_file)
                except:
                    pass
                logger.info("🔓 Lock CLIMA liberado")

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
        key_data = f"{data.get('data_medicao')}-{data.get('codigo_estacao')}"
        return hashlib.md5(key_data.encode()).hexdigest()

    def fetch_clima_data(self, start_date: date, end_date: date) -> List[Dict]:
        """Coleta dados climáticos INMET (simulado)"""
        logger.info(f"🌤️ Coletando dados climáticos: {start_date} a {end_date}")
        
        # Estações INMET em regiões agrícolas principais
        estacoes = [
            {'codigo': 'A001', 'nome': 'Sinop-MT', 'uf': 'MT', 'lat': -11.86, 'lon': -55.50, 'municipio': 'Sinop'},
            {'codigo': 'A002', 'nome': 'Sorriso-MT', 'uf': 'MT', 'lat': -12.55, 'lon': -55.72, 'municipio': 'Sorriso'},
            {'codigo': 'A003', 'nome': 'Campo Verde-MT', 'uf': 'MT', 'lat': -15.55, 'lon': -55.17, 'municipio': 'Campo Verde'},
            {'codigo': 'A004', 'nome': 'Rio Verde-GO', 'uf': 'GO', 'lat': -17.79, 'lon': -50.93, 'municipio': 'Rio Verde'},
            {'codigo': 'A005', 'nome': 'Chapadão do Sul-MS', 'uf': 'MS', 'lat': -18.79, 'lon': -52.62, 'municipio': 'Chapadão do Sul'},
            {'codigo': 'A006', 'nome': 'Barreiras-BA', 'uf': 'BA', 'lat': -12.15, 'lon': -45.00, 'municipio': 'Barreiras'},
            {'codigo': 'A007', 'nome': 'Passo Fundo-RS', 'uf': 'RS', 'lat': -28.22, 'lon': -52.41, 'municipio': 'Passo Fundo'},
            {'codigo': 'A008', 'nome': 'Cruz Alta-RS', 'uf': 'RS', 'lat': -28.64, 'lon': -53.61, 'municipio': 'Cruz Alta'},
            {'codigo': 'A009', 'nome': 'Cascavel-PR', 'uf': 'PR', 'lat': -24.95, 'lon': -53.46, 'municipio': 'Cascavel'},
            {'codigo': 'A010', 'nome': 'Uberlândia-MG', 'uf': 'MG', 'lat': -18.92, 'lon': -48.26, 'municipio': 'Uberlândia'},
        ]
        
        data = []
        current_date = start_date
        
        while current_date <= end_date:
            for estacao in estacoes:
                # Simula dados climáticos baseados na região
                temp_base = 25.0
                if estacao['uf'] in ['RS', 'PR']:
                    temp_base = 20.0  # Região Sul mais fria
                elif estacao['uf'] in ['BA', 'MT', 'GO']:
                    temp_base = 28.0  # Cerrado mais quente
                
                # Variação sazonal
                day_of_year = current_date.timetuple().tm_yday
                seasonal_factor = -5 * abs(day_of_year - 180) / 180  # Pico no meio do ano
                
                temp_media = temp_base + seasonal_factor + random.uniform(-3, 3)
                temp_max = temp_media + random.uniform(8, 15)
                temp_min = temp_media - random.uniform(5, 10)
                
                # Chuva baseada na época do ano (chuvas no verão)
                is_rainy_season = 300 <= day_of_year or day_of_year <= 100  # Nov-Mar
                prec_prob = 0.7 if is_rainy_season else 0.2
                precipitacao = random.uniform(0, 50) if random.random() < prec_prob else 0
                
                record = {
                    'data_medicao': current_date.isoformat(),
                    'codigo_estacao': estacao['codigo'],
                    'nome_estacao': estacao['nome'],
                    'uf': estacao['uf'],
                    'municipio': estacao['municipio'],
                    'latitude': estacao['lat'],
                    'longitude': estacao['lon'],
                    'temperatura_max': round(temp_max, 2),
                    'temperatura_min': round(temp_min, 2),
                    'temperatura_media': round(temp_media, 2),
                    'umidade_relativa': round(random.uniform(45, 90), 2),
                    'precipitacao': round(precipitacao, 2),
                    'velocidade_vento': round(random.uniform(1, 15), 2),
                    'pressao_atmosferica': round(random.uniform(1000, 1030), 2),
                    'radiacao_solar': round(random.uniform(15, 30), 2),
                }
                data.append(record)
                
            current_date += timedelta(days=1)
        
        logger.info(f"✅ {len(data)} registros climáticos coletados")
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
                    "SELECT id FROM clima_dados WHERE hash_registro = ?",
                    (record['hash_registro'],)
                )
                existing = cursor.fetchone()
                
                if existing:
                    # Atualiza registro existente
                    conn.execute("""
                        UPDATE clima_dados SET
                            temperatura_max = ?, temperatura_min = ?, temperatura_media = ?,
                            umidade_relativa = ?, precipitacao = ?, velocidade_vento = ?,
                            pressao_atmosferica = ?, radiacao_solar = ?, updated_at = CURRENT_TIMESTAMP
                        WHERE hash_registro = ?
                    """, (
                        record['temperatura_max'], record['temperatura_min'], record['temperatura_media'],
                        record['umidade_relativa'], record['precipitacao'], record['velocidade_vento'],
                        record['pressao_atmosferica'], record['radiacao_solar'],
                        record['hash_registro']
                    ))
                    updated += 1
                else:
                    # Insere novo registro
                    conn.execute("""
                        INSERT INTO clima_dados 
                        (data_medicao, codigo_estacao, nome_estacao, uf, municipio,
                         latitude, longitude, temperatura_max, temperatura_min, temperatura_media,
                         umidade_relativa, precipitacao, velocidade_vento, pressao_atmosferica,
                         radiacao_solar, hash_registro)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """, (
                        record['data_medicao'], record['codigo_estacao'], record['nome_estacao'],
                        record['uf'], record['municipio'], record['latitude'], record['longitude'],
                        record['temperatura_max'], record['temperatura_min'], record['temperatura_media'],
                        record['umidade_relativa'], record['precipitacao'], record['velocidade_vento'],
                        record['pressao_atmosferica'], record['radiacao_solar'], record['hash_registro']
                    ))
                    inserted += 1
            
            conn.execute("COMMIT")
            logger.info(f"💾 CLIMA - Inseridos: {inserted}, Atualizados: {updated}")
            
        except Exception as e:
            conn.execute("ROLLBACK")
            logger.error(f"❌ Erro no lote CLIMA: {e}")
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

    def run_ingestion(self, days_back: int = 3) -> Dict:
        """Executa coleta principal"""
        with self.exclusive_lock():
            start_time = time.time()
            conn = None
            
            try:
                logger.info(f"🚀 Iniciando ingestão CLIMA (últimos {days_back} dias)")
                
                # Conecta ao banco
                conn = self.get_optimized_connection()
                
                # Define período (dados climáticos são diários)
                end_date = date.today() - timedelta(days=1)  # Dados do dia anterior
                start_date = end_date - timedelta(days=days_back)
                
                # Coleta dados
                raw_data = self.fetch_clima_data(start_date, end_date)
                
                if not raw_data:
                    logger.warning("⚠️ Nenhum dado climático coletado")
                    return {'status': 'no_data', 'processed': 0}
                
                # Processa em lotes
                batch_size = 200
                total_inserted = 0
                total_updated = 0
                
                for i in range(0, len(raw_data), batch_size):
                    batch = raw_data[i:i + batch_size]
                    inserted, updated = self.insert_batch(conn, batch)
                    total_inserted += inserted
                    total_updated += updated
                    
                    logger.info(f"📈 CLIMA processados {i + len(batch)}/{len(raw_data)}")
                
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
                
                logger.info(f"✅ Ingestão CLIMA concluída: {result}")
                return result
                
            except Exception as e:
                error_msg = f"Erro na ingestão CLIMA: {e}"
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
    
    parser = argparse.ArgumentParser(description='Climate Data Ingester')
    parser.add_argument('--days', type=int, default=3, 
                       help='Dias históricos para coletar (padrão: 3)')
    parser.add_argument('--db-path', type=str, 
                       default='/opt/spr/data/spr_central.db',
                       help='Caminho do banco SQLite')
    
    args = parser.parse_args()
    
    # Adiciona jitter para evitar execuções simultâneas
    jitter = random.randint(0, 300)  # 0-5 minutos
    if jitter > 0:
        logger.info(f"⏱️ CLIMA Jitter: aguardando {jitter} segundos...")
        time.sleep(jitter)
    
    ingester = CLIMAIngester(args.db_path)
    result = ingester.run_ingestion(args.days)
    
    # Exit code baseado no resultado
    if result['status'] == 'success':
        sys.exit(0)
    else:
        sys.exit(1)

if __name__ == '__main__':
    main()