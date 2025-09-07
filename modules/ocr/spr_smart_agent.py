#!/usr/bin/env python3
"""
SPR SmartAnalysisAgent - Agent híbrido integrado com o Sistema Preditivo Royal
Robô do SPR que decide automaticamente entre análise local vs OpenAI para commodities
"""

import os
import time
import logging
import re
from typing import List, Dict, Any
from datetime import datetime

# OpenAI (configuração via environment)
try:
    import openai
    from openai import OpenAI
    HAS_OPENAI = True
except ImportError:
    HAS_OPENAI = False

# SPR Integration
from spr_client import SPRClient

# Imports do sistema OCR
try:
    from ocr_service_enhanced import BaseAgent, AgentType, ProcessingTask, AgentResult
except ImportError:
    # Fallback se não tiver o sistema OCR enhanced
    from enum import Enum
    
    class AgentType(Enum):
        SMART_ANALYST = "smart_analyst"
    
    class BaseAgent:
        def __init__(self, agent_id, agent_type):
            self.agent_id = agent_id
            self.agent_type = agent_type
    
    class ProcessingTask:
        pass
    
    class AgentResult:
        def __init__(self, **kwargs):
            self.__dict__.update(kwargs)

logger = logging.getLogger(__name__)

class SPRSmartAgent(BaseAgent):
    """Robô do SPR - Agent inteligente integrado com Sistema Preditivo Royal"""
    
    def __init__(self, agent_id: str):
        super().__init__(agent_id, AgentType.SMART_ANALYST)
        self.openai_client = None
        self.spr_client = None
        self._initialize_services()
        
        # Configurações SPR
        self.tenant_default = "royal_spr"
        self.openai_model = "gpt-4o-mini"
        self.openai_temperature = 0.2
        self.openai_max_tokens = 1200
        self.top_k = 8
        self.min_score = 0.65
        self.ctx_docs_max = 5
        
        # Padrões para classificação de intenção (commodities brasileiras)
        self.local_patterns = [
            # Busca simples
            r'busca|busque|encontre|liste|mostre|exiba',
            r'documentos? sobre|arquivos? de|relatórios? de',
            r'últimos? documentos?|documentos? recentes?',
            r'onde está|qual foi|quais são',
            
            # Commodities específicas
            r'soja|milho|trigo|café|boi gordo|suíno|algodão',
            r'preços? de|cotação|valor|mercado',
            r'oferta|demanda|volume|produção',
            r'cepea|imea|b3|bolsa|mercado',
            
            # Regiões brasileiras
            r'mato grosso|são paulo|paraná|rio grande do sul',
            r'mt|sp|pr|rs|go|mg|ba',
            r'região|estado|município'
        ]
        
        self.openai_patterns = [
            # Análise complexa
            r'analise|análise|interprete|explique',
            r'compare|comparação|diferença|versus',
            r'recomend|suger|aconselh|indic',
            r'estratégia|plano|decisão|escolha',
            
            # Predições e tendências
            r'prevê|previsão|tendência|futuro',
            r'projeção|estimativa|expectativa',
            r'vai subir|vai cair|vai aumentar|vai diminuir',
            r'melhor momento|quando comprar|quando vender',
            
            # Análises técnicas
            r'risco|volatilidade|correlação',
            r'oportunidade|investimento|trading',
            r'signal|sinal|entrada|saída'
        ]
    
    def _initialize_services(self):
        """Inicializa serviços SPR e OpenAI"""
        try:
            # Inicializar SPR Client
            self.spr_client = SPRClient()
            logger.info("✅ SPR Client inicializado")
            
            # Inicializar OpenAI (se disponível e configurado)
            if HAS_OPENAI and os.getenv('OPENAI_API_KEY'):
                self.openai_client = OpenAI(
                    api_key=os.getenv('OPENAI_API_KEY')
                )
                logger.info("✅ OpenAI Client inicializado")
            else:
                logger.warning("⚠️ OpenAI não disponível - usando apenas análise local SPR")
                
        except Exception as e:
            logger.error(f"❌ Erro ao inicializar serviços: {e}")
    
    def classify_intent(self, query: str) -> Dict[str, Any]:
        """Classifica a intenção da consulta para decidir entre local vs OpenAI"""
        query_lower = query.lower()
        
        # Contadores de padrões
        local_matches = sum(1 for pattern in self.local_patterns 
                          if re.search(pattern, query_lower))
        openai_matches = sum(1 for pattern in self.openai_patterns 
                           if re.search(pattern, query_lower))
        
        # Lógica de decisão
        if local_matches > openai_matches:
            decision = "local"
            confidence = min(0.9, 0.5 + (local_matches * 0.1))
        elif openai_matches > local_matches:
            decision = "openai"
            confidence = min(0.9, 0.5 + (openai_matches * 0.1))
        else:
            # Empate - preferir local para commodities, OpenAI para análises
            if any(re.search(r'soja|milho|café|boi|preço|oferta', query_lower)):
                decision = "local"
                confidence = 0.6
            else:
                decision = "openai"
                confidence = 0.6
        
        return {
            "decision": decision,
            "confidence": confidence,
            "local_matches": local_matches,
            "openai_matches": openai_matches,
            "reasoning": f"Padrões locais: {local_matches}, OpenAI: {openai_matches}"
        }
    
    def process_local_query(self, query: str) -> Dict[str, Any]:
        """Processa consulta usando apenas recursos locais SPR"""
        try:
            # Busca commodities no SPR
            search_results = self.spr_client.search_commodities(query)
            
            if not search_results.get('success', False):
                return {
                    "success": False,
                    "error": "Erro na busca local SPR",
                    "method": "local_spr"
                }
            
            # Obter dados de mercado relacionados
            market_data = self.spr_client.get_market_data()
            offers_data = self.spr_client.get_offers()
            
            # Compilar resposta local
            response = {
                "success": True,
                "method": "local_spr",
                "query": query,
                "results": {
                    "search_results": search_results,
                    "market_data": market_data.get('data', []),
                    "offers": offers_data.get('data', []),
                    "summary": self._generate_local_summary(query, search_results, market_data, offers_data)
                },
                "timestamp": datetime.now().isoformat(),
                "tenant": self.tenant_default
            }
            
            return response
            
        except Exception as e:
            logger.error(f"Erro no processamento local: {e}")
            return {
                "success": False,
                "error": str(e),
                "method": "local_spr"
            }
    
    def _generate_local_summary(self, query: str, search_results: Dict, market_data: Dict, offers_data: Dict) -> str:
        """Gera resumo baseado nos dados locais SPR"""
        summary_parts = []
        
        # Resumo da busca
        if search_results.get('success') and search_results.get('data'):
            results_count = len(search_results['data'])
            summary_parts.append(f"Encontrei {results_count} resultados relacionados à sua consulta.")
        
        # Resumo do mercado
        if market_data.get('success') and market_data.get('data'):
            market_count = len(market_data['data'])
            commodities = list(set([item.get('commodity', '') for item in market_data['data']]))
            summary_parts.append(f"Dados de mercado disponíveis para {market_count} registros ({', '.join(commodities[:3])}).")
        
        # Resumo das ofertas
        if offers_data.get('success') and offers_data.get('data'):
            offers_count = len(offers_data['data'])
            summary_parts.append(f"{offers_count} ofertas ativas encontradas.")
        
        if not summary_parts:
            summary_parts.append("Não foram encontrados dados específicos para sua consulta no sistema SPR.")
        
        return " ".join(summary_parts)
    
    def process_openai_query(self, query: str, context_data: Dict[str, Any] = None) -> Dict[str, Any]:
        """Processa consulta usando OpenAI com contexto SPR"""
        if not self.openai_client:
            return {
                "success": False,
                "error": "OpenAI não disponível",
                "fallback_to_local": True,
                "method": "openai_unavailable"
            }
        
        try:
            # Obter contexto do SPR
            context = self._build_spr_context(query)
            
            # Construir prompt para commodities brasileiras
            system_prompt = """Você é um especialista em commodities agrícolas brasileiras do Sistema Preditivo Royal (SPR). 
            Analise dados de mercado, preços, ofertas e tendências para soja, milho, café, boi gordo, suínos e outros produtos agrícolas.
            
            Fontes de dados: CEPEA, IMEA, B3
            Regiões principais: MT, SP, PR, RS, GO
            
            Seja preciso, objetivo e forneça insights acionáveis baseados nos dados disponíveis."""
            
            user_prompt = f"""
            Consulta: {query}
            
            Contexto dos dados SPR:
            {self._format_context_for_openai(context)}
            
            Por favor, analise e responda com base nos dados disponíveis.
            """
            
            # Fazer requisição OpenAI
            response = self.openai_client.chat.completions.create(
                model=self.openai_model,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt}
                ],
                temperature=self.openai_temperature,
                max_tokens=self.openai_max_tokens
            )
            
            # Processar resposta
            ai_response = response.choices[0].message.content
            
            return {
                "success": True,
                "method": "openai_with_spr_context",
                "query": query,
                "response": ai_response,
                "context_used": context,
                "model": self.openai_model,
                "timestamp": datetime.now().isoformat(),
                "tenant": self.tenant_default,
                "tokens_used": response.usage.total_tokens if hasattr(response, 'usage') else None
            }
            
        except Exception as e:
            logger.error(f"Erro no processamento OpenAI: {e}")
            return {
                "success": False,
                "error": str(e),
                "method": "openai_error",
                "fallback_to_local": True
            }
    
    def _build_spr_context(self, query: str) -> Dict[str, Any]:
        """Constrói contexto SPR para a consulta"""
        context = {}
        
        try:
            # Dados de mercado relevantes
            market_data = self.spr_client.get_market_data()
            if market_data.get('success'):
                context['market_data'] = market_data.get('data', [])
            
            # Ofertas relacionadas
            offers = self.spr_client.get_offers()
            if offers.get('success'):
                context['offers'] = offers.get('data', [])
            
            # Sinais de trading (se disponível)
            try:
                signals = self.spr_client.get_trading_signals()
                if signals.get('success'):
                    context['trading_signals'] = signals.get('data', [])
            except:
                pass
            
            # Analytics summary
            try:
                analytics = self.spr_client.get_analytics_summary()
                if analytics.get('success'):
                    context['analytics'] = analytics.get('data', {})
            except:
                pass
                
        except Exception as e:
            logger.error(f"Erro ao construir contexto SPR: {e}")
            context['error'] = str(e)
        
        return context
    
    def _format_context_for_openai(self, context: Dict[str, Any]) -> str:
        """Formata contexto SPR para o prompt OpenAI"""
        formatted_parts = []
        
        # Market data
        if 'market_data' in context and context['market_data']:
            market_summary = []
            for item in context['market_data'][:5]:  # Primeiros 5
                commodity = item.get('commodity', '')
                price = item.get('preco', '')
                variation = item.get('variacao', '')
                market_summary.append(f"{commodity}: R$ {price} ({variation}%)")
            
            formatted_parts.append(f"Dados de Mercado: {', '.join(market_summary)}")
        
        # Offers
        if 'offers' in context and context['offers']:
            offers_count = len(context['offers'])
            formatted_parts.append(f"Ofertas Ativas: {offers_count} disponíveis")
        
        # Trading signals
        if 'trading_signals' in context and context['trading_signals']:
            signals_count = len(context['trading_signals'])
            formatted_parts.append(f"Sinais de Trading: {signals_count} ativos")
        
        return "\n".join(formatted_parts) if formatted_parts else "Contexto limitado disponível"
    
    def process_query(self, query: str) -> Dict[str, Any]:
        """Método principal - processa consulta decidindo entre local vs OpenAI"""
        start_time = time.time()
        
        # Classificar intenção
        intent = self.classify_intent(query)
        
        logger.info(f"📊 Consulta: '{query[:50]}...' | Decisão: {intent['decision']} | Confiança: {intent['confidence']:.2f}")
        
        # Processar conforme decisão
        if intent['decision'] == 'local':
            result = self.process_local_query(query)
        else:
            result = self.process_openai_query(query)
            
            # Fallback para local se OpenAI falhar
            if not result.get('success') and result.get('fallback_to_local'):
                logger.info("🔄 Fallback para processamento local SPR")
                result = self.process_local_query(query)
        
        # Adicionar metadados de processamento
        result['processing_time'] = time.time() - start_time
        result['intent_classification'] = intent
        result['agent_id'] = self.agent_id
        
        return result
    
    def process(self, task: ProcessingTask) -> AgentResult:
        """Interface compatível com o sistema OCR enhanced"""
        try:
            query = getattr(task, 'query', '') or getattr(task, 'text', '')
            
            if not query:
                return AgentResult(
                    agent_id=self.agent_id,
                    success=False,
                    error="Nenhuma consulta fornecida",
                    processing_time=0.0
                )
            
            result = self.process_query(query)
            
            return AgentResult(
                agent_id=self.agent_id,
                success=result.get('success', False),
                result=result,
                processing_time=result.get('processing_time', 0.0),
                confidence=result.get('intent_classification', {}).get('confidence', 0.0)
            )
            
        except Exception as e:
            logger.error(f"Erro no processamento da task: {e}")
            return AgentResult(
                agent_id=self.agent_id,
                success=False,
                error=str(e),
                processing_time=0.0
            )

def main():
    """Exemplo de uso do SPR Smart Agent"""
    import sys
    
    # Configurar logging
    logging.basicConfig(level=logging.INFO)
    
    agent = SPRSmartAgent("spr_smart_001")
    
    print("🤖 SPR Smart Agent - Sistema Preditivo Royal")
    print("=" * 60)
    
    # Consultas de exemplo
    example_queries = [
        "Busque documentos sobre soja",
        "Quais são os preços atuais do milho?",
        "Analise as tendências do mercado de café",
        "Recomende uma estratégia para boi gordo",
        "Mostre as ofertas de trigo disponíveis"
    ]
    
    if len(sys.argv) > 1:
        # Usar consulta fornecida como argumento
        queries = [" ".join(sys.argv[1:])]
    else:
        # Usar consultas de exemplo
        queries = example_queries
    
    for i, query in enumerate(queries, 1):
        print(f"\n{i}. Processando: '{query}'")
        print("-" * 40)
        
        result = agent.process_query(query)
        
        print(f"Método: {result.get('method', 'unknown')}")
        print(f"Sucesso: {result.get('success', False)}")
        print(f"Tempo: {result.get('processing_time', 0):.2f}s")
        
        if result.get('success'):
            if result.get('method') == 'local_spr':
                summary = result.get('results', {}).get('summary', 'Sem resumo')
                print(f"Resumo: {summary}")
            elif 'response' in result:
                response = result['response'][:200] + "..." if len(result.get('response', '')) > 200 else result.get('response', '')
                print(f"Resposta: {response}")
        else:
            print(f"Erro: {result.get('error', 'Erro desconhecido')}")
        
        if i < len(queries):
            time.sleep(1)

if __name__ == "__main__":
    main()