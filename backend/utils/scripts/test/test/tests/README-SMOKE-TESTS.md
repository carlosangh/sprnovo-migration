# SPR LICENSE SYSTEM - COMPREHENSIVE SMOKE TESTS

Sistema completo de testes smoke para validação do sistema de licenças SPR sem mock. Este conjunto de testes garante que o sistema funciona 100% com fonte única real (backend + frontend + integração).

## 📋 Índice

- [Visão Geral](#visão-geral)
- [Arquitetura dos Testes](#arquitetura-dos-testes)
- [Instalação e Configuração](#instalação-e-configuração)
- [Execução dos Testes](#execução-dos-testes)
- [Tipos de Testes](#tipos-de-testes)
- [Interpretação dos Resultados](#interpretação-dos-resultados)
- [Configuração de Produção](#configuração-de-produção)
- [Troubleshooting](#troubleshooting)

## 🎯 Visão Geral

O sistema de smoke tests do SPR foi projetado para validar:

1. **Funcionamento real sem mock**: Todos os testes usam o sistema real
2. **Cobertura completa**: Backend, Frontend, Integração, Performance
3. **Validação de produção**: Testes específicos para ambiente produtivo
4. **Anti-mock**: Detecta e bloqueia sistemas mock em produção
5. **Regressão**: Garante que funcionalidades não quebrem após atualizações

### 🚨 **OBJETIVO CRÍTICO**
Validar que o sistema funciona **100% sem mock** com fonte única real.

## 🏗️ Arquitetura dos Testes

```
tests/
├── smoke-license-comprehensive.js    # Testes backend e integração
├── e2e-license-tests.js             # Testes end-to-end frontend
├── anti-mock-validation.js          # Validações anti-mock
├── performance-load-tests.js        # Testes de performance
├── production-validation-config.json # Configurações produção
└── README-SMOKE-TESTS.md            # Esta documentação

run-smoke-tests-complete.sh          # Script master
```

## 🔧 Instalação e Configuração

### Pré-requisitos

```bash
# Node.js v16+
node --version

# Dependências do sistema
sudo apt-get install -y bc curl

# Dependências Node.js (instaladas automaticamente)
npm install axios ws playwright
```

### Configuração de Ambiente

```bash
# Desenvolvimento
export NODE_ENV=development
export BACKEND_URL=http://localhost:3002
export FRONTEND_URL=http://localhost:3000

# Produção
export NODE_ENV=production
export LICENSE_MODE=production
export LICENSE_MOCK=0
export NO_MOCK=1
export BACKEND_URL=https://spr-backend.com
export FRONTEND_URL=https://spr-frontend.com
```

## 🚀 Execução dos Testes

### Execução Completa (Recomendada)

```bash
# Executar todos os testes
./run-smoke-tests-complete.sh

# Modo produção (validações rigorosas)
./run-smoke-tests-complete.sh --production

# Sem testes E2E (ambientes headless)
./run-smoke-tests-complete.sh --no-e2e

# Modo verbose (debug)
./run-smoke-tests-complete.sh --verbose
```

### Execução Individual

```bash
# Apenas testes backend
node tests/smoke-license-comprehensive.js

# Apenas validação anti-mock
node tests/anti-mock-validation.js

# Apenas testes E2E
node tests/e2e-license-tests.js

# Apenas testes de performance
node tests/performance-load-tests.js
```

### Configuração de Performance

```bash
# Configurar carga de testes
export CONCURRENT_USERS=20
export TEST_DURATION=120
export RAMP_UP=15
export THINK_TIME=1000
```

## 📊 Tipos de Testes

### 1. Testes Backend Críticos

**Arquivo**: `smoke-license-comprehensive.js`

#### ✅ Testes Implementados:

- **GET /api/license/status** → `active:true` quando licença ativa
- **GET /api/license/status** → `active:false` quando sem licença  
- **POST /api/license/activate** → transição `false→true`
- **POST /api/license/deactivate** → transição `true→false`
- **Middleware** bloqueia acessos sem licença válida
- **JWT** contém claim `spr_license=active`

```bash
# Exemplo de execução
node tests/smoke-license-comprehensive.js
```

### 2. Testes Frontend E2E

**Arquivo**: `e2e-license-tests.js`

#### ✅ Cenários Testados:

- App startup faz GET /api/license/status
- Banner "Sistema não ativado" aparece quando `active:false`
- Banner desaparece quando `active:true`
- Form ativação: POST → invalidate query → redirect
- Guards bloqueiam rotas quando `active:false`
- Guards liberam rotas quando `active:true`

```bash
# Executar com Playwright
export HEADLESS=false  # Para ver browser
node tests/e2e-license-tests.js
```

### 3. Validação Anti-Mock

**Arquivo**: `anti-mock-validation.js`

#### 🚫 Validações Críticas:

- Mock Client é rejeitado
- default-session não funciona
- Build falha se mock detected em produção
- No localStorage com dados mock de licença
- Environment variables corretas em produção

```bash
# Executar validação anti-mock
NODE_ENV=production node tests/anti-mock-validation.js
```

### 4. Testes de Performance

**Arquivo**: `performance-load-tests.js`

#### ⚡ Métricas Avaliadas:

- Throughput (requests/second)
- Response times (min, avg, max, P95)
- Error rates
- Success rates
- Resource utilization

```bash
# Teste de carga com 50 usuários por 60 segundos
CONCURRENT_USERS=50 TEST_DURATION=60 node tests/performance-load-tests.js
```

## 📈 Interpretação dos Resultados

### Códigos de Saída

- **0**: Todos os testes passaram
- **1**: Alguns testes falharam (não crítico)
- **2**: Falhas críticas de segurança (mock detectado em produção)
- **3**: Erro fatal de execução

### Localização dos Relatórios

```
/opt/spr/_reports/
├── smoke_tests_master_YYYYMMDD_HHMMSS.json     # Relatório consolidado
├── smoke_license.log                           # Testes backend
├── e2e_license_tests.json                      # Testes E2E
├── anti_mock_validation.json                   # Validação anti-mock
├── performance_report_TIMESTAMP.json          # Performance
└── screenshots/                               # Screenshots E2E
    ├── startup-success.png
    ├── activation-success.png
    └── ...
```

### Exemplo de Relatório Master

```json
{
  "summary": {
    "timestamp": "2025-09-02T14:30:00Z",
    "environment": "production",
    "statistics": {
      "total_tests": 45,
      "passed": 43,
      "failed": 2,
      "success_rate": "95.56%"
    }
  }
}
```

## 🏭 Configuração de Produção

### Variáveis de Ambiente Obrigatórias

```bash
export NODE_ENV=production
export LICENSE_MODE=production
export LICENSE_MOCK=0
export NO_MOCK=1
```

### Validações de Produção

O sistema executa validações rigorosas em produção:

1. **Environment Check**: Variáveis corretas
2. **Mock Detection**: Nenhum código mock no build
3. **Security Headers**: Headers de segurança implementados
4. **Rate Limiting**: Limites de requisição funcionando
5. **Database Integrity**: Dados persistidos corretamente

### Thresholds de Performance

```json
{
  "max_response_time_ms": 3000,
  "min_success_rate": 95,
  "max_error_rate": 5,
  "max_95th_percentile_ms": 5000
}
```

## 🔍 Troubleshooting

### Problemas Comuns

#### 1. Backend não responde

```bash
# Verificar se servidor está rodando
curl http://localhost:3002/api/health

# Iniciar servidor
node backend_server_fixed.js
```

#### 2. Testes E2E falham

```bash
# Instalar Playwright
npx playwright install chromium --with-deps

# Executar com debug
export HEADLESS=false
export VERBOSE=true
node tests/e2e-license-tests.js
```

#### 3. Falha de permissões nos relatórios

```bash
# Criar diretório de relatórios
sudo mkdir -p /opt/spr/_reports
sudo chown -R $USER:$USER /opt/spr/_reports
```

#### 4. Mock detectado em produção

```bash
# Verificar environment
echo $NODE_ENV
echo $LICENSE_MODE
echo $NO_MOCK

# Limpar build e recompilar
rm -rf dist/ build/
npm run build
```

### Logs de Debug

```bash
# Habilitar logs verbose
export DEBUG=1
export VERBOSE=true

# Executar com logs detalhados
./run-smoke-tests-complete.sh --verbose
```

## 📋 Checklist de Produção

Antes de deploy em produção, verificar:

- [ ] `NODE_ENV=production`
- [ ] `LICENSE_MODE=production`
- [ ] `NO_MOCK=1`
- [ ] Build sem código mock
- [ ] Testes smoke passando 100%
- [ ] Validação anti-mock OK
- [ ] Performance dentro dos thresholds
- [ ] Database com licenças reais
- [ ] Logs sem dados sensíveis

## 🚨 Alertas Críticos

### Exit Code 2 (Segurança)

Se os testes retornarem exit code 2, **NÃO FAZER DEPLOY**:

- Mock code detectado em produção
- Variáveis de ambiente incorretas  
- Licenças de teste ativas em produção

### Failure Rate > 5%

Se mais de 5% dos testes falharem:

- Verificar conectividade com backend
- Validar configuração de banco de dados
- Checar se todos os serviços estão rodando

## 📞 Suporte

Para problemas com os testes smoke:

1. Verificar logs em `/opt/spr/_reports/`
2. Executar em modo verbose
3. Validar configuração de ambiente
4. Verificar conectividade de rede

---

**🎯 LEMBRE-SE**: O objetivo é validar que o sistema funciona **100% sem mock** com fonte única real. Qualquer falha crítica deve ser resolvida antes do deploy em produção.