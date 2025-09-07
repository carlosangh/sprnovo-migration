#!/usr/bin/env python3
"""
SPRClient - Cliente para integração com a API do Sistema Preditivo Royal
Implementa os endpoints do sistema SPR para análise de commodities
"""

import os
import logging
import requests
import json
from typing import List, Dict, Any, Optional, Tuple
from datetime import datetime

logger = logging.getLogger(__name__)

class SPRClient:
    """Cliente para comunicação com a API SPR"""
    
    def __init__(self, base_url: str = "http://localhost:3002", api_version: str = "spr"):
        self.base_url = base_url.rstrip('/')
        self.api_version = api_version
        self.api_base = f"{self.base_url}/api/{api_version}"
        self.session = requests.Session()
        self.session.headers.update({
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        })
        
        # Configurações padrão SPR
        self.tenant_default = "royal_spr"
        self.top_k = 8
        self.min_score = 0.65
        self.ctx_docs_max = 5
        
    def _make_request(self, method: str, endpoint: str, **kwargs) -> Dict[str, Any]:
        """Faz requisição HTTP para a API SPR"""
        url = f"{self.api_base}{endpoint}"
        
        try:
            response = self.session.request(method, url, **kwargs)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            logger.error(f"SPR API request failed: {e}")
            return {"error": str(e), "success": False}
    
    def get_auth_info(self) -> Dict[str, Any]:
        """Obtém informações de autenticação e usuário atual"""
        try:
            result = self._make_request("GET", "/auth/me")
            return result
        except Exception as e:
            logger.error(f"Error getting auth info: {e}")
            return {"error": str(e), "success": False}
    
    def health_check(self) -> Dict[str, Any]:
        """Verifica saúde da API SPR"""
        try:
            result = self._make_request("GET", "/health")
            return result
        except Exception as e:
            logger.error(f"Health check failed: {e}")
            return {"error": str(e), "success": False}
    
    def upload_document(self, file_path: str, document_type: str = "commodity_report") -> Dict[str, Any]:
        """Upload de documento para análise OCR"""
        try:
            with open(file_path, 'rb') as file:
                files = {'file': file}
                data = {
                    'document_type': document_type,
                    'tenant': self.tenant_default
                }
                
                # Para upload, não usar session com JSON header
                url = f"{self.api_base}/ocr/upload"
                response = requests.post(url, files=files, data=data)
                response.raise_for_status()
                return response.json()
                
        except Exception as e:
            logger.error(f"Document upload failed: {e}")
            return {"error": str(e), "success": False}
    
    def analyze_document(self, document_id: str, analysis_type: str = "commodity_analysis") -> Dict[str, Any]:
        """Solicita análise de documento"""
        try:
            data = {
                "document_id": document_id,
                "analysis_type": analysis_type,
                "tenant": self.tenant_default,
                "settings": {
                    "extract_prices": True,
                    "extract_volumes": True,
                    "extract_regions": True,
                    "extract_commodities": True,
                    "confidence_threshold": self.min_score
                }
            }
            
            result = self._make_request("POST", "/ocr/analyze", json=data)
            return result
            
        except Exception as e:
            logger.error(f"Document analysis failed: {e}")
            return {"error": str(e), "success": False}
    
    def get_analysis_results(self, analysis_id: str) -> Dict[str, Any]:
        """Obtém resultados de análise"""
        try:
            result = self._make_request("GET", f"/ocr/results/{analysis_id}")
            return result
        except Exception as e:
            logger.error(f"Error getting analysis results: {e}")
            return {"error": str(e), "success": False}
    
    def search_commodities(self, query: str, filters: Dict[str, Any] = None) -> Dict[str, Any]:
        """Busca informações sobre commodities"""
        try:
            data = {
                "query": query,
                "tenant": self.tenant_default,
                "top_k": self.top_k,
                "min_score": self.min_score,
                "filters": filters or {}
            }
            
            result = self._make_request("POST", "/search/commodities", json=data)
            return result
            
        except Exception as e:
            logger.error(f"Commodity search failed: {e}")
            return {"error": str(e), "success": False}
    
    def get_market_data(self, commodity: str = None, region: str = None) -> Dict[str, Any]:
        """Obtém dados de mercado"""
        try:
            params = {}
            if commodity:
                params['commodity'] = commodity
            if region:
                params['region'] = region
                
            result = self._make_request("GET", "/market-data", params=params)
            return result
            
        except Exception as e:
            logger.error(f"Market data request failed: {e}")
            return {"error": str(e), "success": False}
    
    def get_trading_signals(self, commodity: str = None) -> Dict[str, Any]:
        """Obtém sinais de trading"""
        try:
            params = {}
            if commodity:
                params['commodity'] = commodity
                
            result = self._make_request("GET", "/trading-signals", params=params)
            return result
            
        except Exception as e:
            logger.error(f"Trading signals request failed: {e}")
            return {"error": str(e), "success": False}
    
    def submit_analysis_query(self, query: str, context: str = "market_analysis") -> Dict[str, Any]:
        """Submete consulta para análise inteligente"""
        try:
            data = {
                "query": query,
                "context": context,
                "tenant": self.tenant_default,
                "settings": {
                    "top_k": self.top_k,
                    "min_score": self.min_score,
                    "include_context": True,
                    "max_context_docs": self.ctx_docs_max
                }
            }
            
            result = self._make_request("POST", "/analysis/query", json=data)
            return result
            
        except Exception as e:
            logger.error(f"Analysis query failed: {e}")
            return {"error": str(e), "success": False}
    
    def get_offers(self, filters: Dict[str, Any] = None) -> Dict[str, Any]:
        """Obtém ofertas de commodities"""
        try:
            params = filters or {}
            result = self._make_request("GET", "/offers", params=params)
            return result
            
        except Exception as e:
            logger.error(f"Offers request failed: {e}")
            return {"error": str(e), "success": False}
    
    def create_offer(self, offer_data: Dict[str, Any]) -> Dict[str, Any]:
        """Cria nova oferta"""
        try:
            data = {
                **offer_data,
                "tenant": self.tenant_default,
                "created_at": datetime.now().isoformat()
            }
            
            result = self._make_request("POST", "/offers", json=data)
            return result
            
        except Exception as e:
            logger.error(f"Create offer failed: {e}")
            return {"error": str(e), "success": False}
    
    def get_analytics_summary(self) -> Dict[str, Any]:
        """Obtém resumo de analytics"""
        try:
            result = self._make_request("GET", "/analytics/summary")
            return result
        except Exception as e:
            logger.error(f"Analytics summary failed: {e}")
            return {"error": str(e), "success": False}
    
    def get_research_reports(self, topic: str = None) -> Dict[str, Any]:
        """Obtém relatórios de pesquisa"""
        try:
            params = {}
            if topic:
                params['topic'] = topic
                
            result = self._make_request("GET", "/research/reports", params=params)
            return result
            
        except Exception as e:
            logger.error(f"Research reports request failed: {e}")
            return {"error": str(e), "success": False}
    
    def request_research(self, topic: str, scope: str = "market_analysis") -> Dict[str, Any]:
        """Solicita nova pesquisa"""
        try:
            data = {
                "topic": topic,
                "scope": scope,
                "tenant": self.tenant_default,
                "settings": {
                    "max_sources": 10,
                    "include_trends": True,
                    "include_sentiment": True
                }
            }
            
            result = self._make_request("POST", "/research/request", json=data)
            return result
            
        except Exception as e:
            logger.error(f"Research request failed: {e}")
            return {"error": str(e), "success": False}

def main():
    """Exemplo de uso do SPR Client"""
    import sys
    
    # Configurar logging
    logging.basicConfig(level=logging.INFO)
    
    client = SPRClient()
    
    print("🌾 SPR Client - Sistema Preditivo Royal")
    print("=" * 50)
    
    # Teste de health check
    print("\n1. Verificando saúde da API...")
    health = client.health_check()
    print(f"Health: {health}")
    
    # Teste de dados de mercado
    print("\n2. Obtendo dados de mercado...")
    market_data = client.get_market_data("SOJA")
    print(f"Market Data: {market_data}")
    
    # Teste de ofertas
    print("\n3. Obtendo ofertas...")
    offers = client.get_offers()
    print(f"Offers: {offers}")
    
    # Teste de analytics
    print("\n4. Resumo de analytics...")
    analytics = client.get_analytics_summary()
    print(f"Analytics: {analytics}")
    
    if len(sys.argv) > 1:
        # Teste de análise de consulta
        query = sys.argv[1]
        print(f"\n5. Analisando consulta: '{query}'...")
        analysis = client.submit_analysis_query(query)
        print(f"Analysis: {analysis}")

if __name__ == "__main__":
    main()