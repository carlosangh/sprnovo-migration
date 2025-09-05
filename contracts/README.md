# Contratos de APIs - Sistema SPR

Este diretório contém todas as especificações OpenAPI 3.0 das APIs do Sistema Preditivo Royal (SPR).

## 📋 Arquivos de Contratos

### 1. [spr-backend-api.yml](./spr-backend-api.yml)
**API Principal Node.js/TypeScript**
- **Portas:** 3001, 3002  
- **Endpoints:** 12 rotas para dados agrícolas, health checks e sistema
- **Funcionalidades:** WASDE, CFTC COT, progresso de culturas, dados de seca
- **Status:** ✅ Totalmente implementado

### 2. [spr-whatsapp-api.yml](./spr-whatsapp-api.yml)
**Integração WhatsApp via WPPConnect**
- **Proxy:** Backend Node.js → WPPConnect (porta 3003)
- **Endpoints:** 7 rotas para QR Code, sessões e monitoramento
- **Funcionalidades:** Geração de token, gerenciamento de sessões, interface web
- **Status:** ✅ Totalmente implementado

### 3. [spr-python-services.yml](./spr-python-services.yml)  
**Serviços Python (FastAPI)**
- **Portas:** 3002 (SPR API), 8000 (Claude Bridge)
- **Endpoints:** 7 rotas para OCR, análise inteligente e bridge Claude
- **Funcionalidades:** Processamento de documentos, análise de commodities, IA
- **Status:** ⚠️ Parcialmente implementado (43% cobertura)

### 4. [spr-auth-api.yml](./spr-auth-api.yml)
**Sistema de Autenticação (Versão Emergencial)**
- **Porta:** 3002 (conflito com outros serviços)
- **Endpoints:** 7 rotas para login, tokens e endpoints protegidos  
- **Funcionalidades:** Login simplificado, tokens SHA256, usuários hardcoded
- **Status:** ⚠️ Versão emergencial (57% funcionalidade completa)

## 🚀 Uso Rápido

### Visualizar Documentação
```bash
# Instalar swagger-ui (se não tiver)
npm install -g swagger-ui-serve

# Servir documentação interativa
swagger-ui-serve spr-backend-api.yml
```

### Exemplos de Requests

#### 1. Health Check do Backend
```bash
curl -X GET "http://localhost:3002/health" \
  -H "Content-Type: application/json"
```

#### 2. Login na API de Autenticação  
```bash
curl -X POST "http://localhost:3002/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "carlos@royalnegociosagricolas.com.br",
    "password": "Adega001*"
  }'
```

#### 3. Gerar Token WhatsApp
```bash
curl -X POST "http://localhost:3002/api/whatsapp/royal-session/SPR_ROYAL_NEGOCIOS_SECURE_TOKEN_2025/generate-token" \
  -H "Content-Type: application/json"
```

#### 4. Consultar Claude AI
```bash
curl -X POST "http://localhost:8000/pulso/claude/ask" \
  -H "Content-Type: application/json" \
  -d '{
    "content": "Qual a previsão para a safra de soja?",
    "context": "agricultural analysis"
  }'
```

#### 5. Dados WASDE (Relatório USDA)
```bash
curl -X GET "http://localhost:3002/api/reports/wasde/latest" \
  -H "Content-Type: application/json"
```

## ⚠️ Problemas Identificados

### Conflito de Portas (CRÍTICO)
Múltiplos serviços configurados para a mesma porta:
- **Porta 3002:** Backend Node.js + SPR Python API + Auth API

**Solução recomendada:**
```
Backend Node.js:    3001 (prod) / 3002 (dev)
SPR Python API:     3003
Auth API:           3004  
Claude Bridge:      8000 (OK)
WPPConnect:         3005
```

### APIs Não Implementadas
Alguns endpoints estão documentados mas não implementados:
- `/api/ocr/process` - Processamento OCR
- `/api/analysis/commodity` - Análise de commodities
- `/api/analysis/prediction` - Predição de preços

## 🛠️ Ferramentas Recomendadas

### Validação de Contratos
```bash
# Instalar swagger-codegen
npm install -g swagger-codegen-cli

# Validar especificação
swagger-codegen validate -i spr-backend-api.yml
```

### Geração de Clientes
```bash
# Gerar client JavaScript
swagger-codegen generate -i spr-backend-api.yml -l javascript -o ./clients/js

# Gerar client Python  
swagger-codegen generate -i spr-backend-api.yml -l python -o ./clients/python
```

### Testes Automatizados
```bash
# Instalar newman (Postman CLI)
npm install -g newman

# Executar testes (após criar collection)
newman run spr-api-tests.postman_collection.json
```

## 📊 Estatísticas de Cobertura

| API | Endpoints Documentados | Implementados | Cobertura |
|-----|------------------------|---------------|-----------|
| Backend Node.js | 12 | 12 | 100% |
| WhatsApp | 7 | 7 | 100% |
| Python Services | 7 | 3 | 43% |
| Authentication | 7 | 4 | 57% |
| **TOTAL** | **33** | **26** | **79%** |

## 🔗 Próximos Passos

1. **Resolver conflitos de porta** (urgente)
2. **Implementar endpoints faltantes** para OCR e análise
3. **Criar Postman Collection** para todas as APIs
4. **Configurar CI/CD** com validação de contratos
5. **Migrar autenticação** para JWT completo
6. **Implementar rate limiting** e segurança

## 📖 Documentação Adicional

- **Relatório de Análise Completa:** [`/_reports/openapi_diff.md`](../_reports/openapi_diff.md)
- **Especificações OpenAPI:** Todos os arquivos `.yml` neste diretório
- **Repositório:** Sistema SPR - Royal Negócios Agrícolas

---

**Última atualização:** 05 de setembro de 2025  
**Versão das specs:** 1.0  
**Autor:** Claude Code (API Documentation Specialist)