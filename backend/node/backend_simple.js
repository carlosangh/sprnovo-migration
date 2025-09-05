// Configuração de ambiente
process.env.NODE_ENV = process.env.NODE_ENV || 'development';

const express = require('express');
const cors = require('cors');
const path = require('path');
const fs = require('fs').promises;
const axios = require('axios');
const crypto = require('crypto');

const app = express();
const PORT = process.env.PORT || 3002;
const WHATSAPP_SERVER_PORT = process.env.WHATSAPP_SERVER_PORT || 3003;
const WHATSAPP_SERVER_URL = process.env.WHATSAPP_SERVER_URL || `http://localhost:${WHATSAPP_SERVER_PORT}`;

// Security configuration
const JWT_SECRET = process.env.JWT_SECRET || crypto.randomBytes(64).toString('hex');
const RATE_LIMIT_WINDOW = 15 * 60 * 1000; // 15 minutes
const RATE_LIMIT_MAX = 100; // requests per window

// Basic security headers
app.use((req, res, next) => {
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('X-Frame-Options', 'DENY');
    res.setHeader('X-XSS-Protection', '1; mode=block');
    next();
});

// Simple rate limiting middleware
const rateLimitStore = new Map();
const basicRateLimit = (req, res, next) => {
    const ip = req.ip || req.connection.remoteAddress;
    const now = Date.now();
    const windowStart = now - RATE_LIMIT_WINDOW;
    
    if (!rateLimitStore.has(ip)) {
        rateLimitStore.set(ip, []);
    }
    
    const requests = rateLimitStore.get(ip).filter(time => time > windowStart);
    requests.push(now);
    rateLimitStore.set(ip, requests);
    
    if (requests.length > RATE_LIMIT_MAX) {
        return res.status(429).json({
            error: 'Too many requests',
            retryAfter: Math.ceil(RATE_LIMIT_WINDOW / 1000),
            timestamp: new Date().toISOString()
        });
    }
    
    next();
};

app.use(basicRateLimit);

// Basic logging
app.use((req, res, next) => {
    if (process.env.NODE_ENV !== 'test') {
        console.log(`${new Date().toISOString()} - ${req.method} ${req.url} - ${req.ip}`);
    }
    next();
});

// CORS configuration
const allowedOrigins = process.env.NODE_ENV === 'production' 
    ? process.env.ALLOWED_ORIGINS?.split(',') || []
    : [
        'http://localhost:3000', 
        'http://localhost:3001', 
        'http://localhost:3002', 
        'http://localhost:8080',
        'http://127.0.0.1:3000',
        'http://127.0.0.1:3001',
        'http://127.0.0.1:3002',
        'http://127.0.0.1:8080'
    ];

const corsOptions = {
    origin: (origin, callback) => {
        if (!origin || allowedOrigins.includes(origin)) {
            callback(null, true);
        } else {
            console.warn(`🚫 CORS blocked origin: ${origin}`);
            callback(new Error('Not allowed by CORS'));
        }
    },
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
    maxAge: 86400 // 24 hours
};

app.use(cors(corsOptions));

// Body parsing middleware
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Request ID middleware for tracing
app.use((req, res, next) => {
    req.id = crypto.randomUUID();
    res.setHeader('X-Request-ID', req.id);
    next();
});

// System status
let systemStatus = {
    whatsappConnected: false,
    lastCheck: new Date(),
    metrics: {
        totalMessages: 0,
        totalRequests: 0,
        failedRequests: 0
    }
};

// Check WhatsApp Server Status
async function checkWhatsAppServerStatus() {
    try {
        console.log('🔍 Verificando status do WhatsApp Server...');
        systemStatus.metrics.totalRequests++;
        
        const response = await axios.get(`${WHATSAPP_SERVER_URL}/api/status`, { timeout: 5000 });
        
        const isConnected = response.data.whatsappConnected || response.data.connected || false;
        systemStatus.whatsappConnected = isConnected;
        systemStatus.lastCheck = new Date();
        
        console.log(`✅ WhatsApp Server: ${isConnected ? 'Online' : 'Offline'}`);
        return true;
    } catch (error) {
        console.error('❌ WhatsApp Server indisponível:', error.message);
        systemStatus.whatsappConnected = false;
        systemStatus.lastCheck = new Date();
        systemStatus.metrics.failedRequests++;
        return false;
    }
}

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({
        status: 'ok',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        version: '1.0.0',
        environment: process.env.NODE_ENV,
        port: PORT
    });
});

// System status endpoint
app.get('/api/status', async (req, res) => {
    try {
        const whatsappServerOnline = await checkWhatsAppServerStatus();
        
        res.json({
            status: 'operational',
            services: {
                backend: 'active',
                whatsapp: systemStatus.whatsappConnected ? 'connected' : 'disconnected',
                whatsappServer: whatsappServerOnline ? 'online' : 'offline'
            },
            timestamp: new Date().toISOString(),
            uptime: process.uptime(),
            metrics: systemStatus.metrics
        });
    } catch (error) {
        console.error('❌ Erro no endpoint /api/status:', error);
        res.status(500).json({
            status: 'error',
            message: error.message,
            timestamp: new Date().toISOString()
        });
    }
});

// 1. Análise de Commodities
app.get('/api/commodities/analysis/:commodity', async (req, res) => {
    try {
        const { commodity } = req.params;
        const { period = '30d' } = req.query;

        console.log(`📊 Analisando commodity: ${commodity} (período: ${period})`);

        // Simulação de análise de commodities
        const mockAnalysis = {
            commodity: commodity.toUpperCase(),
            analysis: {
                trend: Math.random() > 0.5 ? 'alta' : 'baixa',
                confidence: Math.round(Math.random() * 40 + 60), // 60-100%
                price: {
                    current: Math.round(Math.random() * 1000 + 500),
                    predicted: Math.round(Math.random() * 1000 + 500),
                    change: Math.round((Math.random() - 0.5) * 20 * 100) / 100
                }
            },
            period,
            timestamp: new Date().toISOString(),
            requestId: req.id
        };

        res.json(mockAnalysis);
    } catch (error) {
        console.error(`❌ Erro na análise de commodities:`, error);
        res.status(500).json({
            error: 'Erro interno do servidor',
            message: 'Falha na análise de commodities',
            requestId: req.id,
            timestamp: new Date().toISOString()
        });
    }
});

// 2. Previsões de Preço
app.get('/api/predictions/:commodity', async (req, res) => {
    try {
        const { commodity } = req.params;
        const { days = 7 } = req.query;

        console.log(`🔮 Gerando previsão para: ${commodity} (${days} dias)`);

        // Simulação de previsões
        const predictions = [];
        const basePrice = Math.round(Math.random() * 1000 + 500);
        
        for (let i = 1; i <= parseInt(days); i++) {
            const date = new Date();
            date.setDate(date.getDate() + i);
            
            predictions.push({
                date: date.toISOString().split('T')[0],
                price: Math.round(basePrice * (1 + (Math.random() - 0.5) * 0.1)),
                confidence: Math.round(Math.random() * 30 + 70)
            });
        }

        res.json({
            commodity: commodity.toUpperCase(),
            predictions,
            accuracy: Math.round(Math.random() * 20 + 80),
            timestamp: new Date().toISOString(),
            requestId: req.id
        });
    } catch (error) {
        console.error(`❌ Erro nas previsões:`, error);
        res.status(500).json({
            error: 'Erro interno do servidor',
            message: 'Falha na geração de previsões',
            requestId: req.id,
            timestamp: new Date().toISOString()
        });
    }
});

// 3. Análise de Risco
app.post('/api/risk/analyze', async (req, res) => {
    try {
        const { portfolio, timeframe = '1m' } = req.body;

        console.log(`⚠️ Analisando riscos do portfólio (prazo: ${timeframe})`);

        if (!portfolio || !Array.isArray(portfolio)) {
            return res.status(400).json({
                error: 'Dados inválidos',
                message: 'Portfolio deve ser um array de commodities',
                requestId: req.id
            });
        }

        // Simulação de análise de risco
        const riskAnalysis = {
            portfolio: portfolio.map(item => ({
                ...item,
                risk_score: Math.round(Math.random() * 10),
                volatility: Math.round(Math.random() * 50),
                var_95: Math.round(Math.random() * 100) / 10
            })),
            overall_risk: Math.round(Math.random() * 10),
            recommendations: [
                'Diversificar portfolio',
                'Monitorar volatilidade',
                'Considerar hedge'
            ],
            timeframe,
            timestamp: new Date().toISOString(),
            requestId: req.id
        };

        res.json(riskAnalysis);
    } catch (error) {
        console.error(`❌ Erro na análise de risco:`, error);
        res.status(500).json({
            error: 'Erro interno do servidor',
            message: 'Falha na análise de risco',
            requestId: req.id,
            timestamp: new Date().toISOString()
        });
    }
});

// 4. Dados de Mercado
app.get('/api/market/data/:commodity', async (req, res) => {
    try {
        const { commodity } = req.params;
        const { interval = '1h', limit = 100 } = req.query;

        console.log(`📈 Obtendo dados de mercado: ${commodity}`);

        // Simulação de dados de mercado
        const marketData = [];
        const basePrice = Math.random() * 1000 + 500;
        
        for (let i = 0; i < Math.min(parseInt(limit), 1000); i++) {
            const timestamp = new Date(Date.now() - i * 3600000);
            const price = basePrice * (1 + (Math.random() - 0.5) * 0.05);
            
            marketData.push({
                timestamp: timestamp.toISOString(),
                open: Math.round(price * 100) / 100,
                high: Math.round(price * 1.02 * 100) / 100,
                low: Math.round(price * 0.98 * 100) / 100,
                close: Math.round(price * 100) / 100,
                volume: Math.round(Math.random() * 10000)
            });
        }

        res.json({
            commodity: commodity.toUpperCase(),
            interval,
            data: marketData.reverse(),
            count: marketData.length,
            timestamp: new Date().toISOString(),
            requestId: req.id
        });
    } catch (error) {
        console.error(`❌ Erro nos dados de mercado:`, error);
        res.status(500).json({
            error: 'Erro interno do servidor',
            message: 'Falha na obtenção dos dados de mercado',
            requestId: req.id,
            timestamp: new Date().toISOString()
        });
    }
});

// 5. WhatsApp Integration
app.post('/api/whatsapp/send', async (req, res) => {
    try {
        const { to, message, type = 'text' } = req.body;

        if (!to || !message) {
            return res.status(400).json({
                error: 'Dados obrigatórios faltando',
                message: 'Campos "to" e "message" são obrigatórios',
                requestId: req.id
            });
        }

        console.log(`📱 Enviando mensagem WhatsApp para: ${to}`);

        try {
            const response = await axios.post(`${WHATSAPP_SERVER_URL}/send`, {
                to,
                message,
                type
            }, { timeout: 5000 });

            res.json({
                success: true,
                messageId: response.data.messageId || `msg_${Date.now()}`,
                timestamp: new Date().toISOString(),
                requestId: req.id
            });
        } catch (whatsappError) {
            console.warn(`⚠️ WhatsApp service unavailable, usando modo simulação`);
            
            res.json({
                success: true,
                messageId: `sim_${Date.now()}`,
                mode: 'simulation',
                message: 'Mensagem enviada em modo simulação',
                timestamp: new Date().toISOString(),
                requestId: req.id
            });
        }
    } catch (error) {
        console.error(`❌ Erro no envio WhatsApp:`, error);
        res.status(500).json({
            error: 'Erro interno do servidor',
            message: 'Falha no envio da mensagem',
            requestId: req.id,
            timestamp: new Date().toISOString()
        });
    }
});

// 6. WhatsApp Status
app.get('/api/whatsapp/status', async (req, res) => {
    try {
        console.log(`📱 Verificando status do WhatsApp`);

        try {
            const response = await axios.get(`${WHATSAPP_SERVER_URL}/status`, { timeout: 3000 });
            res.json(response.data);
        } catch (error) {
            res.json({
                status: 'disconnected',
                message: 'WhatsApp service indisponível',
                mode: 'simulation',
                timestamp: new Date().toISOString(),
                requestId: req.id
            });
        }
    } catch (error) {
        console.error(`❌ Erro no status WhatsApp:`, error);
        res.status(500).json({
            error: 'Erro interno do servidor',
            message: 'Falha na verificação de status',
            requestId: req.id,
            timestamp: new Date().toISOString()
        });
    }
});

// 7. Test Endpoint para verificar conectividade
app.get('/api/test', (req, res) => {
    res.json({
        message: 'SPR Backend funcionando!',
        timestamp: new Date().toISOString(),
        requestId: req.id,
        server: {
            port: PORT,
            uptime: process.uptime(),
            memory: process.memoryUsage()
        }
    });
});

// Static file serving
app.use(express.static(path.join(__dirname, 'public')));

// Catch-all handler
app.get('*', (req, res) => {
    res.status(404).json({
        error: 'Not Found',
        message: 'Endpoint não encontrado',
        availableEndpoints: [
            'GET /health',
            'GET /api/status',
            'GET /api/commodities/analysis/:commodity',
            'GET /api/predictions/:commodity', 
            'POST /api/risk/analyze',
            'GET /api/market/data/:commodity',
            'POST /api/whatsapp/send',
            'GET /api/whatsapp/status',
            'GET /api/test'
        ],
        requestId: req.id,
        timestamp: new Date().toISOString()
    });
});

// Global error handler
app.use((err, req, res, next) => {
    console.error(`❌ Erro global:`, err);
    
    const errorMessage = process.env.NODE_ENV === 'production' 
        ? 'Erro interno do servidor' 
        : err.message;

    res.status(err.status || 500).json({
        error: 'Server Error',
        message: errorMessage,
        requestId: req.id,
        timestamp: new Date().toISOString(),
        ...(process.env.NODE_ENV === 'development' && { stack: err.stack })
    });
});

// Cleanup function
const cleanup = () => {
    console.log('\n🛑 Recebido sinal de encerramento...');
    console.log('🧹 Limpando recursos...');
    
    if (rateLimitStore) {
        rateLimitStore.clear();
        console.log('✅ Rate limit store limpo');
    }
    
    console.log('✅ Cleanup concluído');
    process.exit(0);
};

// Signal handlers
process.on('SIGTERM', cleanup);
process.on('SIGINT', cleanup);

// Error handlers
process.on('uncaughtException', (error) => {
    console.error('❌ Exceção não capturada:', error);
    process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
    console.error('❌ Promise rejeitada:', reason);
    process.exit(1);
});

// Start server
const server = app.listen(PORT, () => {
    console.log(`\n🚀 SPR Backend Simplificado iniciado com sucesso!`);
    console.log(`📍 Servidor rodando na porta ${PORT}`);
    console.log(`🌍 Ambiente: ${process.env.NODE_ENV}`);
    console.log(`📱 WhatsApp Server URL: ${WHATSAPP_SERVER_URL}`);
    console.log(`⚡ Rate Limit: ${RATE_LIMIT_MAX} requests per ${RATE_LIMIT_WINDOW/1000}s`);
    console.log(`\n📋 Endpoints disponíveis:`);
    console.log(`   Health Check: http://localhost:${PORT}/health`);
    console.log(`   API Status: http://localhost:${PORT}/api/status`);
    console.log(`   API Test: http://localhost:${PORT}/api/test`);
    console.log(`\n✅ Sistema pronto para receber requisições!`);
    
    // Check WhatsApp Server status on startup
    setTimeout(async () => {
        const isOnline = await checkWhatsAppServerStatus();
        console.log(`📱 WhatsApp Server: ${isOnline ? '✅ Online' : '❌ Offline'}`);
    }, 2000);
});

// Server timeout configuration
server.timeout = 30000; // 30 seconds
server.keepAliveTimeout = 5000; // 5 seconds
server.headersTimeout = 6000; // 6 seconds

module.exports = app;