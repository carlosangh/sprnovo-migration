#!/usr/bin/env python3
"""
SPR - Daily Report Generator
Gera relatório diário de ingestões com métricas e calendário
"""

import sqlite3
import logging
import json
import os
from datetime import datetime, date, timedelta
from typing import Dict, List, Tuple
import calendar

# Configuração de logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('daily_report')

class DailyReportGenerator:
    def __init__(self, db_path: str = '/opt/spr/data/spr_central.db'):
        self.db_path = db_path
        self.report_date = date.today()
        
    def get_connection(self) -> sqlite3.Connection:
        """Conexão SQLite"""
        conn = sqlite3.connect(self.db_path, timeout=5.0)
        conn.row_factory = sqlite3.Row
        return conn

    def get_ingestion_summary(self) -> Dict:
        """Resumo das ingestões das últimas 24h"""
        conn = self.get_connection()
        
        yesterday = datetime.now() - timedelta(days=1)
        
        cursor = conn.execute("""
            SELECT 
                fonte,
                COUNT(*) as execucoes,
                SUM(registros_inseridos) as total_inseridos,
                SUM(registros_atualizados) as total_atualizados,
                AVG(tempo_execucao_ms) as tempo_medio_ms,
                MAX(tempo_execucao_ms) as tempo_max_ms,
                MIN(data_execucao) as primeira_execucao,
                MAX(data_execucao) as ultima_execucao,
                SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) as falhas
            FROM ingest_control 
            WHERE data_execucao >= ? AND fonte != 'INIT'
            GROUP BY fonte
            ORDER BY fonte
        """, (yesterday,))
        
        summary = {}
        for row in cursor.fetchall():
            fonte = row[0]
            summary[fonte] = {
                'execucoes': row[1],
                'registros_inseridos': row[2] or 0,
                'registros_atualizados': row[3] or 0,
                'tempo_medio_ms': int(row[4]) if row[4] else 0,
                'tempo_maximo_ms': int(row[5]) if row[5] else 0,
                'primeira_execucao': row[6],
                'ultima_execucao': row[7],
                'falhas': row[8] or 0,
                'taxa_sucesso': round(((row[1] - (row[8] or 0)) / row[1] * 100), 1) if row[1] > 0 else 0
            }
            
        conn.close()
        return summary

    def get_data_status(self) -> Dict:
        """Status atual dos dados por fonte"""
        conn = self.get_connection()
        
        data_status = {}
        
        # CEPEA
        cursor = conn.execute("""
            SELECT 
                COUNT(*) as total,
                COUNT(DISTINCT commodity) as commodities,
                MAX(data_coleta) as ultima_data,
                MIN(data_coleta) as primeira_data
            FROM cepea_precos
        """)
        row = cursor.fetchone()
        data_status['CEPEA'] = {
            'total_registros': row[0],
            'commodities_ativas': row[1],
            'ultima_data': row[2],
            'primeira_data': row[3],
            'cobertura_dias': (date.fromisoformat(row[2]) - date.fromisoformat(row[3])).days + 1 if row[2] and row[3] else 0
        }
        
        # IMEA  
        cursor = conn.execute("""
            SELECT 
                COUNT(*) as total,
                COUNT(DISTINCT regiao) as regioes,
                COUNT(DISTINCT commodity) as commodities,
                MAX(data_referencia) as ultima_data,
                MIN(data_referencia) as primeira_data
            FROM imea_dados
        """)
        row = cursor.fetchone()
        data_status['IMEA'] = {
            'total_registros': row[0],
            'regioes_ativas': row[1],
            'commodities_ativas': row[2],
            'ultima_data': row[3],
            'primeira_data': row[4],
            'cobertura_dias': (date.fromisoformat(row[3]) - date.fromisoformat(row[4])).days + 1 if row[3] and row[4] else 0
        }
        
        # CLIMA
        cursor = conn.execute("""
            SELECT 
                COUNT(*) as total,
                COUNT(DISTINCT codigo_estacao) as estacoes,
                COUNT(DISTINCT uf) as ufs,
                MAX(data_medicao) as ultima_data,
                MIN(data_medicao) as primeira_data
            FROM clima_dados
        """)
        row = cursor.fetchone()
        data_status['CLIMA'] = {
            'total_registros': row[0],
            'estacoes_ativas': row[1],
            'ufs_cobertas': row[2],
            'ultima_data': row[3],
            'primeira_data': row[4],
            'cobertura_dias': (date.fromisoformat(row[3]) - date.fromisoformat(row[4])).days + 1 if row[3] and row[4] else 0
        }
        
        conn.close()
        return data_status

    def get_performance_metrics(self) -> Dict:
        """Métricas de performance das últimas 24h"""
        conn = self.get_connection()
        
        yesterday = datetime.now() - timedelta(days=1)
        
        cursor = conn.execute("""
            SELECT 
                fonte,
                AVG(latencia_ms) as latencia_media,
                MAX(latencia_ms) as latencia_maxima,
                AVG(throughput_regs_sec) as throughput_medio,
                AVG(db_size_mb) as tamanho_db_mb,
                MAX(wal_size_mb) as wal_max_mb,
                COUNT(*) as medicoes
            FROM performance_metrics 
            WHERE timestamp_metric >= ?
            GROUP BY fonte
        """, (yesterday,))
        
        metrics = {}
        for row in cursor.fetchall():
            fonte = row[0]
            if fonte == 'SMOKE_TEST':
                continue
                
            metrics[fonte] = {
                'latencia_media_ms': int(row[1]) if row[1] else 0,
                'latencia_maxima_ms': int(row[2]) if row[2] else 0,
                'throughput_medio_rps': round(row[3], 2) if row[3] else 0,
                'tamanho_db_mb': round(row[4], 2) if row[4] else 0,
                'wal_maximo_mb': round(row[5], 2) if row[5] else 0,
                'medicoes_24h': row[6]
            }
            
        conn.close()
        return metrics

    def generate_next_runs_calendar(self) -> Dict:
        """Gera calendário com próximas execuções"""
        
        # Configuração dos crons (hora, minuto)
        cron_schedule = {
            'CEPEA': [(7, 5), (12, 35), (18, 5)],  # 3x ao dia
            'IMEA': [(6, 20), (17, 20)],          # 2x ao dia  
            'CLIMA': [(4, 45), (16, 45)],         # 2x ao dia
            'MANUTENCAO': [(3, 0)],               # 1x ao dia (checkpoint WAL)
            'SMOKE_TEST': [(8, 30), (14, 30), (20, 30)],  # 3x ao dia
            'RELATORIO': [(23, 15)]               # 1x ao dia
        }
        
        calendar_data = {}
        now = datetime.now()
        
        for days_ahead in range(7):  # Próximos 7 dias
            target_date = now.date() + timedelta(days=days_ahead)
            date_str = target_date.isoformat()
            calendar_data[date_str] = {
                'weekday': calendar.day_name[target_date.weekday()],
                'executions': []
            }
            
            for fonte, times in cron_schedule.items():
                for hour, minute in times:
                    exec_time = datetime.combine(target_date, datetime.min.time().replace(hour=hour, minute=minute))
                    
                    # Só mostra execuções futuras para hoje
                    if target_date == now.date() and exec_time <= now:
                        continue
                        
                    calendar_data[date_str]['executions'].append({
                        'time': f"{hour:02d}:{minute:02d}",
                        'fonte': fonte,
                        'timestamp': exec_time.isoformat()
                    })
            
            # Ordena execuções por horário
            calendar_data[date_str]['executions'].sort(key=lambda x: x['time'])
            
        return calendar_data

    def detect_issues(self, ingestion_summary: Dict, data_status: Dict) -> List[str]:
        """Detecta problemas potenciais"""
        issues = []
        
        # Verifica falhas nas ingestões
        for fonte, info in ingestion_summary.items():
            if info['falhas'] > 0:
                issues.append(f"❌ {fonte}: {info['falhas']} execuções falharam")
            
            if info['taxa_sucesso'] < 90:
                issues.append(f"⚠️ {fonte}: taxa de sucesso baixa ({info['taxa_sucesso']:.1f}%)")
                
            if info['tempo_medio_ms'] > 30000:
                issues.append(f"🐌 {fonte}: execução lenta ({info['tempo_medio_ms']/1000:.1f}s)")
        
        # Verifica atualidade dos dados
        today = date.today()
        for fonte, info in data_status.items():
            if info['ultima_data']:
                days_old = (today - date.fromisoformat(info['ultima_data'])).days
                
                if fonte == 'CEPEA' and days_old > 1:
                    issues.append(f"📅 {fonte}: dados desatualizados ({days_old} dias)")
                elif fonte == 'IMEA' and days_old > 7:
                    issues.append(f"📅 {fonte}: dados desatualizados ({days_old} dias)")
                elif fonte == 'CLIMA' and days_old > 2:
                    issues.append(f"📅 {fonte}: dados desatualizados ({days_old} dias)")
        
        return issues

    def generate_report(self) -> Dict:
        """Gera relatório completo"""
        logger.info("📊 Gerando relatório diário...")
        
        ingestion_summary = self.get_ingestion_summary()
        data_status = self.get_data_status()
        performance_metrics = self.get_performance_metrics()
        calendar_data = self.generate_next_runs_calendar()
        issues = self.detect_issues(ingestion_summary, data_status)
        
        # Cálculos gerais
        total_records = sum(info['total_registros'] for info in data_status.values())
        total_executions = sum(info['execucoes'] for info in ingestion_summary.values())
        total_failures = sum(info['falhas'] for info in ingestion_summary.values())
        
        report = {
            'metadata': {
                'report_date': self.report_date.isoformat(),
                'generated_at': datetime.now().isoformat(),
                'database_path': self.db_path
            },
            'summary': {
                'total_records': total_records,
                'total_executions_24h': total_executions,
                'total_failures_24h': total_failures,
                'overall_success_rate': round(((total_executions - total_failures) / total_executions * 100), 1) if total_executions > 0 else 100,
                'issues_detected': len(issues)
            },
            'ingestion_summary': ingestion_summary,
            'data_status': data_status,
            'performance_metrics': performance_metrics,
            'next_runs_calendar': calendar_data,
            'issues': issues
        }
        
        logger.info(f"✅ Relatório gerado - {total_records:,} registros, {total_executions} execuções")
        
        return report

def main():
    """Função principal"""
    import argparse
    
    parser = argparse.ArgumentParser(description='SPR Daily Report Generator')
    parser.add_argument('--db-path', type=str, 
                       default='/opt/spr/data/spr_central.db',
                       help='Caminho do banco SQLite')
    parser.add_argument('--output', type=str,
                       help='Arquivo de saída (padrão: stdout)')
    parser.add_argument('--format', choices=['json', 'markdown'], 
                       default='json',
                       help='Formato de saída')
    
    args = parser.parse_args()
    
    # Gera relatório
    generator = DailyReportGenerator(args.db_path)
    report = generator.generate_report()
    
    # Formata saída
    if args.format == 'json':
        output = json.dumps(report, indent=2, ensure_ascii=False)
    else:
        # Formato markdown (básico)
        output = f"""# SPR Daily Report - {report['metadata']['report_date']}

## Resumo Geral
- **Total de registros**: {report['summary']['total_records']:,}
- **Execuções (24h)**: {report['summary']['total_executions_24h']}
- **Taxa de sucesso**: {report['summary']['overall_success_rate']:.1f}%
- **Issues detectados**: {report['summary']['issues_detected']}

## Status dos Dados
"""
        for fonte, info in report['data_status'].items():
            output += f"### {fonte}\n"
            output += f"- Registros: {info['total_registros']:,}\n"
            output += f"- Última data: {info['ultima_data']}\n"
            output += f"- Cobertura: {info['cobertura_dias']} dias\n\n"
        
        if report['issues']:
            output += "## Issues Detectados\n"
            for issue in report['issues']:
                output += f"- {issue}\n"
    
    # Salva ou imprime
    if args.output:
        with open(args.output, 'w', encoding='utf-8') as f:
            f.write(output)
        print(f"Relatório salvo em: {args.output}")
    else:
        print(output)

if __name__ == '__main__':
    main()