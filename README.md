# SPR - Sistema Preditivo Royal

Sistema de previsão inteligente de preços de commodities agrícolas para o mercado brasileiro, integrado com Evolution API v2 para comunicação via WhatsApp.

## Estrutura do Projeto

```
SPRNOVO/
├── backend/                 # Backend Node.js e Python
├── frontend/               # Frontend Next.js 14
├── modules/               # Módulos Python (auth, etc)
├── ai_agents/             # Sistema multi-agentes IA
├── scripts/               # Scripts de automação
├── nginx/                 # Configurações Nginx
├── secrets/               # Arquivos de configuração segura
└── docker-compose.yml     # Orquestração de containers
```

## Ativação Evolution v2 com Postgres+Redis

### Pré-requisitos

- Docker e Docker Compose instalados
- Node.js 18+ e Python 3.9+
- Nginx (para produção)

### 1. Configuração dos Segredos

Os segredos de produção já estão configurados em:
- `./secrets/evolution.env` - Configurações Evolution API
- `./backend/.env` - Configurações backend

### 2. Subir Serviços

```bash
# Usando script de admin
./scripts/evo_admin.sh up

# Ou diretamente com docker-compose
docker-compose up -d
```

### 3. Verificação dos Serviços

```bash
# Status dos containers
./scripts/evo_admin.sh ps

# Logs da Evolution API
./scripts/evo_admin.sh logs

# Teste de conectividade
curl -H "apikey: c451bb1deb223c150b4c41ed3925bfaa91cdacf45d3d01350b2a16520c97b21c" \
  http://localhost:8080/manager/status
```

### 4. Testes com Probe Script

```bash
# Teste básico de conectividade
./scripts/evo_probe.sh base

# Teste completo
./scripts/evo_probe.sh all

# Criar instância WhatsApp
./scripts/evo_probe.sh create

# Conectar e obter QR code
./scripts/evo_probe.sh connect

# Enviar mensagem de teste
PHONE="+5566999999999" TEXT="Hello from SPR" ./scripts/evo_probe.sh sendText
```

### 5. Frontend

```bash
cd frontend
npm install
npm run dev
```

Acesse: http://localhost:3000

## Componentes da Arquitetura

### Docker Services

- **PostgreSQL 16** (`pg`): Banco principal da Evolution API
- **Redis 7** (`redis`): Cache e sessões
- **Evolution API** (`evolution-api`): API WhatsApp com healthcheck

### Scripts de Administração

- `./scripts/evo_admin.sh` - Gerenciamento Docker (up/down/ps/logs)
- `./scripts/evo_probe.sh` - Testes e operações da Evolution API
- `./scripts/mini_smoke.sh` - Monitoramento rápido de saúde
- `./scripts/go_no_go_checklist.sh` - Validação completa do sistema

### Frontend Features

- **Dashboard**: Visão geral do sistema
- **WhatsApp**: Gerenciamento de instâncias e mensagens  
- **Commodities**: Gráficos de preços com Recharts
- **Settings**: Configurações do sistema
- **Status Banner**: Monitoramento Evolution API em tempo real

## Configuração de Produção

### 1. DNS e SSL

```bash
# Configurar DNS A/AAAA records
# evo.royalnegociosagricolas.com.br -> IP_SERVIDOR

# Instalar certificado SSL
sudo certbot --nginx -d evo.royalnegociosagricolas.com.br

# Copiar configuração Nginx
sudo cp nginx/evo.royalnegociosagricolas.com.br /etc/nginx/sites-available/
sudo ln -s /etc/nginx/sites-available/evo.royalnegociosagricolas.com.br /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

### 2. Variáveis de Ambiente

Configurar no servidor de produção:
- `NEXT_PUBLIC_EVO_URL=https://evo.royalnegociosagricolas.com.br`
- `NEXT_PUBLIC_API_BASE_URL=https://royalnegociosagricolas.com.br`

### 3. Webhook Configuration

A Evolution API enviará webhooks para:
```
https://royalnegociosagricolas.com.br/api/webhook/evolution?token=f542b07048e0b7401bf1de47e84b2822f27391aa414cc72c
```

## Monitoramento

### Health Checks

```bash
# Evolution API
curl https://evo.royalnegociosagricolas.com.br/manager/status

# Backend SPR  
curl http://localhost:3002/health

# Smoke test completo
./scripts/mini_smoke.sh
```

### Logs

```bash
# Evolution API
./scripts/evo_admin.sh logs evolution-api

# Todos os serviços
./scripts/evo_admin.sh logs all

# Nginx (produção)
sudo tail -f /var/log/nginx/evo_access.log
```

## Troubleshooting

### Evolution API não inicia

1. Verificar logs: `./scripts/evo_admin.sh logs`
2. Confirmar PostgreSQL: `docker-compose ps pg`
3. Testar conectividade: `./scripts/evo_probe.sh base`

### Frontend não conecta Evolution API

1. Verificar variável `NEXT_PUBLIC_EVO_URL`
2. Testar CORS no navegador
3. Confirmar status banner no layout

### Webhooks não funcionam

1. Verificar token na URL do webhook
2. Confirmar rota no backend: `/api/webhook/evolution`
3. Testar com curl manual

## Segurança

- **Rate Limiting**: 10 req/s por IP no Nginx
- **HTTPS Only**: Redirecionamento automático
- **API Keys**: Autenticação obrigatória
- **CORS**: Restrito ao domínio principal
- **Headers**: Security headers configurados

## Suporte

- Logs: `./scripts/evo_admin.sh logs`
- Status: `./scripts/mini_smoke.sh`  
- Teste completo: `./scripts/go_no_go_checklist.sh`