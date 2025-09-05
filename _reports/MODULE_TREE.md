# SPR BACKEND - MAPEAMENTO COMPLETO DE MÓDULOS

## OVERVIEW DA ARQUITETURA BACKEND

### 1. BACKEND PRINCIPAL NODE.JS/EXPRESS
**Localização**: `/home/cadu/SPRNOVO/backend/node/`

```
backend/node/
├── src/                           # Código TypeScript estruturado
│   ├── index.ts                   # Entry point principal
│   ├── server.ts                  # Configuração servidor Express
│   ├── middleware/
│   │   ├── error-handler.ts       # Middleware tratamento de erros
│   │   └── request-enhancement.ts # Enhancement de requests
│   ├── routes/
│   │   ├── basis-endpoints.ts     # Endpoints base do SPR
│   │   ├── health.ts             # Health checks
│   │   ├── new-endpoints.ts      # Novos endpoints
│   │   └── whatsapp.ts           # Integração WhatsApp
│   ├── types/
│   │   ├── core.ts               # Tipos core do sistema
│   │   └── express.ts            # Extensões Express
│   └── utils/
│       ├── errors.ts             # Utilitários de erro
│       ├── response-helpers.ts   # Helpers de resposta
│       └── runtime-validation.ts # Validação runtime
├── backend_server_fixed.js        # Servidor principal (produção)
├── backend_server_stable.js       # Versão estável
├── backend_server_compat.js       # Versão compatibilidade
├── spr-backend-complete.js        # Backend completo
├── backend_simple.js              # Versão simplificada
├── simple_backend.js              # Backend mais básico
├── package.json                   # Dependências Node.js
└── package-lock.json              # Lock de dependências
```

**ENDPOINTS MAPEADOS**:
- `GET /health` - Health check do sistema
- `POST|GET /whatsapp/*` - APIs WhatsApp integration
- `GET|POST /api/basis/*` - Endpoints base SPR
- `GET|POST /api/new/*` - Novos endpoints

**DEPENDÊNCIAS PRINCIPAIS**:
- express ^4.18.2
- cors ^2.8.5  
- helmet ^6.0.1
- jsonwebtoken ^9.0.0
- axios ^1.3.4
- socket.io ^4.6.1

---

### 2. SERVIÇOS PYTHON - MÓDULO OCR
**Localização**: `/home/cadu/SPRNOVO/modules/ocr/`

```
modules/ocr/
├── main.py                     # FastAPI service principal
├── ocr_service.py              # Serviço OCR básico  
├── ocr_service_enhanced.py     # OCR Enhanced (51KB)
├── smart_analysis_agent.py     # Agente análise inteligente
├── clg_client.py              # Cliente CLG integration
├── clg_robot_service.py       # Serviço robot CLG
├── clg_smart_agent.py         # Agente inteligente CLG
├── spr_api.py                 # API SPR Python
├── spr_simple.py              # SPR simplificado
├── start_enhanced_ocr.py      # Script startup OCR
├── test_enhanced_ocr.py       # Testes OCR
├── manage_ocr_system.sh       # Script gestão OCR
├── README_OCR_Enhanced.md     # Documentação OCR
└── __pycache__/               # Cache Python
```

**FUNCIONALIDADES**:
- OCR de documentos com IA
- Análise inteligente de conteúdo
- Integração CLG (Claude Language Generation)
- APIs FastAPI para processamento

**ENDPOINTS PYTHON**:
- `GET /` - Status do serviço
- `GET /health` - Health check
- `POST /pulso/claude/ask` - Interface Claude

---

### 3. MÓDULO DE INGESTÃO DE DADOS  
**Localização**: `/home/cadu/SPRNOVO/modules/ingestion/`

```
modules/ingestion/
├── cepea_ingester.py          # Ingestor dados CEPEA (12.5KB)
├── imea_ingester.py           # Ingestor dados IMEA (13.5KB) 
├── clima_ingester.py          # Ingestor dados climáticos (15.7KB)
├── daily_report.py            # Gerador relatórios diários (13.3KB)
├── smoke_test.py              # Testes de fumaça (16.3KB)
├── crontab_spr_ingest         # Configuração cron jobs
└── init_spr_central.sql       # Schema database central
```

**FUNCIONALIDADES**:
- Ingestão automática dados CEPEA
- Ingestão dados IMEA (commodities)
- Monitoramento dados climáticos
- Relatórios diários automatizados
- Testes automatizados pipeline

---

### 4. MÓDULO DE AUTENTICAÇÃO
**Localização**: `/home/cadu/SPRNOVO/modules/auth/`

```
modules/auth/
└── backend_auth.py            # Sistema autenticação Python
```

**FUNCIONALIDADES**:
- Autenticação usuários
- Gestão tokens
- Controle acesso

---

### 5. UTILITÁRIOS E SCRIPTS
**Localização**: `/home/cadu/SPRNOVO/backend/utils/scripts/`

```
backend/utils/scripts/
├── backup_spr.sh              # Backup do sistema
├── health_watch.sh            # Monitoramento saúde
└── test/                      # Scripts de teste
    ├── deploy/                # Scripts deploy
    │   ├── deploy.sh          # Deploy principal  
    │   ├── deploy-config-debug.sh
    │   ├── deploy-corrections.sh
    │   ├── deploy-diagnosis-system.sh
    │   └── [+ 8 outros scripts deploy]
    ├── tests/                 # Suíte de testes
    │   ├── anti-mock-validation.js
    │   ├── e2e-license-tests.js
    │   ├── performance-load-tests.js
    │   └── smoke-license-comprehensive.js
    └── utils/                 # Utilitários sistema
        ├── anti-mock-sentinel.sh
        ├── cleanup-mocks.sh
        ├── dependency-mapper.sh
        └── [+ 6 outros utilitários]
```

---

## INTEGRAÇÕES E FLUXOS DE DADOS

### FLUXO PRINCIPAL SPR:
1. **Frontend** → **Backend Node.js** (Express + TypeScript)
2. **Backend Node.js** → **Serviços Python** (FastAPI + OCR)
3. **Scripts Ingestão** → **Database Central** (dados CEPEA/IMEA/Clima)
4. **Autenticação** → **Controle Acesso** (Python + JWT)

### PRINCIPAIS INTEGRAÇÕES:
- **WhatsApp API**: Integração via Node.js routes
- **OCR Services**: Python FastAPI + IA
- **Data Pipeline**: Ingestão automática dados commodities
- **Claude Integration**: Bridge Python para IA
- **Real-time**: Socket.io para updates tempo real

---

## TECNOLOGIAS IDENTIFICADAS

### BACKEND STACK:
- **Node.js** (>=16.0.0) + **Express.js** 4.18.2
- **TypeScript** (estruturado com types)
- **Python** + **FastAPI** (microserviços)
- **Socket.io** (real-time)
- **SQLite3** (database)

### SEGURANÇA:
- **JWT** (jsonwebtoken ^9.0.0)
- **BCrypt** (bcrypt ^5.1.0) 
- **Helmet** (helmet ^6.0.1)
- **Rate Limiting** (express-rate-limit)
- **CORS** configurado

### MONITORAMENTO:
- Health checks automatizados
- Scripts de diagnóstico
- Testes de performance
- Validação anti-mock
- Telemetria integrada

---

## PRÓXIMOS PASSOS SUGERIDOS

1. **Configurar ambiente SPRNOVO**
2. **Instalar dependências Node.js**: `npm install` em `/backend/node/`
3. **Configurar Python environment** para módulos
4. **Configurar databases** usando `init_spr_central.sql`
5. **Testar integrações** com scripts em `/test/`
6. **Deploy gradual** usando scripts em `/deploy/`

---

**STATUS**: ✅ MAPEAMENTO COMPLETO CONCLUÍDO  
**DATA**: $(date)  
**ARQUIVOS BACKEND PROCESSADOS**: ~119 arquivos de código  
**EXCLUSÕES**: Frontend, node_modules, builds minificados removidos