#!/usr/bin/env python3
"""
SmartAnalysisAgent - Agent híbrido que decide automaticamente
entre análise local vs OpenAI baseado na complexidade da query
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

# Vector Search
from qdrant_client import QdrantClient
from sentence_transformers import SentenceTransformer

# Imports do sistema OCR
from ocr_service_enhanced import BaseAgent, AgentType, ProcessingTask, AgentResult

logger = logging.getLogger(__name__)

class SmartAnalysisAgent(BaseAgent):
    """Agent inteligente que decide automaticamente entre análise local vs OpenAI"""
    
    def __init__(self, agent_id: str):
        super().__init__(agent_id, AgentType.SMART_ANALYST)
        self.openai_client = None
        self.embedding_model = None
        self.qdrant_client = None
        self._initialize_services()
        
        # Padrões para classificação de intenção
        self.local_patterns = [
            # Busca simples
            r'busca|busque|encontre|liste|mostre|exiba',
            r'documentos? sobre|arquivos? de|relatórios? de',
            r'últimos? documentos?|documentos? recentes?',
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
            
            # Local services
            self.embedding_model = SentenceTransformer('sentence-transformers/all-MiniLM-L6-v2')
            self.qdrant_client = QdrantClient(host="localhost", port=6333)
            
            logger.info(f"SmartAnalysisAgent {self.agent_id} initialized successfully")
            
        except Exception as e:
            logger.error(f"Error initializing SmartAnalysisAgent: {e}")
    
    async def process(self, task: ProcessingTask) -> AgentResult:
        start_time = time.time()
        self.is_active = True
        self.last_activity = datetime.now()
        
        try:
            query = task.metadata.get('query', '')
            user_intent = task.metadata.get('intent', 'auto')
            
            if not query:
                raise ValueError("No query provided for analysis")
            
            # Decisão automática da estratégia
            if user_intent == 'auto':
                strategy = self._classify_intent(query)
            else:
                strategy = user_intent
            
            logger.info(f"Query: '{query}' -> Strategy: {strategy}")
            
            if strategy == 'local':
                result_data = await self._local_analysis(query, task.metadata)
            else:
                result_data = await self._openai_analysis(query, task.metadata)
            
            result = AgentResult(
                agent_id=self.agent_id,
                agent_type=self.agent_type,
                task_id=task.task_id,
                success=True,
                data={
                    'strategy_used': strategy,
                    'query': query,
                    **result_data
                },
                processing_time=time.time() - start_time,
                confidence=result_data.get('confidence', 0.8)
            )
            
        except Exception as e:
            logger.error(f"SmartAnalysisAgent {self.agent_id} error: {e}")
            result = AgentResult(
                agent_id=self.agent_id,
                agent_type=self.agent_type,
                task_id=task.task_id,
                success=False,
                data={'strategy_used': 'error'},
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
            if keyword in query_lower:
                openai_score += 2
        
        # Decide baseado na pontuação
        if openai_score > local_score:
            return 'openai'
        else:
            return 'local'
    
    async def _local_analysis(self, query: str, metadata: Dict) -> Dict[str, Any]:
        """Análise local usando busca no Qdrant"""
        try:
            # Parâmetros da busca
            limit = metadata.get('limit', 10)
            min_score = metadata.get('min_score', 0.7)
            
            # Criar embedding da query
            query_embedding = self.embedding_model.encode(query).tolist()
            
            # Buscar no Qdrant
            search_result = self.qdrant_client.search(
                collection_name="commodity_documents_enhanced",
                query_vector=query_embedding,
                limit=limit,
                score_threshold=min_score
            )
            
            # Formatar resultados
            documents = []
            for hit in search_result:
                payload = hit.payload
                documents.append({
                    "score": hit.score,
                    "file_name": payload.get("file_name", ""),
                    "document_type": payload.get("document_type", "unknown"),
                    "text_preview": payload.get("text", "")[:200] + "...",
                    "keywords": payload.get("keywords", [])[:5],
                    "processed_at": payload.get("processed_at", "")
                })
            
            # Resposta estruturada
            return {
                'response_type': 'search_results',
                'documents_found': len(documents),
                'documents': documents,
                'summary': f"Encontrados {len(documents)} documentos relacionados a: {query}",
                'confidence': 0.9 if documents else 0.3
            }
            
        except Exception as e:
            logger.error(f"Error in local analysis: {e}")
            return {
                'response_type': 'error',
                'error': str(e),
                'confidence': 0.0
            }
    
    async def _openai_analysis(self, query: str, metadata: Dict) -> Dict[str, Any]:
        """Análise avançada usando OpenAI com contexto do banco"""
        try:
            # Primeiro, buscar contexto relevante no banco
            context_docs = await self._get_context_for_openai(query, metadata.get('context_limit', 5))
            
            # Preparar prompt com contexto
            system_prompt = self._build_system_prompt()
            user_prompt = self._build_user_prompt(query, context_docs)
            
            # Chamada para OpenAI
            response = self.openai_client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt}
                ],
                max_tokens=1500,
                temperature=0.7
            )
            
            analysis_result = response.choices[0].message.content
            
            return {
                'response_type': 'ai_analysis',
                'analysis': analysis_result,
                'context_documents': len(context_docs),
                'model_used': 'gpt-4o-mini',
                'tokens_used': response.usage.total_tokens if response.usage else 0,
                'confidence': 0.95
            }
            
        except Exception as e:
            logger.error(f"Error in OpenAI analysis: {e}")
            # Fallback para análise local em caso de erro
            logger.info("Falling back to local analysis due to OpenAI error")
            return await self._local_analysis(query, metadata)
    
    async def _get_context_for_openai(self, query: str, limit: int = 5) -> List[Dict]:
        """Busca documentos relevantes para fornecer contexto ao OpenAI"""
        try:
            # Buscar documentos mais relevantes
            query_embedding = self.embedding_model.encode(query).tolist()
            
            search_result = self.qdrant_client.search(
                collection_name="commodity_documents_enhanced",
                query_vector=query_embedding,
                limit=limit,
                score_threshold=0.6
            )
            
            context_docs = []
            for hit in search_result:
                payload = hit.payload
                context_docs.append({
                    'text': payload.get('text', '')[:800],  # Limite texto para não estourar tokens
                    'file_name': payload.get('file_name', 'Unknown'),
                    'document_type': payload.get('document_type', 'unknown'),
                    'score': hit.score,
                    'keywords': payload.get('keywords', [])[:3]
                })
            
            return context_docs
            
        except Exception as e:
            logger.error(f"Error getting context: {e}")
            return []
    
    def _build_system_prompt(self) -> str:
        """Constrói o prompt do sistema para OpenAI"""
        return '''Você é um especialista em análise de documentos de commodities e mercado agrícola.

Sua função é analisar informações de documentos processados via OCR e fornecer insights valiosos.

Você recebe:
1. Uma pergunta específica do usuário
2. Contexto de documentos relevantes do banco de dados

Deve responder:
- De forma clara e objetiva
- Com insights baseados nos dados fornecidos
- Identificando tendências e padrões quando possível
- Fazendo recomendações práticas quando solicitado
- Sendo honesto sobre limitações dos dados disponíveis

Formato de resposta preferido:
- Resumo executivo breve
- Pontos principais identificados
- Conclusões ou recomendações (quando aplicável)'''
    
    def _build_user_prompt(self, query: str, context_docs: List[Dict]) -> str:
        """Constrói o prompt do usuário com contexto"""
        prompt = f"PERGUNTA DO USUÁRIO: {query}\n\n"
        
        if context_docs:
            prompt += "CONTEXTO DOS DOCUMENTOS RELEVANTES:\n\n"
            
            for i, doc in enumerate(context_docs, 1):
                prompt += f"DOCUMENTO {i} ({doc['file_name']} - {doc['document_type']}):\n"
                prompt += f"Relevância: {doc['score']:.2f}\n"
                if doc['keywords']:
                    prompt += f"Palavras-chave: {', '.join(doc['keywords'])}\n"
                prompt += f"Conteúdo: {doc['text'][:600]}...\n\n"
        else:
            prompt += "CONTEXTO: Nenhum documento específico encontrado no banco de dados.\n\n"
        
        prompt += "Por favor, analise a pergunta considerando o contexto fornecido e responda de forma clara e útil."
        
        return prompt