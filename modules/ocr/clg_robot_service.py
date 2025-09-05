#!/usr/bin/env python3
"""
CLG Robot Service - Serviço do Robô CLG
Endpoint unificado compatível com especificação CLG
"""

import os
import time
import logging
from typing import Dict, Any, Optional, List
from datetime import datetime

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from clg_smart_agent import CLGSmartAgent
from ocr_service_enhanced import ProcessingTask, ProcessingStrategy

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# FastAPI App
app = FastAPI(
    title="CLG Robot Service",
    description="Robô do CLG - Sistema Inteligente de Análise",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global CLG Robot
clg_robot = None

# Pydantic Models
class CLGQuery(BaseModel):
    query: str
    tenant: str = "tenant_luiz"
    intent: str = "auto"  # auto, local, openai
    all_tenants: bool = False
    limit: int = 8
    min_score: float = 0.65

class CLGResponse(BaseModel):
    success: bool
    query: str
    strategy_used: str
    response_type: str
    tenant: str
    processing_time: float
    confidence: float
    
    # Para respostas de busca local
    documents_found: Optional[int] = None
    documents: Optional[List[Dict[str, Any]]] = None
    summary: Optional[str] = None
    sources: Optional[List[str]] = None
    
    # Para análises OpenAI
    analysis: Optional[str] = None
    context_documents: Optional[int] = None
    model_used: Optional[str] = None
    tokens_used: Optional[int] = None
    
    # Dados adicionais CLG
    data_source: Optional[str] = None
    error: Optional[str] = None

class CLGStatus(BaseModel):
    robot_status: str
    clg_connection: bool
    openai_available: bool
    processed_count: int
    tenant_default: str
    timestamp: str

class CLGDocumentList(BaseModel):
    success: bool
    tenant: str
    documents: List[Dict[str, Any]]
    total_count: int
    timestamp: str

@app.on_event("startup")
async def startup_event():
    """Initialize CLG Robot"""
    global clg_robot
    try:
        clg_robot = CLGSmartAgent("clg_robot_main")
        logger.info("CLG Robot initialized successfully")
    except Exception as e:
        logger.error(f"Error initializing CLG Robot: {e}")
        clg_robot = None

@app.get("/")
async def root():
    """Root endpoint - CLG Robot info"""
    return {
        "service": "CLG Robot",
        "version": "1.0.0",
        "description": "Robô do CLG - Sistema Inteligente de Análise",
        "status": "operational" if clg_robot else "error",
        "endpoints": {
            "chat": "/robot/ask",
            "status": "/robot/status", 
            "documents": "/robot/documents",
            "commands": "/robot/commands"
        },
        "timestamp": datetime.now().isoformat()
    }

@app.post("/robot/ask", response_model=CLGResponse)
async def ask_robot(request: CLGQuery):
    """Endpoint principal do Robô CLG - pergunta unificada"""
    try:
        if not clg_robot:
            raise HTTPException(status_code=500, detail="CLG Robot not available")
        
        # Verificar autenticação CLG (se necessário)
        auth_info = clg_robot.get_auth_info()
        tenant = request.tenant
        
        # Se admin, permitir all_tenants
        if auth_info.get('is_admin', False) and request.all_tenants:
            logger.info(f"Admin access - searching all tenants")
        
        # Criar task para o CLG Robot
        task_id = f"clg_task_{int(time.time() * 1000)}"
        task = ProcessingTask(
            task_id=task_id,
            file_path="",  # Não usado para análise
            strategy=ProcessingStrategy.BALANCED,
            metadata={
                'query': request.query,
                'intent': request.intent,
                'tenant': tenant,
                'all_tenants': request.all_tenants,
                'limit': request.limit,
                'min_score': request.min_score
            }
        )
        
        # Processar com CLG Robot
        result = await clg_robot.process(task)
        
        if result.success:
            response_data = result.data
            
            return CLGResponse(
                success=True,
                query=request.query,
                strategy_used=response_data.get('strategy_used', 'unknown'),
                response_type=response_data.get('response_type', 'unknown'),
                tenant=tenant,
                processing_time=result.processing_time,
                confidence=result.confidence,
                
                # Campos condicionais baseados no tipo
                documents_found=response_data.get('documents_found'),
                documents=response_data.get('documents'),
                summary=response_data.get('summary'),
                sources=response_data.get('sources'),
                
                analysis=response_data.get('analysis'),
                context_documents=response_data.get('context_documents'),
                model_used=response_data.get('model_used'),
                tokens_used=response_data.get('tokens_used'),
                
                data_source=response_data.get('data_source')
            )
        else:
            return CLGResponse(
                success=False,
                query=request.query,
                strategy_used=result.data.get('strategy_used', 'error'),
                response_type='error',
                tenant=tenant,
                processing_time=result.processing_time,
                confidence=0.0,
                error=result.error
            )
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"CLG Robot error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/robot/status", response_model=CLGStatus)
async def get_robot_status():
    """Status do Robô CLG"""
    try:
        if not clg_robot:
            return CLGStatus(
                robot_status="error",
                clg_connection=False,
                openai_available=False,
                processed_count=0,
                tenant_default="tenant_luiz",
                timestamp=datetime.now().isoformat()
            )
        
        # Verificar conexões
        clg_status = clg_robot.get_clg_status()
        clg_connection = clg_status.get('success', False)
        
        # Testar OpenAI
        openai_available = clg_robot.openai_client is not None
        
        return CLGStatus(
            robot_status="operational",
            clg_connection=clg_connection,
            openai_available=openai_available,
            processed_count=clg_robot.processed_count,
            tenant_default=clg_robot.tenant_default,
            timestamp=datetime.now().isoformat()
        )
        
    except Exception as e:
        logger.error(f"Status check error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/robot/documents", response_model=CLGDocumentList)
async def list_robot_documents(
    tenant: str = Query(default="tenant_luiz"),
    all_tenants: bool = Query(default=False),
    limit: int = Query(default=50)
):
    """Listar documentos do CLG"""
    try:
        if not clg_robot:
            raise HTTPException(status_code=500, detail="CLG Robot not available")
        
        # Verificar permissões para all_tenants
        if all_tenants:
            auth_info = clg_robot.get_auth_info()
            if not auth_info.get('is_admin', False):
                raise HTTPException(status_code=403, detail="Admin access required for all tenants")
        
        # Listar documentos
        doc_result = clg_robot.list_documents(tenant, all_tenants)
        
        if doc_result.get('success', False):
            return CLGDocumentList(
                success=True,
                tenant=tenant,
                documents=doc_result.get('documents', []),
                total_count=doc_result.get('total_count', 0),
                timestamp=datetime.now().isoformat()
            )
        else:
            return CLGDocumentList(
                success=False,
                tenant=tenant,
                documents=[],
                total_count=0,
                timestamp=datetime.now().isoformat()
            )
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Document list error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/robot/commands")
async def get_robot_commands():
    """Comandos especiais do Robô CLG"""
    return {
        "available_commands": {
            "STATUS": "Retorna painel do sistema",
            "LISTAR DOCUMENTOS": "Lista documentos do tenant atual",
            "BUSCAR {termo}": "Busca semântica no CLG",
            "LIMPAR CONTEXTO": "Limpa histórico da conversa"
        },
        "command_examples": [
            "STATUS",
            "BUSCAR preços do milho",
            "LISTAR DOCUMENTOS",
            "analise tendências de soja",
            "busque relatórios sobre trigo"
        ],
        "usage_tips": [
            "Use 'buscar' para encontrar documentos específicos",
            "Use 'analisar' para insights complexos com OpenAI",
            "O robô decide automaticamente local vs OpenAI",
            "Sempre cita as fontes dos documentos"
        ]
    }

@app.post("/robot/command")
async def execute_robot_command(command: str):
    """Executa comandos especiais do Robô CLG"""
    try:
        if not clg_robot:
            raise HTTPException(status_code=500, detail="CLG Robot not available")
        
        command_upper = command.upper().strip()
        
        if command_upper == "STATUS":
            # Retornar status do sistema
            status = await get_robot_status()
            clg_status = clg_robot.get_clg_status()
            
            return {
                "command": "STATUS",
                "result": {
                    "robot_status": status.robot_status,
                    "clg_connection": status.clg_connection,
                    "openai_available": status.openai_available,
                    "processed_queries": status.processed_count,
                    "clg_system": clg_status.get('clg_status', {})
                }
            }
        
        elif command_upper == "LISTAR DOCUMENTOS":
            # Listar documentos
            docs = await list_robot_documents()
            return {
                "command": "LISTAR DOCUMENTOS",
                "result": {
                    "total_documents": docs.total_count,
                    "tenant": docs.tenant,
                    "documents": docs.documents[:10]  # Primeiros 10
                }
            }
        
        elif command_upper.startswith("BUSCAR "):
            # Busca
            search_term = command[7:].strip()
            query_request = CLGQuery(query=search_term, intent="local")
            result = await ask_robot(query_request)
            
            return {
                "command": f"BUSCAR {search_term}",
                "result": result.dict()
            }
        
        elif command_upper == "LIMPAR CONTEXTO":
            # Simular limpeza de contexto
            return {
                "command": "LIMPAR CONTEXTO",
                "result": {
                    "status": "Contexto limpo",
                    "tenant": clg_robot.tenant_default,
                    "timestamp": datetime.now().isoformat()
                }
            }
        
        else:
            # Comando desconhecido - tratar como query normal
            query_request = CLGQuery(query=command)
            result = await ask_robot(query_request)
            
            return {
                "command": f"QUERY: {command}",
                "result": result.dict()
            }
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Command execution error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# Health check
@app.get("/health")
async def health_check():
    """Health check endpoint"""
    try:
        robot_ok = clg_robot is not None
        clg_ok = robot_ok and clg_robot.clg_client.test_connection() if robot_ok else False
        
        return {
            "status": "healthy" if robot_ok else "unhealthy",
            "components": {
                "clg_robot": "ok" if robot_ok else "error",
                "clg_connection": "ok" if clg_ok else "error",
                "openai": "ok" if (robot_ok and clg_robot.openai_client) else "error"
            },
            "timestamp": datetime.now().isoformat()
        }
    except Exception as e:
        return {
            "status": "unhealthy",
            "error": str(e),
            "timestamp": datetime.now().isoformat()
        }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8004)