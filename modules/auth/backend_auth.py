"""
SPR - Sistema Preditivo Royal
Backend com Autenticação - Versão Emergencial Simples
"""

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from datetime import datetime
import uvicorn
import hashlib
from pydantic import BaseModel
from typing import Optional
import secrets

# Configurações simples
SIMPLE_SECRET = "emergency-token-2025"

app = FastAPI(
    title="SPR - Sistema Preditivo Royal (Com Autenticação)",
    description="APIs para análise de commodities agrícolas com autenticação",
    version="1.2.0-emergency"
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://127.0.0.1:3000", "http://161.35.193.215"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Modelos simples
class LoginRequest(BaseModel):
    email: Optional[str] = None
    username: Optional[str] = None
    password: str

# Usuários válidos (senha: Adega001*)
VALID_USERS = {
    "carlos@royalnegociosagricolas.com.br": "Adega001*",
    "admin": "Adega001*"
}

def create_simple_token(identifier: str) -> str:
    """Criar token simples"""
    timestamp = str(int(datetime.utcnow().timestamp()))
    token_data = f"{identifier}:{timestamp}:{SIMPLE_SECRET}"
    return hashlib.sha256(token_data.encode()).hexdigest()

def verify_credentials(identifier: str, password: str) -> bool:
    """Verificar credenciais"""
    return identifier in VALID_USERS and VALID_USERS[identifier] == password

# ============= ENDPOINTS DE AUTENTICAÇÃO =============

@app.post("/api/auth/login")
async def login(request: LoginRequest):
    """Endpoint de login"""
    
    # Usar email ou username
    identifier = request.email or request.username
    if not identifier or not request.password:
        raise HTTPException(
            status_code=400, 
            detail={"error": "Email/username and password required"}
        )
    
    # Verificar credenciais
    if not verify_credentials(identifier, request.password):
        print(f"❌ Failed login attempt for: {identifier}")
        raise HTTPException(
            status_code=401,
            detail={"error": "Invalid credentials"}
        )
    
    # Criar token
    token = create_simple_token(identifier)
    expires_at = datetime.utcnow().isoformat()
    
    print(f"✅ User {identifier} logged in successfully")
    
    return {
        "success": True,
        "token": token,
        "user": {
            "username": identifier,
            "email": identifier if "@" in identifier else f"{identifier}@royalnegociosagricolas.com.br",
            "roles": ["admin", "user"]
        },
        "expires_at": expires_at
    }

@app.post("/api/auth/refresh")
async def refresh_token():
    """Renovar token (simplificado)"""
    return {
        "success": True,
        "message": "Token refresh não implementado na versão emergencial"
    }

@app.get("/api/auth/me")
async def get_current_user():
    """Obter dados do usuário atual (simplificado)"""
    return {
        "success": True,
        "message": "User info não implementado na versão emergencial"
    }

# ============= ENDPOINTS PÚBLICOS =============

@app.get("/")
async def root():
    """Endpoint raiz"""
    return {
        "message": "🌾 SPR - Sistema Preditivo Royal (Com Autenticação)",
        "version": "1.2.0-emergency",
        "status": "✅ ONLINE",
        "auth_endpoints": [
            "POST /api/auth/login",
            "POST /api/auth/refresh", 
            "GET /api/auth/me"
        ],
        "timestamp": datetime.utcnow().isoformat()
    }

@app.get("/health")
async def health_check():
    """Health check"""
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "auth": "enabled"
    }

@app.get("/api/status")
async def api_status():
    """Status da API"""
    return {
        "status": "✅ ONLINE",
        "auth": "✅ ENABLED", 
        "version": "1.2.0-emergency",
        "timestamp": datetime.utcnow().isoformat()
    }

# ============= ENDPOINTS PROTEGIDOS =============

@app.get("/api/protected/test")
async def protected_test():
    """Endpoint de teste (simplificado)"""
    return {
        "message": "🔒 Acesso liberado (versão emergencial)",
        "timestamp": datetime.utcnow().isoformat()
    }

if __name__ == "__main__":
    print("🚀 Iniciando SPR Backend com Autenticação na porta 3002...")
    uvicorn.run(app, host="0.0.0.0", port=3002, reload=False)