#!/usr/bin/env python3
"""
CLG SmartAnalysisAgent - Agent híbrido integrado com o sistema CLG
Robô do CLG que decide automaticamente entre análise local vs OpenAI
"""

import os
import time
import logging
import re
from typing import List, Dict, Any
from datetime import datetime

# OpenAI
import openai
from openai import OpenAI

# CLG Integration
from clg_client import CLGClient

# Imports do sistema OCR
from ocr_service_enhanced import BaseAgent, AgentType, ProcessingTask, AgentResult

logger = logging.getLogger(__name__)

class CLGSmartAgent(BaseAgent):
    """Robô do CLG - Agent inteligente integrado com sistema CLG"""
    
    def __init__(self, agent_id: str):
        super().__init__(agent_id, AgentType.SMART_ANALYST)
        self.openai_client = None
        self.clg_client = None
        self._initialize_services()
        
        # Configurações CLG
        self.tenant_default = "tenant_luiz"
        self.openai_model = "gpt-4o-mini"
        self.openai_temperature = 0.2
        self.openai_max_tokens = 1200
        self.top_k = 8
        self.min_score = 0.65
        self.ctx_docs_max = 5
        
        # Padrões para classificação de intenção (conforme especificação CLG)
        self.local_patterns = [
            # Busca simples
            r'busca|busque|encontre|liste|mostre|exiba',
            r'documentos? sobre|arquivos? de|relatórios? de',
            r'últimos? documentos?|documentos? recentes?',
            r'onde está|qual foi|quais são',
            # Filtros básicos
            r'filtrar por|filtrar documentos?',
            r'tipo de documento|categoria',
            r'data|período|mês|ano',
        ]
        
        self.openai_patterns = [
            # Análises complexas
            r'analise|análise|analisar|avalie|avaliar',
            r'tendência|tendências|padrão|padrões',
            r'preveja|previsão|projeção|cenário',
            r'compare|comparação|diferença|variação',
            r'insight|conclusão|interpretação|resumo',
            r'recomend|sugest|estratégia|decisão',
            # Operações cognitivas
            r'explique|explicar|justificar|razão',
            r'correlação|relação|impacto|influência',
            r'o que significa|por que|como afeta',
            r'resumir|sintetizar|consolidar'
        ]
    
    def _initialize_services(self):
        try:
            # OpenAI client
            openai_key = "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"
            self.openai_client = OpenAI(api_key=openai_key)
            
            # CLG Client (primary)
            self.clg_client = CLGClient()
            
            # Test CLG connection
            if self.clg_client.test_connection():
                logger.info(f"CLG SmartAgent initialized - CLG connection OK")
            else:
                logger.warning(f"CLG SmartAgent initialized - CLG connection failed")
            
        except Exception as e:
            logger.error(f"Error initializing CLG SmartAgent: {e}")
    
    async def process(self, task: ProcessingTask) -> AgentResult:
        start_time = time.time()
        self.is_active = True
        self.last_activity = datetime.now()
        
        try:
            query = task.metadata.get('query', '')
            user_intent = task.metadata.get('intent', 'auto')
            tenant = task.metadata.get('tenant', self.tenant_default)
            all_tenants = task.metadata.get('all_tenants', False)
            
            if not query:
                raise ValueError("No query provided for analysis")
            
            # Decisão automática da estratégia
            if user_intent == 'auto':
                strategy = self._classify_intent(query)
            else:
                strategy = user_intent
            
            logger.info(f"CLG Robot - Query: '{query[:50]}...' -> Strategy: {strategy}")
            
            # Adicionar informações de contexto
            task.metadata.update({
                'tenant': tenant,
                'all_tenants': all_tenants,
                'top_k': task.metadata.get('limit', self.top_k),
                'min_score': task.metadata.get('min_score', self.min_score)
            })
            
            if strategy == 'local':
                result_data = await self._local_clg_search(query, task.metadata)
            else:
                result_data = await self._openai_clg_analysis(query, task.metadata)
            
            result = AgentResult(
                agent_id=self.agent_id,
                agent_type=self.agent_type,
                task_id=task.task_id,
                success=True,
                data={
                    'strategy_used': strategy,
                    'query': query,
                    'tenant': tenant,
                    **result_data
                },
                processing_time=time.time() - start_time,
                confidence=result_data.get('confidence', 0.8)
            )
            
        except Exception as e:
            logger.error(f"CLG SmartAgent {self.agent_id} error: {e}")
            result = AgentResult(
                agent_id=self.agent_id,
                agent_type=self.agent_type,
                task_id=task.task_id,
                success=False,
                data={'strategy_used': 'error', 'tenant': task.metadata.get('tenant', self.tenant_default)},
                processing_time=time.time() - start_time,
                error=str(e)
            )
        finally:
            self.is_active = False
            self.processed_count += 1
            
        return result
    
    def _classify_intent(self, query: str) -> str:
        """Classifica automaticamente se deve usar análise local ou OpenAI"""
        query_lower = query.lower()
        
        # Pontua para cada categoria
        local_score = 0
        openai_score = 0
        
        # Verifica padrões locais
        for pattern in self.local_patterns:
            if re.search(pattern, query_lower):
                local_score += 1
        
        # Verifica padrões OpenAI
        for pattern in self.openai_patterns:
            if re.search(pattern, query_lower):
                openai_score += 1
        
        # Palavras-chave que indicam complexidade
        complex_keywords = ['por que', 'como', 'qual impacto', 'o que significa', 
                           'estratégia', 'recomendação', 'decisão']
        
        for keyword in complex_keywords:
            if keyword in query_lower:\n                openai_score += 2
        
        # Decide baseado na pontuação
        if openai_score > local_score:
            return 'openai'
        else:
            return 'local'
    
    async def _local_clg_search(self, query: str, metadata: Dict) -> Dict[str, Any]:
        """Análise local usando CLG RAG"""
        try:
            tenant = metadata.get('tenant', self.tenant_default)
            all_tenants = metadata.get('all_tenants', False)
            top_k = metadata.get('top_k', self.top_k)
            min_score = metadata.get('min_score', self.min_score)
            
            # Buscar via CLG
            clg_result = self.clg_client.rag_search(
                query=query,
                tenant=tenant,
                all_tenants=all_tenants,
                top_k=top_k,
                min_score=min_score
            )
            
            if clg_result.get('success', False):
                documents = clg_result.get('documents', [])
                
                # Preparar resposta no formato CLG
                formatted_docs = []
                sources = []
                
                for doc in documents:
                    formatted_doc = {
                        \"id\": doc.get('id', ''),\n                        \"title\": doc.get('title', 'Documento'),\n                        \"content_preview\": doc.get('content', '')[:300] + \"...\",\n                        \"score\": doc.get('score', 0.0),\n                        \"source\": doc.get('source', 'CLG'),\n                        \"date\": doc.get('date', ''),\n                        \"type\": doc.get('metadata', {}).get('type', 'document')\n                    }\n                    formatted_docs.append(formatted_doc)\n                    \n                    # Coletar fontes para citação\n                    if doc.get('title') and doc.get('id'):\n                        sources.append(f\"{doc['title']} (ID: {doc['id']})\")\n                \n                # Resposta estruturada CLG\n                summary = f\"Encontrados {len(formatted_docs)} documentos no sistema CLG\"\n                if sources:\n                    summary += f\"\\n\\n**Fontes:** {'; '.join(sources[:5])}\"\n                \n                return {\n                    'response_type': 'clg_search_results',\n                    'documents_found': len(formatted_docs),\n                    'documents': formatted_docs,\n                    'summary': summary,\n                    'sources': sources,\n                    'confidence': 0.9 if formatted_docs else 0.3,\n                    'data_source': 'CLG RAG System'\n                }\n            else:\n                # CLG falhou\n                return {\n                    'response_type': 'clg_search_error',\n                    'documents_found': 0,\n                    'documents': [],\n                    'summary': f\"Busca no sistema CLG não retornou resultados para: {query}\",\n                    'sources': [],\n                    'confidence': 0.2,\n                    'data_source': 'CLG RAG System (no results)',\n                    'clg_error': clg_result.get('error', 'Unknown error')\n                }\n            \n        except Exception as e:\n            logger.error(f\"Error in CLG local search: {e}\")\n            return {\n                'response_type': 'error',\n                'error': str(e),\n                'confidence': 0.0,\n                'data_source': 'Error'\n            }\n    \n    async def _openai_clg_analysis(self, query: str, metadata: Dict) -> Dict[str, Any]:\n        \"\"\"Análise avançada usando OpenAI com contexto do CLG\"\"\"\n        try:\n            # Buscar contexto relevante no CLG\n            context_docs = await self._get_clg_context_for_openai(query, metadata)\n            \n            # Preparar prompt com contexto CLG\n            system_prompt = self._build_clg_system_prompt()\n            user_prompt = self._build_clg_user_prompt(query, context_docs)\n            \n            # Chamada para OpenAI\n            response = self.openai_client.chat.completions.create(\n                model=self.openai_model,\n                messages=[\n                    {\"role\": \"system\", \"content\": system_prompt},\n                    {\"role\": \"user\", \"content\": user_prompt}\n                ],\n                max_tokens=self.openai_max_tokens,\n                temperature=self.openai_temperature\n            )\n            \n            analysis_result = response.choices[0].message.content\n            \n            # Coletar fontes para citação\n            sources = []\n            for doc in context_docs:\n                if doc.get('title') and doc.get('id'):\n                    sources.append(f\"{doc['title']} (ID: {doc['id']})\")\n            \n            return {\n                'response_type': 'clg_ai_analysis',\n                'analysis': analysis_result,\n                'context_documents': len(context_docs),\n                'sources': sources,\n                'model_used': self.openai_model,\n                'tokens_used': response.usage.total_tokens if response.usage else 0,\n                'confidence': 0.95,\n                'data_source': 'CLG + OpenAI'\n            }\n            \n        except Exception as e:\n            logger.error(f\"Error in CLG OpenAI analysis: {e}\")\n            # Fallback para busca local CLG\n            logger.info(\"Falling back to CLG local search due to OpenAI error\")\n            return await self._local_clg_search(query, metadata)\n    \n    async def _get_clg_context_for_openai(self, query: str, metadata: Dict) -> List[Dict]:\n        \"\"\"Busca documentos relevantes no CLG para contexto OpenAI\"\"\"\n        try:\n            tenant = metadata.get('tenant', self.tenant_default)\n            \n            # Buscar contexto via CLG\n            clg_result = self.clg_client.rag_search(\n                query=query,\n                tenant=tenant,\n                top_k=self.ctx_docs_max,\n                min_score=0.6\n            )\n            \n            context_docs = []\n            \n            if clg_result.get('success', False) and clg_result.get('documents'):\n                for doc in clg_result['documents']:\n                    context_docs.append({\n                        'text': doc.get('content', '')[:800],  # Limite para tokens\n                        'title': doc.get('title', 'Documento CLG'),\n                        'source': f\"CLG - {doc.get('source', 'Sistema')}\",\n                        'score': doc.get('score', 0.0),\n                        'date': doc.get('date', ''),\n                        'id': doc.get('id', '')\n                    })\n            \n            return context_docs\n            \n        except Exception as e:\n            logger.error(f\"Error getting CLG context: {e}\")\n            return []\n    \n    def _build_clg_system_prompt(self) -> str:\n        \"\"\"Constrói o prompt do sistema para OpenAI conforme especificação CLG\"\"\"\n        return '''Você é o Robô do CLG (Ciclo Lógico), um assistente especializado em análise de dados agrícolas e commodities.\n\nSUA IDENTIDADE:\n- Fale sempre em português do Brasil, de forma objetiva e clara\n- Responda para pessoas leigas (Luiz e Cadu) sem jargão técnico\n- Use exemplos práticos quando possível\n- Seja direto e conciso\n\nSUA FUNÇÃO:\n- Analisar dados do sistema CLG\n- Fornecer insights baseados nos documentos fornecidos\n- Identificar tendências e padrões quando possível\n- Fazer recomendações práticas quando solicitado\n- Ser honesto sobre limitações dos dados disponíveis\n\nFORMATO DE RESPOSTA:\n- Comece com um resumo executivo breve\n- Liste pontos principais identificados\n- Termine com \"Fontes:\" citando os IDs dos documentos\n- Se não houver dados suficientes, seja claro sobre isso\n- Evite paredes de texto - use seções curtas\n\nREGRAS:\n- SEMPRE cite as fontes usando os IDs dos documentos\n- Nunca invente informações que não estão nos documentos\n- Se os dados forem limitados, seja honesto sobre isso'''    \n    \n    def _build_clg_user_prompt(self, query: str, context_docs: List[Dict]) -> str:\n        \"\"\"Constrói o prompt do usuário com contexto CLG\"\"\"\n        prompt = f\"PERGUNTA DO USUÁRIO: {query}\\n\\n\"\n        \n        if context_docs:\n            prompt += \"DOCUMENTOS DO SISTEMA CLG:\\n\\n\"\n            \n            for i, doc in enumerate(context_docs, 1):\n                prompt += f\"DOCUMENTO {i}:\\n\"\n                prompt += f\"Título: {doc.get('title', 'Sem título')}\\n\"\n                prompt += f\"Fonte: {doc.get('source', 'CLG')}\\n\"\n                prompt += f\"Relevância: {doc.get('score', 0):.2f}\\n\"\n                if doc.get('date'):\n                    prompt += f\"Data: {doc['date']}\\n\"\n                if doc.get('id'):\n                    prompt += f\"ID: {doc['id']}\\n\"\n                prompt += f\"Conteúdo: {doc.get('text', '')[:600]}\\n\\n\"\n        else:\n            prompt += \"CONTEXTO: Nenhum documento específico encontrado no sistema CLG para esta consulta.\\n\\n\"\n        \n        prompt += \"\"\"INSTRUÇÕES:\n- Analise a pergunta usando APENAS as informações dos documentos fornecidos\n- Responda em português brasileiro, de forma clara e objetiva\n- Cite as fontes usando os IDs dos documentos\n- Se não houver informações suficientes, seja claro sobre isso\n- Forneça insights práticos quando possível\"\"\"\n        \n        return prompt\n    \n    # Métodos de utilidade CLG\n    def get_auth_info(self) -> Dict[str, Any]:\n        \"\"\"Obtém informações de autenticação CLG\"\"\"\n        if self.clg_client:\n            return self.clg_client.get_auth_info()\n        return {\"success\": False, \"error\": \"CLG client not available\"}\n    \n    def list_documents(self, tenant: str = None, all_tenants: bool = False) -> Dict[str, Any]:\n        \"\"\"Lista documentos do CLG\"\"\"\n        if self.clg_client:\n            return self.clg_client.list_documents(tenant or self.tenant_default, all_tenants)\n        return {\"success\": False, \"error\": \"CLG client not available\"}\n    \n    def get_clg_status(self) -> Dict[str, Any]:\n        \"\"\"Obtém status do sistema CLG\"\"\"\n        if self.clg_client:\n            return self.clg_client.get_system_status()\n        return {\"success\": False, \"error\": \"CLG client not available\"}"