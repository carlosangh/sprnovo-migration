#!/usr/bin/env python3
"""
CLGClient - Cliente para integração com a API do Ciclo Lógico
Implementa os endpoints do sistema CLG conforme especificação
"""

import os
import logging
import requests
import json
from typing import List, Dict, Any, Optional, Tuple
from datetime import datetime

logger = logging.getLogger(__name__)

class CLGClient:
    """Cliente para comunicação com a API CLG"""
    
    def __init__(self, base_url: str = "http://localhost:8000", api_version: str = "v1"):
        self.base_url = base_url.rstrip('/')
        self.api_version = api_version
        self.api_base = f"{self.base_url}/api/{api_version}"
        self.session = requests.Session()
        self.session.headers.update({
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        })
        
        # Configurações padrão CLG
        self.tenant_default = "tenant_luiz"
        self.top_k = 8
        self.min_score = 0.65
        self.ctx_docs_max = 5
        
    def _make_request(self, method: str, endpoint: str, **kwargs) -> Dict[str, Any]:
        """Faz requisição HTTP para a API CLG"""
        url = f"{self.api_base}{endpoint}"
        
        try:
            response = self.session.request(method, url, **kwargs)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            logger.error(f"CLG API request failed: {e}")
            return {"error": str(e), "success": False}
    
    def get_auth_info(self) -> Dict[str, Any]:
        """Obtém informações de autenticação e usuário atual"""
        try:
            result = self._make_request("GET", "/auth/me")
            if "error" not in result:
                return {
                    "success": True,
                    "user": result.get("user", {}),
                    "role": result.get("role", "user"),
                    "tenant": result.get("tenant", self.tenant_default),
                    "is_admin": result.get("role") == "admin"
                }
            else:
                # Se não autenticado, usar defaults
                return {
                    "success": True,
                    "user": {"name": "Anonymous"},
                    "role": "user", 
                    "tenant": self.tenant_default,
                    "is_admin": False
                }
        except Exception as e:
            logger.error(f"Error getting auth info: {e}")
            return {
                "success": False,
                "error": str(e),
                "tenant": self.tenant_default,
                "is_admin": False
            }
    
    def rag_search(self, query: str, tenant: str = None, all_tenants: bool = False, 
                   top_k: int = None, min_score: float = None) -> Dict[str, Any]:
        """Busca semântica via RAG local"""
        try:
            # Usar defaults se não especificado
            tenant = tenant or self.tenant_default
            top_k = top_k or self.top_k
            min_score = min_score or self.min_score
            
            # Preparar parâmetros
            params = {
                "q": query,
                "k": top_k,
                "tenant": tenant
            }
            
            if all_tenants:
                params["all"] = "1"
            
            # Tentar diferentes endpoints possíveis
            endpoints_to_try = [
                "/rag/local/search",
                "/chat/embeddings", 
                "/data/search"
            ]
            
            for endpoint in endpoints_to_try:
                try:
                    result = self._make_request("GET", endpoint, params=params)
                    if "error" not in result:
                        # Normalizar resposta
                        return self._normalize_search_result(result, query)
                except Exception as e:
                    logger.debug(f"Endpoint {endpoint} failed: {e}")
                    continue
            
            # Se todos falharam, retornar erro
            return {
                "success": False,
                "error": "RAG search endpoints not available",
                "query": query,
                "documents": [],
                "total_found": 0
            }
            
        except Exception as e:
            logger.error(f"Error in RAG search: {e}")
            return {
                "success": False,
                "error": str(e),
                "query": query,
                "documents": [],
                "total_found": 0
            }
    
    def _normalize_search_result(self, raw_result: Dict, query: str) -> Dict[str, Any]:
        """Normaliza resultado de busca para formato padrão"""
        try:
            # Extrair documentos do resultado
            documents = []
            
            # Diferentes formatos possíveis de resposta
            if "results" in raw_result:
                docs_data = raw_result["results"]
            elif "documents" in raw_result:
                docs_data = raw_result["documents"]
            elif "data" in raw_result:
                docs_data = raw_result["data"]
            else:
                docs_data = raw_result if isinstance(raw_result, list) else []
            
            # Normalizar cada documento
            for doc in docs_data:
                if isinstance(doc, dict):
                    normalized_doc = {
                        "id": doc.get("id", doc.get("document_id", "")),
                        "title": doc.get("title", doc.get("file_name", doc.get("name", "Documento"))),
                        "content": doc.get("content", doc.get("text", doc.get("excerpt", "")))[:400],
                        "score": doc.get("score", doc.get("relevance", doc.get("similarity", 0.0))),
                        "source": doc.get("source", doc.get("type", "CLG")),
                        "date": doc.get("date", doc.get("created_at", doc.get("timestamp", ""))),
                        "metadata": doc.get("metadata", {})
                    }
                    documents.append(normalized_doc)
            
            return {
                "success": True,
                "query": query,
                "documents": documents,
                "total_found": len(documents),
                "processing_time": raw_result.get("processing_time", 0),
                "raw_result": raw_result  # Para debug
            }
            
        except Exception as e:
            logger.error(f"Error normalizing search result: {e}")
            return {
                "success": False,
                "error": f"Result normalization failed: {e}",
                "query": query,
                "documents": [],
                "total_found": 0
            }
    
    def list_documents(self, tenant: str = None, all_tenants: bool = False, 
                      limit: int = 50) -> Dict[str, Any]:
        """Lista documentos indexados"""
        try:
            tenant = tenant or self.tenant_default
            
            params = {
                "tenant": tenant,
                "limit": limit
            }
            
            if all_tenants:
                params["all"] = "1"
            
            # Tentar diferentes endpoints
            endpoints_to_try = [
                "/docs/list",
                "/documents",
                "/data/documents"
            ]
            
            for endpoint in endpoints_to_try:
                try:
                    result = self._make_request("GET", endpoint, params=params)
                    if "error" not in result:
                        return self._normalize_document_list(result)
                except Exception as e:
                    logger.debug(f"Endpoint {endpoint} failed: {e}")
                    continue
            
            return {
                "success": False,
                "error": "Document list endpoints not available",
                "documents": [],
                "total_count": 0
            }
            
        except Exception as e:
            logger.error(f"Error listing documents: {e}")
            return {
                "success": False,
                "error": str(e),
                "documents": [],
                "total_count": 0
            }
    
    def _normalize_document_list(self, raw_result: Dict) -> Dict[str, Any]:
        """Normaliza lista de documentos"""
        try:
            documents = []
            
            # Extrair lista de documentos
            if "documents" in raw_result:
                docs_data = raw_result["documents"]
            elif "items" in raw_result:
                docs_data = raw_result["items"]
            elif "data" in raw_result:
                docs_data = raw_result["data"]
            else:
                docs_data = raw_result if isinstance(raw_result, list) else []
            
            # Normalizar cada documento
            for doc in docs_data:
                if isinstance(doc, dict):
                    normalized_doc = {
                        "id": doc.get("id", ""),
                        "title": doc.get("title", doc.get("name", doc.get("filename", ""))),
                        "type": doc.get("type", doc.get("document_type", "document")),
                        "size": doc.get("size", doc.get("file_size", 0)),
                        "created_at": doc.get("created_at", doc.get("uploaded_at", "")),
                        "tenant": doc.get("tenant", ""),
                        "status": doc.get("status", "indexed"),
                        "metadata": doc.get("metadata", {})
                    }
                    documents.append(normalized_doc)
            
            return {
                "success": True,
                "documents": documents,
                "total_count": raw_result.get("total", raw_result.get("count", len(documents))),
                "raw_result": raw_result
            }
            
        except Exception as e:
            logger.error(f"Error normalizing document list: {e}")
            return {
                "success": False,
                "error": f"Document list normalization failed: {e}",
                "documents": [],
                "total_count": 0
            }
    
    def ingest_text(self, texts: List[str], tenant: str = None) -> Dict[str, Any]:
        """Ingere textos simples no sistema"""
        try:
            tenant = tenant or self.tenant_default
            
            payload = {
                "texts": texts,
                "tenant": tenant
            }
            
            result = self._make_request("POST", "/rag/local/ingest", json=payload)
            return result
            
        except Exception as e:
            logger.error(f"Error ingesting texts: {e}")
            return {"success": False, "error": str(e)}
    
    def upload_document(self, file_path: str, tenant: str = None) -> Dict[str, Any]:
        """Upload e indexação de documento"""
        try:
            tenant = tenant or self.tenant_default
            
            # Para upload de arquivo, usar multipart
            with open(file_path, 'rb') as f:
                files = {'files': f}
                data = {'tenant': tenant}
                
                # Remove content-type para multipart
                headers = {k: v for k, v in self.session.headers.items() 
                          if k.lower() != 'content-type'}
                
                url = f"{self.api_base}/docs/upload"
                response = requests.post(url, files=files, data=data, headers=headers)
                response.raise_for_status()
                
                return response.json()
                
        except Exception as e:
            logger.error(f"Error uploading document: {e}")
            return {"success": False, "error": str(e)}
    
    def delete_document(self, doc_id: str) -> Dict[str, Any]:
        """Remove documento pelo ID"""
        try:
            params = {"id": doc_id}
            result = self._make_request("DELETE", "/docs/delete", params=params)
            return result
            
        except Exception as e:
            logger.error(f"Error deleting document: {e}")
            return {"success": False, "error": str(e)}
    
    def get_system_status(self) -> Dict[str, Any]:
        """Obtém status do sistema CLG"""
        try:
            # Testar diferentes endpoints de status
            status_endpoints = [
                "/health",
                "/status", 
                "/system/status"
            ]
            
            for endpoint in status_endpoints:
                try:
                    result = self._make_request("GET", endpoint)
                    if "error" not in result:
                        return {
                            "success": True,
                            "clg_status": result,
                            "api_base": self.api_base,
                            "timestamp": datetime.now().isoformat()
                        }
                except:
                    continue
            
            # Se nenhum endpoint de status funcionar, testar conectividade básica
            root_result = self._make_request("GET", "/")
            if "error" not in root_result:
                return {
                    "success": True,
                    "clg_status": {"status": "operational", "api_info": root_result},
                    "api_base": self.api_base,
                    "timestamp": datetime.now().isoformat()
                }
            
            return {"success": False, "error": "CLG API not accessible"}
            
        except Exception as e:
            logger.error(f"Error getting system status: {e}")
            return {"success": False, "error": str(e)}
    
    def test_connection(self) -> bool:
        """Testa conectividade básica com CLG"""
        try:
            result = self._make_request("GET", "/")
            return "error" not in result
        except:
            return False