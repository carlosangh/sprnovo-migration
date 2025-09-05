#!/usr/bin/env python3
"""
SPR - Smoke Tests para Ingestões
Testes de integridade e performance das ingestões de dados
"""

import sqlite3
import logging
import time
import os
import json
from datetime import datetime, date, timedelta
from typing import Dict, List, Tuple, Optional
from pathlib import Path

# Configuração de logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/opt/spr/logs/smoke_test.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger('smoke_test')

class SprSmokeTest:
    def __init__(self, db_path: str = '/opt/spr/data/spr_central.db'):
        self.db_path = db_path
        self.results = {}
        self.alerts = []
        
    def get_connection(self) -> sqlite3.Connection:
        """Conexão SQLite para testes"""
        if not os.path.exists(self.db_path):
            raise FileNotFoundError(f"Banco de dados não encontrado: {self.db_path}")
        
        conn = sqlite3.connect(
            self.db_path,
            timeout=5.0,
            check_same_thread=False
        )
        conn.row_factory = sqlite3.Row
        return conn

    def test_database_health(self) -> Dict:
        """Testa integridade básica do banco"""
        logger.info("🔍 Testando integridade do banco...")
        
        try:
            conn = self.get_connection()
            start_time = time.time()
            
            # Integrity check
            cursor = conn.execute("PRAGMA integrity_check")
            integrity_result = cursor.fetchone()[0]
            
            # WAL mode check  
            cursor = conn.execute("PRAGMA journal_mode")
            journal_mode = cursor.fetchone()[0]
            
            # Database size
            cursor = conn.execute("PRAGMA database_list")
            db_info = cursor.fetchone()
            db_size_mb = os.path.getsize(db_info[2]) / (1024 * 1024)
            
            # WAL file size
            wal_file = db_info[2] + '-wal'
            wal_size_mb = 0
            if os.path.exists(wal_file):
                wal_size_mb = os.path.getsize(wal_file) / (1024 * 1024)
            
            latency_ms = int((time.time() - start_time) * 1000)
            
            result = {
                'status': 'ok' if integrity_result == 'ok' else 'error',
                'integrity': integrity_result,
                'journal_mode': journal_mode,
                'db_size_mb': round(db_size_mb, 2),
                'wal_size_mb': round(wal_size_mb, 2),
                'latency_ms': latency_ms
            }
            
            # Alertas
            if wal_size_mb > 100:
                self.alerts.append(f"WAL file muito grande: {wal_size_mb:.1f}MB")
            
            if db_size_mb > 1000:
                self.alerts.append(f"Database muito grande: {db_size_mb:.1f}MB") 
                
            if journal_mode != 'wal':
                self.alerts.append(f"Journal mode incorreto: {journal_mode}")
                
            conn.close()
            logger.info(f"✅ Banco saudável - {db_size_mb:.1f}MB, WAL: {wal_size_mb:.1f}MB")
            return result
            
        except Exception as e:
            error_msg = f"Erro na verificação do banco: {e}"
            logger.error(f"❌ {error_msg}")
            return {'status': 'error', 'error': error_msg}

    def test_data_freshness(self) -> Dict:
        """Testa se os dados estão atualizados"""
        logger.info("📅 Testando atualidade dos dados...")
        
        try:
            conn = self.get_connection()
            today = date.today()
            yesterday = today - timedelta(days=1)
            two_days_ago = today - timedelta(days=2)
            
            sources_status = {}
            
            # CEPEA - deve ter dados de ontem ou hoje
            cursor = conn.execute("""
                SELECT MAX(data_coleta) as ultima_data, COUNT(*) as total_registros
                FROM cepea_precos 
                WHERE data_coleta >= ?
            """, (two_days_ago.isoformat(),))
            
            row = cursor.fetchone()
            cepea_last = row[0] if row[0] else '1900-01-01'
            cepea_count = row[1]
            
            cepea_days_old = (today - date.fromisoformat(cepea_last)).days
            sources_status['CEPEA'] = {
                'ultima_data': cepea_last,
                'dias_atraso': cepea_days_old,
                'registros_recentes': cepea_count,
                'status': 'ok' if cepea_days_old <= 1 else 'stale'
            }
            
            # IMEA - dados semanais, aceita até 7 dias
            cursor = conn.execute("""
                SELECT MAX(data_referencia) as ultima_data, COUNT(*) as total_registros
                FROM imea_dados 
                WHERE data_referencia >= ?
            """, ((today - timedelta(days=14)).isoformat(),))
            
            row = cursor.fetchone()
            imea_last = row[0] if row[0] else '1900-01-01'
            imea_count = row[1]
            
            imea_days_old = (today - date.fromisoformat(imea_last)).days
            sources_status['IMEA'] = {
                'ultima_data': imea_last,
                'dias_atraso': imea_days_old,
                'registros_recentes': imea_count,
                'status': 'ok' if imea_days_old <= 7 else 'stale'
            }
            
            # CLIMA - dados diários, aceita até 2 dias
            cursor = conn.execute("""
                SELECT MAX(data_medicao) as ultima_data, COUNT(*) as total_registros
                FROM clima_dados 
                WHERE data_medicao >= ?
            """, (two_days_ago.isoformat(),))
            
            row = cursor.fetchone()
            clima_last = row[0] if row[0] else '1900-01-01'
            clima_count = row[1]
            
            clima_days_old = (today - date.fromisoformat(clima_last)).days
            sources_status['CLIMA'] = {
                'ultima_data': clima_last,
                'dias_atraso': clima_days_old,
                'registros_recentes': clima_count,
                'status': 'ok' if clima_days_old <= 2 else 'stale'
            }
            
            # Gera alertas
            for fonte, info in sources_status.items():
                if info['status'] == 'stale':
                    self.alerts.append(f"{fonte}: dados desatualizados ({info['dias_atraso']} dias)")
                if info['registros_recentes'] == 0:
                    self.alerts.append(f"{fonte}: nenhum registro recente")
                    
            conn.close()
            
            overall_status = 'ok'
            if any(info['status'] == 'stale' for info in sources_status.values()):
                overall_status = 'stale'
            
            result = {
                'status': overall_status,
                'sources': sources_status,
                'check_date': today.isoformat()
            }
            
            logger.info(f"✅ Dados verificados - Status: {overall_status}")
            return result
            
        except Exception as e:
            error_msg = f"Erro na verificação de dados: {e}"
            logger.error(f"❌ {error_msg}")
            return {'status': 'error', 'error': error_msg}

    def test_ingestion_performance(self) -> Dict:
        """Testa performance das últimas ingestões"""
        logger.info("⚡ Testando performance das ingestões...")
        
        try:
            conn = self.get_connection()
            
            # Últimas execuções (24h)
            yesterday = datetime.now() - timedelta(days=1)
            
            cursor = conn.execute("""
                SELECT fonte, 
                       COUNT(*) as total_execucoes,
                       AVG(tempo_execucao_ms) as tempo_medio_ms,
                       MAX(tempo_execucao_ms) as tempo_max_ms,
                       SUM(registros_inseridos + registros_atualizados) as total_registros,
                       SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) as execucoes_falhas
                FROM ingest_control 
                WHERE data_execucao >= ?
                GROUP BY fonte
            """, (yesterday,))
            
            perf_data = {}
            for row in cursor.fetchall():
                fonte = row[0]
                if fonte == 'INIT':  # Skip initialization record
                    continue
                    
                exec_count = row[1]
                avg_time = int(row[2]) if row[2] else 0
                max_time = int(row[3]) if row[3] else 0
                total_recs = row[4] if row[4] else 0
                failed_count = row[5] if row[5] else 0
                
                # Calcula throughput
                throughput = total_recs / max((avg_time / 1000), 1) if avg_time > 0 else 0
                
                perf_data[fonte] = {
                    'execucoes_24h': exec_count,
                    'tempo_medio_ms': avg_time,
                    'tempo_maximo_ms': max_time,
                    'registros_processados': total_recs,
                    'execucoes_falhas': failed_count,
                    'throughput_rps': round(throughput, 2),
                    'taxa_sucesso': round(((exec_count - failed_count) / exec_count * 100), 1) if exec_count > 0 else 0
                }
                
                # Alertas de performance
                if failed_count > 0:
                    self.alerts.append(f"{fonte}: {failed_count} execuções falharam em 24h")
                if avg_time > 30000:  # > 30s
                    self.alerts.append(f"{fonte}: execução muito lenta ({avg_time/1000:.1f}s)")
                if throughput < 10:  # < 10 registros/segundo
                    self.alerts.append(f"{fonte}: throughput baixo ({throughput:.1f} rps)")
                    
            conn.close()
            
            result = {
                'status': 'ok' if len(self.alerts) == 0 else 'warning',
                'performance_data': perf_data,
                'check_timestamp': datetime.now().isoformat()
            }
            
            logger.info(f"✅ Performance verificada - {len(perf_data)} fontes analisadas")
            return result
            
        except Exception as e:
            error_msg = f"Erro na verificação de performance: {e}"
            logger.error(f"❌ {error_msg}")
            return {'status': 'error', 'error': error_msg}

    def test_lock_contention(self) -> Dict:
        """Testa se há contenção de locks"""
        logger.info("🔒 Testando contenção de locks...")
        
        try:
            # Verifica arquivos de lock existentes
            lock_files = [
                '/tmp/cepea_ingest.lock',
                '/tmp/imea_ingest.lock', 
                '/tmp/clima_ingest.lock',
                '/tmp/cepea_master.lock',
                '/tmp/imea_master.lock',
                '/tmp/clima_master.lock'
            ]
            
            active_locks = []
            stale_locks = []
            
            for lock_file in lock_files:
                if os.path.exists(lock_file):
                    stat_info = os.stat(lock_file)
                    age_minutes = (time.time() - stat_info.st_mtime) / 60
                    
                    lock_info = {
                        'file': lock_file,
                        'age_minutes': round(age_minutes, 1),
                        'size': stat_info.st_size
                    }
                    
                    if age_minutes > 30:  # Lock antigo demais
                        stale_locks.append(lock_info)
                        self.alerts.append(f"Lock antigo detectado: {lock_file} ({age_minutes:.1f}min)")
                    else:
                        active_locks.append(lock_info)
                        
            # Testa latência de escrita simples
            conn = self.get_connection()
            start_time = time.time()
            
            conn.execute("""
                INSERT INTO performance_metrics 
                (fonte, latencia_ms, throughput_regs_sec) 
                VALUES ('SMOKE_TEST', ?, ?)
            """, (1, 1))
            
            write_latency = int((time.time() - start_time) * 1000)
            
            # Remove o teste
            conn.execute("DELETE FROM performance_metrics WHERE fonte = 'SMOKE_TEST'")
            conn.close()
            
            result = {
                'status': 'ok' if len(stale_locks) == 0 else 'warning',
                'active_locks': active_locks,
                'stale_locks': stale_locks,
                'write_latency_ms': write_latency,
                'contention_risk': 'high' if len(active_locks) > 2 else 'low'
            }
            
            if write_latency > 1000:  # > 1s
                self.alerts.append(f"Latência de escrita alta: {write_latency}ms")
                
            logger.info(f"✅ Locks verificados - {len(active_locks)} ativos, {len(stale_locks)} obsoletos")
            return result
            
        except Exception as e:
            error_msg = f"Erro na verificação de locks: {e}"
            logger.error(f"❌ {error_msg}")
            return {'status': 'error', 'error': error_msg}

    def run_all_tests(self) -> Dict:
        """Executa todos os smoke tests"""
        logger.info("🚀 Iniciando smoke tests SPR...")
        
        start_time = time.time()
        
        # Executa todos os testes
        self.results = {
            'database_health': self.test_database_health(),
            'data_freshness': self.test_data_freshness(),
            'ingestion_performance': self.test_ingestion_performance(),
            'lock_contention': self.test_lock_contention()
        }
        
        # Status geral
        overall_status = 'ok'
        error_count = 0
        warning_count = 0
        
        for test_name, result in self.results.items():
            if result.get('status') == 'error':
                error_count += 1
                overall_status = 'error'
            elif result.get('status') in ['warning', 'stale']:
                warning_count += 1
                if overall_status == 'ok':
                    overall_status = 'warning'
        
        execution_time = int((time.time() - start_time) * 1000)
        
        summary = {
            'timestamp': datetime.now().isoformat(),
            'overall_status': overall_status,
            'execution_time_ms': execution_time,
            'tests_run': len(self.results),
            'errors': error_count,
            'warnings': warning_count,
            'alerts': self.alerts,
            'results': self.results
        }
        
        # Log do resultado
        status_emoji = "✅" if overall_status == 'ok' else "⚠️" if overall_status == 'warning' else "❌"
        logger.info(f"{status_emoji} Smoke tests concluídos - Status: {overall_status.upper()}")
        logger.info(f"📊 Resumo: {len(self.results)} testes, {error_count} erros, {warning_count} warnings")
        
        if self.alerts:
            logger.warning("🚨 Alertas encontrados:")
            for alert in self.alerts:
                logger.warning(f"  - {alert}")
        
        return summary

def main():
    """Função principal"""
    import argparse
    
    parser = argparse.ArgumentParser(description='SPR Smoke Tests')
    parser.add_argument('--db-path', type=str, 
                       default='/opt/spr/data/spr_central.db',
                       help='Caminho do banco SQLite')
    parser.add_argument('--json-output', action='store_true',
                       help='Saída em formato JSON')
    
    args = parser.parse_args()
    
    # Executa testes
    tester = SprSmokeTest(args.db_path)
    results = tester.run_all_tests()
    
    # Output
    if args.json_output:
        print(json.dumps(results, indent=2, ensure_ascii=False))
    
    # Exit code baseado no status
    if results['overall_status'] == 'ok':
        exit(0)
    elif results['overall_status'] == 'warning':
        exit(1)
    else:
        exit(2)

if __name__ == '__main__':
    main()