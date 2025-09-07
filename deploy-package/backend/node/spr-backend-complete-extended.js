/**
 * SPR Backend Completo - Sistema Preditivo Royal
 * Backend Node.js com todas as APIs necessárias para o sistema
 * Conectado ao PostgreSQL com schema completo
 */

const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3001;

// =====================================================
// CONFIGURAÇÕES E MIDDLEWARE
// =====================================================

// Configuração PostgreSQL
const pool = new Pool({
    host: process.env.DB_HOST || 'localhost',
    port: process.env.DB_PORT || 5432,
    database: process.env.DB_NAME || 'spr_db',
    user: process.env.DB_USER || 'spr_user',
    password: process.env.DB_PASSWORD || 'spr_password_2025',
    max: 20,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 2000,
});

// Configuração CORS
app.use(cors({
    origin: ['http://localhost:3000', 'http://localhost:8080', 'http://localhost:8082', 'http://localhost:3002'],
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE'],
    allowedHeaders: ['Content-Type', 'Authorization']
}));

// Middleware
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

// Configuração Multer para upload de arquivos
const uploadDir = path.join(__dirname, '../uploads/ocr');
if (!fs.existsSync(uploadDir)) {
    fs.mkdirSync(uploadDir, { recursive: true });
}

const storage = multer.diskStorage({
    destination: uploadDir,
    filename: (req, file, cb) => {
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        cb(null, uniqueSuffix + path.extname(file.originalname));
    }
});

const upload = multer({ 
    storage: storage,
    limits: { fileSize: 50 * 1024 * 1024 } // 50MB
});

// =====================================================
// FUNÇÕES HELPER
// =====================================================

// Função helper para resposta padronizada
const sendResponse = (res, data, message = null, metadata = null) => {
    if (!data || (Array.isArray(data) && data.length === 0)) {
        return res.json({
            success: false,
            message: "sem estes dados no BD",
            data: []
        });
    }
    
    const response = {
        success: true,
        message: message || "Dados encontrados com sucesso",
        data: data
    };

    if (metadata) {
        response.metadata = metadata;
    }
    
    res.json(response);
};

// Função para logging estruturado
const logActivity = async (level, component, message, details = null, agentId = null) => {
    try {
        await pool.query(`
            INSERT INTO system_logs (level, component, agent_id, message, details, timestamp)
            VALUES ($1, $2, $3, $4, $5, NOW())
        `, [level, component, agentId, message, details ? JSON.stringify(details) : null]);
    } catch (error) {
        console.error('Erro ao gravar log:', error);
    }
};

// Função para validar paginação
const validatePagination = (req) => {
    const page = Math.max(1, parseInt(req.query.page) || 1);
    const limit = Math.min(100, Math.max(1, parseInt(req.query.limit) || 10));
    const offset = (page - 1) * limit;
    return { page, limit, offset };
};

// =====================================================
// ROTAS BÁSICAS
// =====================================================

// Health check
app.get('/', (req, res) => {
    res.json({
        status: "SPR Backend Extended",
        version: "2.0.0",
        database: "PostgreSQL conectado",
        timestamp: new Date().toISOString(),
        modules: ["Analytics", "Research", "OCR", "Agents", "System"]
    });
});

// Status geral do sistema
app.get('/api/status', async (req, res) => {
    try {
        // Teste de conexão com banco
        const dbTest = await pool.query('SELECT 1');
        
        // Estatísticas gerais
        const stats = await Promise.all([
            pool.query('SELECT COUNT(*) FROM market_analyses'),
            pool.query('SELECT COUNT(*) FROM trading_signals WHERE status = $1', ['active']),
            pool.query('SELECT COUNT(*) FROM research_reports'),
            pool.query('SELECT COUNT(*) FROM ocr_documents'),
            pool.query('SELECT COUNT(*) FROM agent_status WHERE status = $1', ['online'])
        ]);

        await logActivity('info', 'system', 'Status check realizado');

        res.json({
            status: "✅ ONLINE",
            database: "✅ CONNECTED", 
            version: "2.0.0-extended",
            timestamp: new Date().toISOString(),
            stats: {
                market_analyses: parseInt(stats[0].rows[0].count),
                active_signals: parseInt(stats[1].rows[0].count),
                research_reports: parseInt(stats[2].rows[0].count),
                ocr_documents: parseInt(stats[3].rows[0].count),
                online_agents: parseInt(stats[4].rows[0].count),
                uptime: process.uptime()
            }
        });
    } catch (error) {
        console.error('Erro no status:', error);
        await logActivity('error', 'system', 'Erro no health check', { error: error.message });
        
        res.status(500).json({
            status: "❌ ERROR",
            database: "❌ DISCONNECTED",
            error: error.message
        });
    }
});

// =====================================================
// ANALYTICS APIs
// =====================================================

// GET /api/analytics/market - Análises de mercado
app.get('/api/analytics/market', async (req, res) => {
    try {
        const { page, limit, offset } = validatePagination(req);
        const { commodity, analysis_type, region } = req.query;
        
        let whereClause = 'WHERE 1=1';
        const params = [];
        
        if (commodity) {
            whereClause += ` AND commodity = $${params.length + 1}`;
            params.push(commodity.toUpperCase());
        }
        
        if (analysis_type) {
            whereClause += ` AND analysis_type = $${params.length + 1}`;
            params.push(analysis_type);
        }
        
        if (region) {
            whereClause += ` AND region = $${params.length + 1}`;
            params.push(region);
        }
        
        const query = `
            SELECT id, commodity, analysis_type, region, data, confidence_score,
                   insights, recommendations, created_at, agent_id
            FROM market_analyses 
            ${whereClause}
            ORDER BY created_at DESC
            LIMIT $${params.length + 1} OFFSET $${params.length + 2}
        `;
        
        params.push(limit, offset);
        
        const result = await pool.query(query, params);
        
        // Contar total para paginação
        const countQuery = `SELECT COUNT(*) FROM market_analyses ${whereClause}`;
        const countResult = await pool.query(countQuery, params.slice(0, -2));
        const total = parseInt(countResult.rows[0].count);
        
        await logActivity('info', 'analytics', 'Market analyses consultadas', { 
            count: result.rows.length, 
            filters: { commodity, analysis_type, region }
        });

        sendResponse(res, result.rows, null, {
            pagination: {
                page,
                limit,
                total,
                pages: Math.ceil(total / limit)
            }
        });
    } catch (error) {
        console.error('Erro ao buscar análises de mercado:', error);
        await logActivity('error', 'analytics', 'Erro ao consultar market analyses', { error: error.message });
        sendResponse(res, null, `Erro: ${error.message}`);
    }
});

// POST /api/analytics/market - Criar análise de mercado
app.post('/api/analytics/market', async (req, res) => {
    try {
        const {
            commodity,
            analysis_type,
            region,
            data,
            confidence_score,
            insights,
            recommendations,
            agent_id
        } = req.body;

        if (!commodity || !analysis_type || !data) {
            return res.status(400).json({
                success: false,
                message: "Campos obrigatórios: commodity, analysis_type, data"
            });
        }

        const result = await pool.query(`
            INSERT INTO market_analyses 
            (commodity, analysis_type, region, data, confidence_score, insights, recommendations, agent_id)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
            RETURNING *
        `, [
            commodity.toUpperCase(),
            analysis_type,
            region,
            JSON.stringify(data),
            confidence_score,
            insights,
            recommendations,
            agent_id
        ]);

        await logActivity('info', 'analytics', 'Nova análise de mercado criada', {
            id: result.rows[0].id,
            commodity,
            analysis_type
        }, agent_id);

        res.status(201).json({
            success: true,
            message: "Análise de mercado criada com sucesso",
            data: result.rows[0]
        });
    } catch (error) {
        console.error('Erro ao criar análise de mercado:', error);
        await logActivity('error', 'analytics', 'Erro ao criar market analysis', { error: error.message });
        res.status(500).json({
            success: false,
            message: `Erro: ${error.message}`
        });
    }
});

// GET/POST /api/analytics/trading-signals - Sinais de trading
app.get('/api/analytics/trading-signals', async (req, res) => {
    try {
        const { page, limit, offset } = validatePagination(req);
        const { commodity, signal_type, status = 'active' } = req.query;
        
        let whereClause = 'WHERE 1=1';
        const params = [];
        
        if (commodity) {
            whereClause += ` AND commodity = $${params.length + 1}`;
            params.push(commodity.toUpperCase());
        }
        
        if (signal_type) {
            whereClause += ` AND signal_type = $${params.length + 1}`;
            params.push(signal_type.toUpperCase());
        }
        
        if (status) {
            whereClause += ` AND status = $${params.length + 1}`;
            params.push(status);
        }

        const query = `
            SELECT id, commodity, signal_type, target_price, stop_loss, confidence,
                   reasoning, valid_until, status, created_at, agent_id
            FROM trading_signals 
            ${whereClause}
            ORDER BY created_at DESC
            LIMIT $${params.length + 1} OFFSET $${params.length + 2}
        `;
        
        params.push(limit, offset);
        
        const result = await pool.query(query, params);
        
        await logActivity('info', 'analytics', 'Trading signals consultados', {
            count: result.rows.length,
            filters: { commodity, signal_type, status }
        });

        sendResponse(res, result.rows);
    } catch (error) {
        console.error('Erro ao buscar sinais de trading:', error);
        await logActivity('error', 'analytics', 'Erro ao consultar trading signals', { error: error.message });
        sendResponse(res, null, `Erro: ${error.message}`);
    }
});

app.post('/api/analytics/trading-signals', async (req, res) => {
    try {
        const {
            commodity,
            signal_type,
            target_price,
            stop_loss,
            confidence,
            reasoning,
            valid_until,
            agent_id
        } = req.body;

        if (!commodity || !signal_type || !target_price) {
            return res.status(400).json({
                success: false,
                message: "Campos obrigatórios: commodity, signal_type, target_price"
            });
        }

        const result = await pool.query(`
            INSERT INTO trading_signals 
            (commodity, signal_type, target_price, stop_loss, confidence, reasoning, valid_until, agent_id)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
            RETURNING *
        `, [
            commodity.toUpperCase(),
            signal_type.toUpperCase(),
            target_price,
            stop_loss,
            confidence,
            reasoning,
            valid_until,
            agent_id
        ]);

        await logActivity('info', 'analytics', 'Novo sinal de trading criado', {
            id: result.rows[0].id,
            commodity,
            signal_type,
            target_price
        }, agent_id);

        res.status(201).json({
            success: true,
            message: "Sinal de trading criado com sucesso",
            data: result.rows[0]
        });
    } catch (error) {
        console.error('Erro ao criar sinal de trading:', error);
        await logActivity('error', 'analytics', 'Erro ao criar trading signal', { error: error.message });
        res.status(500).json({
            success: false,
            message: `Erro: ${error.message}`
        });
    }
});

// GET /api/analytics/summary - Resumo executivo
app.get('/api/analytics/summary', async (req, res) => {
    try {
        const { period = '30' } = req.query;
        
        const periodDays = parseInt(period);
        
        // Análises por commodity nos últimos N dias
        const analysesQuery = `
            SELECT commodity, COUNT(*) as total_analyses, AVG(confidence_score) as avg_confidence
            FROM market_analyses 
            WHERE created_at > NOW() - INTERVAL '${periodDays} days'
            GROUP BY commodity
            ORDER BY total_analyses DESC
        `;
        
        // Sinais ativos
        const signalsQuery = `
            SELECT signal_type, COUNT(*) as count
            FROM trading_signals 
            WHERE status = 'active' AND (valid_until IS NULL OR valid_until > NOW())
            GROUP BY signal_type
        `;
        
        // Relatórios de pesquisa recentes
        const reportsQuery = `
            SELECT COUNT(*) as total_reports, AVG(relevance_score) as avg_relevance
            FROM research_reports 
            WHERE created_at > NOW() - INTERVAL '${periodDays} days'
        `;

        const [analysesResult, signalsResult, reportsResult] = await Promise.all([
            pool.query(analysesQuery),
            pool.query(signalsQuery),
            pool.query(reportsQuery)
        ]);

        const summary = {
            period_days: periodDays,
            market_analyses: {
                by_commodity: analysesResult.rows,
                total: analysesResult.rows.reduce((sum, row) => sum + parseInt(row.total_analyses), 0)
            },
            trading_signals: {
                active_signals: signalsResult.rows,
                total_active: signalsResult.rows.reduce((sum, row) => sum + parseInt(row.count), 0)
            },
            research: {
                total_reports: parseInt(reportsResult.rows[0]?.total_reports || 0),
                avg_relevance: parseFloat(reportsResult.rows[0]?.avg_relevance || 0).toFixed(2)
            },
            generated_at: new Date().toISOString()
        };

        await logActivity('info', 'analytics', 'Summary executivo consultado', { period: periodDays });

        sendResponse(res, summary);
    } catch (error) {
        console.error('Erro ao gerar resumo:', error);
        await logActivity('error', 'analytics', 'Erro ao gerar summary', { error: error.message });
        sendResponse(res, null, `Erro: ${error.message}`);
    }
});

// POST /api/analytics/query - Consultas inteligentes
app.post('/api/analytics/query', async (req, res) => {
    try {
        const { query, query_type, processing_method = 'local', agent_id } = req.body;

        if (!query) {
            return res.status(400).json({
                success: false,
                message: "Campo obrigatório: query"
            });
        }

        // Simular processamento de consulta inteligente
        const startTime = Date.now();
        
        // Classificação básica de intent baseada em palavras-chave
        let intent_classification = { intent: 'general', confidence: 0.5 };
        
        if (query.toLowerCase().includes('preço') || query.toLowerCase().includes('cotação')) {
            intent_classification = { intent: 'price_inquiry', confidence: 0.8 };
        } else if (query.toLowerCase().includes('análise') || query.toLowerCase().includes('tendência')) {
            intent_classification = { intent: 'market_analysis', confidence: 0.75 };
        } else if (query.toLowerCase().includes('sinal') || query.toLowerCase().includes('trading')) {
            intent_classification = { intent: 'trading_signal', confidence: 0.7 };
        }

        // Buscar dados relevantes baseados no intent
        let results = {};
        let response_text = "Consulta processada com sucesso.";

        switch (intent_classification.intent) {
            case 'price_inquiry':
                const priceData = await pool.query(`
                    SELECT commodity, preco, variacao, data_coleta 
                    FROM dados_mercado 
                    ORDER BY data_coleta DESC 
                    LIMIT 5
                `);
                results = { prices: priceData.rows };
                response_text = `Encontrados dados de preço para ${priceData.rows.length} commodities.`;
                break;
                
            case 'market_analysis':
                const analysisData = await pool.query(`
                    SELECT commodity, analysis_type, confidence_score, created_at 
                    FROM market_analyses 
                    ORDER BY created_at DESC 
                    LIMIT 5
                `);
                results = { analyses: analysisData.rows };
                response_text = `Encontradas ${analysisData.rows.length} análises recentes de mercado.`;
                break;
                
            case 'trading_signal':
                const signalData = await pool.query(`
                    SELECT commodity, signal_type, target_price, confidence, created_at 
                    FROM trading_signals 
                    WHERE status = 'active'
                    ORDER BY created_at DESC 
                    LIMIT 5
                `);
                results = { signals: signalData.rows };
                response_text = `Encontrados ${signalData.rows.length} sinais de trading ativos.`;
                break;
                
            default:
                results = { message: "Consulta processada, mas não foram identificados dados específicos." };
        }

        const processingTime = (Date.now() - startTime) / 1000;

        // Salvar consulta no banco
        const savedQuery = await pool.query(`
            INSERT INTO query_analyses 
            (query, query_type, intent_classification, processing_method, results, 
             response_text, confidence, processing_time, agent_id)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
            RETURNING *
        `, [
            query,
            query_type,
            JSON.stringify(intent_classification),
            processing_method,
            JSON.stringify(results),
            response_text,
            intent_classification.confidence,
            processingTime,
            agent_id
        ]);

        await logActivity('info', 'analytics', 'Consulta inteligente processada', {
            query_id: savedQuery.rows[0].id,
            intent: intent_classification.intent,
            processing_time: processingTime
        }, agent_id);

        res.status(201).json({
            success: true,
            message: "Consulta processada com sucesso",
            data: {
                query_id: savedQuery.rows[0].id,
                intent_classification,
                results,
                response_text,
                processing_time: processingTime,
                timestamp: savedQuery.rows[0].created_at
            }
        });
    } catch (error) {
        console.error('Erro ao processar consulta:', error);
        await logActivity('error', 'analytics', 'Erro ao processar query', { error: error.message });
        res.status(500).json({
            success: false,
            message: `Erro: ${error.message}`
        });
    }
});

// =====================================================
// RESEARCH APIs
// =====================================================

// GET/POST /api/research/reports - Relatórios de pesquisa
app.get('/api/research/reports', async (req, res) => {
    try {
        const { page, limit, offset } = validatePagination(req);
        const { scope, topic } = req.query;
        
        let whereClause = 'WHERE 1=1';
        const params = [];
        
        if (scope) {
            whereClause += ` AND scope = $${params.length + 1}`;
            params.push(scope);
        }
        
        if (topic) {
            whereClause += ` AND topic ILIKE $${params.length + 1}`;
            params.push(`%${topic}%`);
        }

        const query = `
            SELECT id, topic, scope, key_findings, market_impact, sentiment_score,
                   relevance_score, created_at, agent_id
            FROM research_reports 
            ${whereClause}
            ORDER BY created_at DESC
            LIMIT $${params.length + 1} OFFSET $${params.length + 2}
        `;
        
        params.push(limit, offset);
        
        const result = await pool.query(query, params);
        
        await logActivity('info', 'research', 'Relatórios de pesquisa consultados', {
            count: result.rows.length,
            filters: { scope, topic }
        });

        sendResponse(res, result.rows);
    } catch (error) {
        console.error('Erro ao buscar relatórios:', error);
        await logActivity('error', 'research', 'Erro ao consultar research reports', { error: error.message });
        sendResponse(res, null, `Erro: ${error.message}`);
    }
});

app.post('/api/research/reports', async (req, res) => {
    try {
        const {
            topic,
            scope,
            sources,
            key_findings,
            market_impact,
            sentiment_score,
            relevance_score,
            raw_data,
            agent_id
        } = req.body;

        if (!topic || !key_findings) {
            return res.status(400).json({
                success: false,
                message: "Campos obrigatórios: topic, key_findings"
            });
        }

        const result = await pool.query(`
            INSERT INTO research_reports 
            (topic, scope, sources, key_findings, market_impact, sentiment_score, 
             relevance_score, raw_data, agent_id)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
            RETURNING *
        `, [
            topic,
            scope,
            sources ? JSON.stringify(sources) : null,
            key_findings,
            market_impact,
            sentiment_score,
            relevance_score,
            raw_data ? JSON.stringify(raw_data) : null,
            agent_id
        ]);

        await logActivity('info', 'research', 'Novo relatório de pesquisa criado', {
            id: result.rows[0].id,
            topic,
            scope
        }, agent_id);

        res.status(201).json({
            success: true,
            message: "Relatório de pesquisa criado com sucesso",
            data: result.rows[0]
        });
    } catch (error) {
        console.error('Erro ao criar relatório:', error);
        await logActivity('error', 'research', 'Erro ao criar research report', { error: error.message });
        res.status(500).json({
            success: false,
            message: `Erro: ${error.message}`
        });
    }
});

// POST /api/research/request - Solicitar pesquisa
app.post('/api/research/request', async (req, res) => {
    try {
        const { topic, scope, priority = 'normal', requested_by, agent_id } = req.body;

        if (!topic) {
            return res.status(400).json({
                success: false,
                message: "Campo obrigatório: topic"
            });
        }

        // Criar uma entrada de pesquisa solicitada (usando business_kpis temporariamente)
        const requestId = `research_${Date.now()}`;
        
        await logActivity('info', 'research', 'Nova pesquisa solicitada', {
            request_id: requestId,
            topic,
            scope,
            priority,
            requested_by
        }, agent_id);

        res.status(202).json({
            success: true,
            message: "Solicitação de pesquisa recebida e processada",
            data: {
                request_id: requestId,
                topic,
                scope,
                priority,
                status: 'queued',
                estimated_completion: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString() // 24h
            }
        });
    } catch (error) {
        console.error('Erro ao solicitar pesquisa:', error);
        await logActivity('error', 'research', 'Erro ao solicitar research', { error: error.message });
        res.status(500).json({
            success: false,
            message: `Erro: ${error.message}`
        });
    }
});

// GET /api/research/topics - Tópicos disponíveis
app.get('/api/research/topics', async (req, res) => {
    try {
        // Buscar tópicos únicos dos relatórios existentes
        const topicsQuery = `
            SELECT DISTINCT topic, scope, COUNT(*) as report_count,
                   AVG(relevance_score) as avg_relevance,
                   MAX(created_at) as last_report
            FROM research_reports 
            GROUP BY topic, scope
            ORDER BY report_count DESC, avg_relevance DESC
        `;
        
        const result = await pool.query(topicsQuery);
        
        // Tópicos sugeridos baseados no domínio agrícola
        const suggestedTopics = [
            { topic: "Análise Safra Soja", scope: "production_forecast", category: "commodities" },
            { topic: "Mercado Exportação Milho", scope: "trade_analysis", category: "trading" },
            { topic: "Impacto Climático Preços", scope: "risk_analysis", category: "climate" },
            { topic: "Tendências Consumo Interno", scope: "market_analysis", category: "demand" },
            { topic: "Logística Portuária", scope: "infrastructure", category: "logistics" },
            { topic: "Políticas Governamentais", scope: "regulatory_analysis", category: "policy" }
        ];

        const topics = {
            available_topics: result.rows,
            suggested_topics: suggestedTopics,
            categories: ['commodities', 'trading', 'climate', 'demand', 'logistics', 'policy'],
            scopes: ['production_forecast', 'trade_analysis', 'risk_analysis', 'market_analysis', 'infrastructure', 'regulatory_analysis']
        };

        await logActivity('info', 'research', 'Tópicos de pesquisa consultados');

        sendResponse(res, topics);
    } catch (error) {
        console.error('Erro ao buscar tópicos:', error);
        await logActivity('error', 'research', 'Erro ao consultar topics', { error: error.message });
        sendResponse(res, null, `Erro: ${error.message}`);
    }
});

// =====================================================
// OCR APIs
// =====================================================

// POST /api/ocr/upload - Upload documentos
app.post('/api/ocr/upload', upload.single('document'), async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({
                success: false,
                message: "Nenhum arquivo foi enviado"
            });
        }

        const { document_type, agent_id } = req.body;
        
        // Calcular hash do arquivo
        const fileBuffer = fs.readFileSync(req.file.path);
        const fileHash = crypto.createHash('md5').update(fileBuffer).digest('hex');
        
        // Verificar se arquivo já existe
        const existingFile = await pool.query(
            'SELECT id FROM ocr_documents WHERE file_hash = $1',
            [fileHash]
        );
        
        if (existingFile.rows.length > 0) {
            // Remover arquivo duplicado
            fs.unlinkSync(req.file.path);
            
            return res.json({
                success: true,
                message: "Arquivo já existe no sistema",
                data: { 
                    id: existingFile.rows[0].id,
                    status: 'duplicate'
                }
            });
        }

        // Salvar informações no banco
        const result = await pool.query(`
            INSERT INTO ocr_documents 
            (filename, file_path, file_hash, file_size, mime_type, document_type, 
             processing_status, agent_id)
            VALUES ($1, $2, $3, $4, $5, $6, 'uploaded', $7)
            RETURNING *
        `, [
            req.file.originalname,
            req.file.path,
            fileHash,
            req.file.size,
            req.file.mimetype,
            document_type || 'unknown',
            agent_id
        ]);

        await logActivity('info', 'ocr', 'Documento enviado para OCR', {
            id: result.rows[0].id,
            filename: req.file.originalname,
            size: req.file.size,
            type: document_type
        }, agent_id);

        res.status(201).json({
            success: true,
            message: "Documento enviado com sucesso",
            data: {
                id: result.rows[0].id,
                filename: result.rows[0].filename,
                file_hash: result.rows[0].file_hash,
                processing_status: result.rows[0].processing_status,
                created_at: result.rows[0].created_at
            }
        });
    } catch (error) {
        console.error('Erro no upload:', error);
        
        // Limpar arquivo em caso de erro
        if (req.file && fs.existsSync(req.file.path)) {
            fs.unlinkSync(req.file.path);
        }
        
        await logActivity('error', 'ocr', 'Erro no upload OCR', { error: error.message });
        res.status(500).json({
            success: false,
            message: `Erro: ${error.message}`
        });
    }
});

// POST /api/ocr/analyze - Análise OCR
app.post('/api/ocr/analyze', async (req, res) => {
    try {
        const { document_id, analysis_options, agent_id } = req.body;

        if (!document_id) {
            return res.status(400).json({
                success: false,
                message: "Campo obrigatório: document_id"
            });
        }

        // Buscar documento
        const docResult = await pool.query(
            'SELECT * FROM ocr_documents WHERE id = $1',
            [document_id]
        );

        if (docResult.rows.length === 0) {
            return res.status(404).json({
                success: false,
                message: "Documento não encontrado"
            });
        }

        const document = docResult.rows[0];

        // Simular processamento OCR
        const startTime = Date.now();
        
        // Marcar como processando
        await pool.query(
            'UPDATE ocr_documents SET processing_status = $1 WHERE id = $2',
            ['processing', document_id]
        );

        // Simular resultados OCR baseados no tipo de documento
        let ocrResults = {};
        let analysisResults = {};
        let extractedData = {};
        
        switch (document.document_type) {
            case 'price_list':
                ocrResults = {
                    text: "COTAÇÕES DIÁRIAS\nSOJA: R$ 145,50/saca\nMILHO: R$ 72,30/saca\nTRIGO: R$ 89,90/saca",
                    confidence: 0.92
                };
                extractedData = {
                    commodities: [
                        { name: "SOJA", price: 145.50, unit: "saca" },
                        { name: "MILHO", price: 72.30, unit: "saca" },
                        { name: "TRIGO", price: 89.90, unit: "saca" }
                    ],
                    date: new Date().toISOString().split('T')[0]
                };
                analysisResults = {
                    document_type: "price_list",
                    commodities_found: 3,
                    data_quality: "high"
                };
                break;
                
            case 'commodity_report':
                ocrResults = {
                    text: "RELATÓRIO DE ANÁLISE DE MERCADO\nTendência altista para soja\nVolume de negociação elevado",
                    confidence: 0.88
                };
                extractedData = {
                    analysis_type: "market_trend",
                    sentiment: "bullish",
                    confidence_level: "high"
                };
                analysisResults = {
                    document_type: "analysis_report",
                    insights_extracted: 2,
                    actionable_items: 1
                };
                break;
                
            default:
                ocrResults = {
                    text: "Documento processado com OCR genérico",
                    confidence: 0.75
                };
                extractedData = {
                    processed: true,
                    type: "generic"
                };
                analysisResults = {
                    document_type: "generic",
                    processing_method: "basic_ocr"
                };
        }

        const processingTime = (Date.now() - startTime) / 1000;

        // Atualizar documento com resultados
        const updatedDoc = await pool.query(`
            UPDATE ocr_documents 
            SET ocr_results = $1, analysis_results = $2, extracted_data = $3,
                processing_status = 'completed', processing_time = $4, processed_at = NOW()
            WHERE id = $5
            RETURNING *
        `, [
            JSON.stringify(ocrResults),
            JSON.stringify(analysisResults),
            JSON.stringify(extractedData),
            processingTime,
            document_id
        ]);

        await logActivity('info', 'ocr', 'Análise OCR concluída', {
            document_id,
            processing_time: processingTime,
            confidence: ocrResults.confidence
        }, agent_id);

        res.json({
            success: true,
            message: "Análise OCR concluída com sucesso",
            data: {
                document_id: document_id,
                ocr_results: ocrResults,
                analysis_results: analysisResults,
                extracted_data: extractedData,
                processing_time: processingTime,
                processed_at: updatedDoc.rows[0].processed_at
            }
        });
    } catch (error) {
        console.error('Erro na análise OCR:', error);
        
        // Marcar como erro em caso de falha
        if (req.body.document_id) {
            try {
                await pool.query(
                    'UPDATE ocr_documents SET processing_status = $1 WHERE id = $2',
                    ['error', req.body.document_id]
                );
            } catch (updateError) {
                console.error('Erro ao atualizar status:', updateError);
            }
        }
        
        await logActivity('error', 'ocr', 'Erro na análise OCR', { error: error.message });
        res.status(500).json({
            success: false,
            message: `Erro: ${error.message}`
        });
    }
});

// GET /api/ocr/results/:id - Resultados análise
app.get('/api/ocr/results/:id', async (req, res) => {
    try {
        const { id } = req.params;
        
        const result = await pool.query(
            'SELECT * FROM ocr_documents WHERE id = $1',
            [id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({
                success: false,
                message: "Documento não encontrado"
            });
        }

        const document = result.rows[0];

        await logActivity('info', 'ocr', 'Resultados OCR consultados', { document_id: id });

        res.json({
            success: true,
            message: "Resultados encontrados",
            data: {
                id: document.id,
                filename: document.filename,
                document_type: document.document_type,
                processing_status: document.processing_status,
                ocr_results: document.ocr_results,
                analysis_results: document.analysis_results,
                extracted_data: document.extracted_data,
                processing_time: document.processing_time,
                created_at: document.created_at,
                processed_at: document.processed_at
            }
        });
    } catch (error) {
        console.error('Erro ao buscar resultados OCR:', error);
        await logActivity('error', 'ocr', 'Erro ao consultar resultados OCR', { error: error.message });
        res.status(500).json({
            success: false,
            message: `Erro: ${error.message}`
        });
    }
});

// =====================================================
// AGENTS APIs
// =====================================================

// GET /api/agents/status - Status de todos agentes
app.get('/api/agents/status', async (req, res) => {
    try {
        const result = await pool.query(`
            SELECT agent_id, agent_name, agent_type, specialization, status,
                   current_task, capabilities, last_heartbeat, performance_metrics,
                   error_count, created_at, updated_at
            FROM agent_status
            ORDER BY 
                CASE status 
                    WHEN 'online' THEN 1 
                    WHEN 'offline' THEN 2 
                    WHEN 'error' THEN 3 
                    ELSE 4 
                END,
                last_heartbeat DESC
        `);

        const agentStats = {
            total_agents: result.rows.length,
            online: result.rows.filter(a => a.status === 'online').length,
            offline: result.rows.filter(a => a.status === 'offline').length,
            error: result.rows.filter(a => a.status === 'error').length,
            last_update: new Date().toISOString()
        };

        await logActivity('info', 'agents', 'Status dos agentes consultado', agentStats);

        sendResponse(res, {
            agents: result.rows,
            statistics: agentStats
        });
    } catch (error) {
        console.error('Erro ao buscar status dos agentes:', error);
        await logActivity('error', 'agents', 'Erro ao consultar agent status', { error: error.message });
        sendResponse(res, null, `Erro: ${error.message}`);
    }
});

// POST /api/agents/task - Atribuir tarefa
app.post('/api/agents/task', async (req, res) => {
    try {
        const { agent_id, task, priority = 'normal', assigned_by } = req.body;

        if (!agent_id || !task) {
            return res.status(400).json({
                success: false,
                message: "Campos obrigatórios: agent_id, task"
            });
        }

        // Verificar se agente existe e está online
        const agentResult = await pool.query(
            'SELECT * FROM agent_status WHERE agent_id = $1',
            [agent_id]
        );

        if (agentResult.rows.length === 0) {
            return res.status(404).json({
                success: false,
                message: "Agente não encontrado"
            });
        }

        const agent = agentResult.rows[0];

        if (agent.status !== 'online') {
            return res.status(400).json({
                success: false,
                message: `Agente está ${agent.status}, não pode receber tarefas`
            });
        }

        // Atualizar agente com nova tarefa
        const updatedAgent = await pool.query(`
            UPDATE agent_status 
            SET current_task = $1, updated_at = NOW()
            WHERE agent_id = $2
            RETURNING *
        `, [task, agent_id]);

        const taskId = `task_${Date.now()}_${agent_id}`;

        await logActivity('info', 'agents', 'Tarefa atribuída ao agente', {
            task_id: taskId,
            agent_id,
            task,
            priority,
            assigned_by
        }, agent_id);

        res.json({
            success: true,
            message: "Tarefa atribuída com sucesso",
            data: {
                task_id: taskId,
                agent_id,
                agent_name: agent.agent_name,
                task,
                priority,
                assigned_at: new Date().toISOString(),
                status: 'assigned'
            }
        });
    } catch (error) {
        console.error('Erro ao atribuir tarefa:', error);
        await logActivity('error', 'agents', 'Erro ao atribuir task', { error: error.message });
        res.status(500).json({
            success: false,
            message: `Erro: ${error.message}`
        });
    }
});

// GET /api/agents/performance - Performance
app.get('/api/agents/performance', async (req, res) => {
    try {
        const { period = '7' } = req.query;
        const periodDays = parseInt(period);

        // Performance dos agentes
        const performanceQuery = `
            SELECT 
                a.agent_id,
                a.agent_name,
                a.specialization,
                a.status,
                a.error_count,
                a.performance_metrics,
                COUNT(l.id) as activity_count,
                COUNT(CASE WHEN l.level = 'error' THEN 1 END) as error_log_count
            FROM agent_status a
            LEFT JOIN system_logs l ON a.agent_id = l.agent_id 
                AND l.timestamp > NOW() - INTERVAL '${periodDays} days'
            GROUP BY a.agent_id, a.agent_name, a.specialization, a.status, 
                     a.error_count, a.performance_metrics
            ORDER BY activity_count DESC
        `;

        const result = await pool.query(performanceQuery);

        // Calcular métricas agregadas
        const totalActivity = result.rows.reduce((sum, row) => sum + parseInt(row.activity_count), 0);
        const totalErrors = result.rows.reduce((sum, row) => sum + parseInt(row.error_log_count), 0);
        
        const performance = {
            period_days: periodDays,
            agents: result.rows.map(row => ({
                ...row,
                activity_count: parseInt(row.activity_count),
                error_log_count: parseInt(row.error_log_count),
                success_rate: row.activity_count > 0 
                    ? ((row.activity_count - row.error_log_count) / row.activity_count * 100).toFixed(2)
                    : '0.00'
            })),
            summary: {
                total_agents: result.rows.length,
                total_activity: totalActivity,
                total_errors: totalErrors,
                overall_success_rate: totalActivity > 0 
                    ? ((totalActivity - totalErrors) / totalActivity * 100).toFixed(2)
                    : '0.00'
            }
        };

        await logActivity('info', 'agents', 'Performance dos agentes consultada', { period: periodDays });

        sendResponse(res, performance);
    } catch (error) {
        console.error('Erro ao buscar performance:', error);
        await logActivity('error', 'agents', 'Erro ao consultar performance', { error: error.message });
        sendResponse(res, null, `Erro: ${error.message}`);
    }
});

// =====================================================
// SYSTEM APIs
// =====================================================

// GET /api/system/performance - Métricas sistema
app.get('/api/system/performance', async (req, res) => {
    try {
        const { period = '1' } = req.query;
        const periodHours = parseInt(period);

        // Métricas de performance do sistema
        const metricsQuery = `
            SELECT 
                metric_name,
                metric_type,
                AVG(value) as avg_value,
                MAX(value) as max_value,
                MIN(value) as min_value,
                COUNT(*) as sample_count,
                source_component
            FROM performance_metrics
            WHERE timestamp > NOW() - INTERVAL '${periodHours} hours'
            GROUP BY metric_name, metric_type, source_component
            ORDER BY metric_name, source_component
        `;

        // System stats básicos
        const systemStats = {
            uptime: process.uptime(),
            memory_usage: process.memoryUsage(),
            cpu_usage: process.cpuUsage(),
            timestamp: new Date().toISOString()
        };

        // Database stats
        const dbStats = await pool.query(`
            SELECT 
                COUNT(*) FILTER (WHERE pg_stat_activity.state = 'active') as active_connections,
                COUNT(*) as total_connections
            FROM pg_stat_activity 
            WHERE datname = current_database()
        `);

        const metricsResult = await pool.query(metricsQuery);

        const performance = {
            period_hours: periodHours,
            system_stats: systemStats,
            database_stats: dbStats.rows[0],
            performance_metrics: metricsResult.rows,
            collected_at: new Date().toISOString()
        };

        // Adicionar métrica atual
        await pool.query(`
            INSERT INTO performance_metrics (metric_name, metric_type, value, source_component)
            VALUES ('system_uptime', 'gauge', $1, 'backend_api')
        `, [systemStats.uptime]);

        await logActivity('info', 'system', 'Métricas de performance consultadas', { period: periodHours });

        sendResponse(res, performance);
    } catch (error) {
        console.error('Erro ao buscar performance do sistema:', error);
        await logActivity('error', 'system', 'Erro ao consultar system performance', { error: error.message });
        sendResponse(res, null, `Erro: ${error.message}`);
    }
});

// GET /api/system/logs - Logs sistema
app.get('/api/system/logs', async (req, res) => {
    try {
        const { page, limit, offset } = validatePagination(req);
        const { level, component, agent_id } = req.query;
        
        let whereClause = 'WHERE 1=1';
        const params = [];
        
        if (level) {
            whereClause += ` AND level = $${params.length + 1}`;
            params.push(level);
        }
        
        if (component) {
            whereClause += ` AND component = $${params.length + 1}`;
            params.push(component);
        }
        
        if (agent_id) {
            whereClause += ` AND agent_id = $${params.length + 1}`;
            params.push(agent_id);
        }

        const query = `
            SELECT id, level, component, agent_id, message, details, 
                   stack_trace, timestamp
            FROM system_logs 
            ${whereClause}
            ORDER BY timestamp DESC
            LIMIT $${params.length + 1} OFFSET $${params.length + 2}
        `;
        
        params.push(limit, offset);
        
        const result = await pool.query(query, params);
        
        // Contar total para paginação
        const countQuery = `SELECT COUNT(*) FROM system_logs ${whereClause}`;
        const countResult = await pool.query(countQuery, params.slice(0, -2));
        const total = parseInt(countResult.rows[0].count);

        sendResponse(res, result.rows, null, {
            pagination: {
                page,
                limit,
                total,
                pages: Math.ceil(total / limit)
            }
        });
    } catch (error) {
        console.error('Erro ao buscar logs:', error);
        await logActivity('error', 'system', 'Erro ao consultar system logs', { error: error.message });
        sendResponse(res, null, `Erro: ${error.message}`);
    }
});

// POST /api/system/config - Configurações
app.post('/api/system/config', async (req, res) => {
    try {
        const { config_key, config_value, description, updated_by } = req.body;

        if (!config_key || config_value === undefined) {
            return res.status(400).json({
                success: false,
                message: "Campos obrigatórios: config_key, config_value"
            });
        }

        // Usar business_kpis para armazenar configurações temporariamente
        const result = await pool.query(`
            INSERT INTO business_kpis (kpi_name, kpi_category, value, unit, calculation_method)
            VALUES ($1, 'system_config', $2, 'config', $3)
            ON CONFLICT (kpi_name) DO UPDATE SET 
                value = EXCLUDED.value,
                calculation_method = EXCLUDED.calculation_method,
                created_at = NOW()
            RETURNING *
        `, [config_key, parseFloat(config_value) || 0, description || 'System configuration']);

        await logActivity('info', 'system', 'Configuração atualizada', {
            config_key,
            updated_by
        });

        res.json({
            success: true,
            message: "Configuração atualizada com sucesso",
            data: {
                config_key,
                config_value,
                description,
                updated_at: result.rows[0].created_at
            }
        });
    } catch (error) {
        console.error('Erro ao atualizar configuração:', error);
        await logActivity('error', 'system', 'Erro ao atualizar config', { error: error.message });
        res.status(500).json({
            success: false,
            message: `Erro: ${error.message}`
        });
    }
});

// =====================================================
// ROTAS DE COMPATIBILIDADE (mantidas do backend original)
// =====================================================

// API Produtos
app.get('/api/produtos', async (req, res) => {
    try {
        const result = await pool.query(`
            SELECT id, nome, categoria, unidade_precificacao, ativo 
            FROM produtos 
            WHERE ativo = true 
            ORDER BY nome
        `);
        sendResponse(res, result.rows);
    } catch (error) {
        console.error('Erro ao buscar produtos:', error);
        sendResponse(res, null, `Erro: ${error.message}`);
    }
});

// API Ofertas
app.get('/api/offers', async (req, res) => {
    try {
        const result = await pool.query(`
            SELECT 
                o.id,
                o.pin_seq as pin,
                p.nome as commodity,
                o.quantidade_sacas60 as quantity,
                o.quantidade_ton,
                o.preco_unitario as price,
                o.modalidade,
                o.local_retirada_entrega as location,
                o.status,
                o.created_at,
                p.categoria,
                p.unidade_precificacao as unit
            FROM ofertas o
            JOIN produtos p ON o.produto_id = p.id
            WHERE o.status = 'aberta'
            ORDER BY o.created_at DESC
        `);

        if (result.rows.length === 0) {
            return sendResponse(res, null);
        }

        const formattedOffers = result.rows.map(row => ({
            id: row.id,
            pin: row.pin,
            commodity: row.commodity,
            price: parseFloat(row.price),
            quantity: row.quantity || row.quantidade_ton || 0,
            quality: row.categoria === 'graos' ? 'Premium' : 'Standard',
            location: row.location,
            phone: "Contato via WhatsApp",
            whatsapp: "+55 65 9999-9999",
            unit: row.unit,
            status: row.status,
            created_at: row.created_at
        }));

        sendResponse(res, formattedOffers);
    } catch (error) {
        console.error('Erro ao buscar ofertas:', error);
        sendResponse(res, null, `Erro: ${error.message}`);
    }
});

// API Dados de Mercado
app.get('/api/market-data', async (req, res) => {
    try {
        const result = await pool.query(`
            SELECT 
                commodity,
                preco,
                variacao,
                volume,
                fonte,
                regiao,
                tendencia,
                data_coleta
            FROM dados_mercado
            ORDER BY data_coleta DESC
            LIMIT 50
        `);
        sendResponse(res, result.rows);
    } catch (error) {
        console.error('Erro ao buscar dados de mercado:', error);
        sendResponse(res, null, `Erro: ${error.message}`);
    }
});

// =====================================================
// TRATAMENTO DE ERROS E INICIALIZAÇÃO
// =====================================================

// Middleware de tratamento de erros
app.use((error, req, res, next) => {
    console.error('Erro não tratado:', error);
    logActivity('error', 'system', 'Erro não tratado', { 
        error: error.message, 
        stack: error.stack,
        url: req.url,
        method: req.method
    });
    
    res.status(500).json({
        success: false,
        message: "Erro interno do servidor",
        error: error.message
    });
});


// Tratamento de erros de conexão
pool.on('error', (err) => {
    console.error('Erro no pool PostgreSQL:', err);
    logActivity('error', 'database', 'Erro no pool PostgreSQL', { error: err.message });
});

// =====================================================
// WHATSAPP EVOLUTION API - INTEGRAÇÃO COMPLETA
// =====================================================

const axios = require('axios');

// Configurações Evolution API
const EVO_URL = process.env.EVO_URL || process.env.EVOLUTION_API_URL || 'http://localhost:8080';
const EVO_APIKEY = process.env.EVO_APIKEY || process.env.EVOLUTION_API_KEY || '';
const EVO_WEBHOOK_TOKEN = process.env.EVO_WEBHOOK_TOKEN || process.env.EVOLUTION_WEBHOOK_TOKEN || '';

// Headers padrão para requisições Evolution API
const getEvoHeaders = () => ({
    'apikey': EVO_APIKEY,
    'Content-Type': 'application/json'
});

// Função auxiliar para chamadas à Evolution API
async function callEvolutionAPI(endpoint, method = 'GET', data = null) {
    try {
        const config = {
            method,
            url: `${EVO_URL}${endpoint}`,
            headers: getEvoHeaders(),
            ...(data && { data })
        };
        
        const response = await axios(config);
        return { success: true, data: response.data };
    } catch (error) {
        console.error(`Evolution API Error [${method} ${endpoint}]:`, error.response?.data || error.message);
        
        // Modo demonstração quando Evolution API não está disponível
        if (error.code === 'ECONNREFUSED') {
            return handleDemoMode(endpoint, method, data);
        }
        
        return { 
            success: false, 
            error: error.response?.data || { message: error.message }
        };
    }
}

// Modo demonstração para quando Evolution API não está disponível
function handleDemoMode(endpoint, method, data) {
    console.log(`[DEMO MODE] Simulating ${method} ${endpoint}`);
    
    // Simular respostas baseadas no endpoint
    if (endpoint === '/instance/fetchInstances') {
        return {
            success: true,
            data: [
                {
                    instanceName: 'spr-demo',
                    status: 'disconnected',
                    serverUrl: 'localhost:8080',
                    apikey: 'demo-key'
                },
                {
                    instanceName: 'spr-principal',
                    status: 'disconnected', 
                    serverUrl: 'localhost:8080',
                    apikey: 'demo-key'
                }
            ]
        };
    }
    
    if (endpoint === '/instance/create' && method === 'POST') {
        const instanceName = data?.instanceName || 'demo-instance';
        return {
            success: true,
            data: {
                instanceName,
                status: 'created',
                qrcode: data?.qrcode || false,
                message: `Instância ${instanceName} criada em modo demonstração`
            }
        };
    }
    
    if (endpoint.includes('/instance/connect/')) {
        const instanceName = endpoint.split('/').pop();
        return {
            success: true,
            data: {
                instanceName,
                status: 'connecting',
                qrcode: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==',
                message: 'QR Code gerado em modo demonstração'
            }
        };
    }
    
    if (endpoint.includes('/message/sendText/')) {
        return {
            success: true,
            data: {
                messageId: 'demo-msg-' + Date.now(),
                status: 'sent',
                message: 'Mensagem enviada em modo demonstração'
            }
        };
    }
    
    if (endpoint.includes('/chat/findChats/')) {
        return {
            success: true,
            data: [
                {
                    id: '5511999887766@s.whatsapp.net',
                    name: 'Cliente Demo SPR',
                    lastMessage: 'Olá! Como posso ajudar?',
                    timestamp: Date.now(),
                    unreadCount: 2
                },
                {
                    id: '5511888776655@s.whatsapp.net', 
                    name: 'Fornecedor Soja',
                    lastMessage: 'Temos nova cotação disponível',
                    timestamp: Date.now() - 3600000,
                    unreadCount: 0
                }
            ]
        };
    }
    
    if (endpoint.includes('/chat/findContacts/')) {
        return {
            success: true,
            data: [
                {
                    id: '5511999887766@s.whatsapp.net',
                    name: 'Cliente Demo SPR',
                    profilePic: '',
                    isGroup: false
                },
                {
                    id: '5511888776655@s.whatsapp.net',
                    name: 'Fornecedor Soja', 
                    profilePic: '',
                    isGroup: false
                },
                {
                    id: '5511777665544@s.whatsapp.net',
                    name: 'Cooperativa MT',
                    profilePic: '',
                    isGroup: false
                }
            ]
        };
    }
    
    // Resposta padrão para outros endpoints
    return {
        success: true,
        data: {
            message: 'Operação simulada em modo demonstração',
            demoMode: true,
            timestamp: new Date().toISOString()
        }
    };
}

// =====================================================
// WHATSAPP - HEALTH & STATUS APIs
// =====================================================

app.get('/api/whatsapp/health', async (req, res) => {
    try {
        await logActivity('info', 'whatsapp', 'Health check solicitado');
        
        const healthCheck = await callEvolutionAPI('/health');
        
        res.json({
            success: true,
            message: "WhatsApp service health check",
            data: {
                ok: healthCheck.success,
                service: "whatsapp",
                evolution_api: healthCheck.success ? "online" : "offline",
                url: EVO_URL,
                timestamp: new Date().toISOString()
            }
        });
        
    } catch (error) {
        console.error('Erro no health check WhatsApp:', error);
        res.status(500).json({
            success: false,
            message: "Erro no health check WhatsApp",
            error: error.message
        });
    }
});

app.get('/api/whatsapp/config', async (req, res) => {
    try {
        res.json({
            success: true,
            message: "Configurações WhatsApp",
            data: {
                evolution_url: EVO_URL,
                has_api_key: !!EVO_APIKEY,
                has_webhook_token: !!EVO_WEBHOOK_TOKEN,
                webhook_url: `http://localhost:${PORT}/api/whatsapp/webhook`
            }
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: "Erro ao obter configurações",
            error: error.message
        });
    }
});

// =====================================================
// WHATSAPP - INSTANCE MANAGEMENT APIs
// =====================================================

app.post('/api/whatsapp/instance', async (req, res) => {
    try {
        const { instanceName, token, qrcode = true } = req.body;
        
        if (!instanceName) {
            return res.status(400).json({
                success: false,
                message: "Nome da instância é obrigatório"
            });
        }

        await logActivity('info', 'whatsapp', 'Criando instância WhatsApp', { instanceName });

        const result = await callEvolutionAPI('/instance/create', 'POST', {
            instanceName,
            token,
            qrcode
        });

        if (result.success) {
            res.status(201).json({
                success: true,
                message: "Instância criada com sucesso",
                data: result.data
            });
        } else {
            res.status(400).json({
                success: false,
                message: "Erro ao criar instância",
                error: result.error
            });
        }

    } catch (error) {
        console.error('Erro ao criar instância:', error);
        res.status(500).json({
            success: false,
            message: "Erro interno ao criar instância",
            error: error.message
        });
    }
});

app.get('/api/whatsapp/instance/:instanceName', async (req, res) => {
    try {
        const { instanceName } = req.params;
        
        const result = await callEvolutionAPI(`/instance/fetchInstances?instanceName=${instanceName}`);
        
        res.json({
            success: result.success,
            message: result.success ? "Instância encontrada" : "Erro ao buscar instância",
            data: result.data,
            error: result.error
        });
        
    } catch (error) {
        res.status(500).json({
            success: false,
            message: "Erro ao buscar instância",
            error: error.message
        });
    }
});

app.get('/api/whatsapp/instances', async (req, res) => {
    try {
        await logActivity('info', 'whatsapp', 'Listando instâncias WhatsApp');
        
        const result = await callEvolutionAPI('/instance/fetchInstances');
        
        res.json({
            success: result.success,
            message: result.success ? "Instâncias listadas com sucesso" : "Erro ao listar instâncias",
            data: result.data || [],
            error: result.error
        });
        
    } catch (error) {
        res.status(500).json({
            success: false,
            message: "Erro ao listar instâncias",
            error: error.message
        });
    }
});

app.delete('/api/whatsapp/instance/:instanceName', async (req, res) => {
    try {
        const { instanceName } = req.params;
        
        await logActivity('info', 'whatsapp', 'Deletando instância WhatsApp', { instanceName });
        
        const result = await callEvolutionAPI(`/instance/delete/${instanceName}`, 'DELETE');
        
        res.json({
            success: result.success,
            message: result.success ? "Instância deletada com sucesso" : "Erro ao deletar instância",
            data: result.data,
            error: result.error
        });
        
    } catch (error) {
        res.status(500).json({
            success: false,
            message: "Erro ao deletar instância",
            error: error.message
        });
    }
});

// =====================================================
// WHATSAPP - CONNECTION & QR CODE APIs
// =====================================================

app.get('/api/whatsapp/instance/:instanceName/qrcode', async (req, res) => {
    try {
        const { instanceName } = req.params;
        
        await logActivity('info', 'whatsapp', 'Solicitando QR Code', { instanceName });
        
        const result = await callEvolutionAPI(`/instance/connect/${instanceName}`, 'GET');
        
        res.json({
            success: result.success,
            message: result.success ? "QR Code gerado" : "Erro ao gerar QR Code",
            data: result.data,
            error: result.error
        });
        
    } catch (error) {
        res.status(500).json({
            success: false,
            message: "Erro ao gerar QR Code",
            error: error.message
        });
    }
});

app.post('/api/whatsapp/instance/:instanceName/connect', async (req, res) => {
    try {
        const { instanceName } = req.params;
        
        const result = await callEvolutionAPI(`/instance/connect/${instanceName}`, 'GET');
        
        res.json({
            success: result.success,
            message: result.success ? "Conectando instância" : "Erro ao conectar",
            data: result.data,
            error: result.error
        });
        
    } catch (error) {
        res.status(500).json({
            success: false,
            message: "Erro ao conectar instância",
            error: error.message
        });
    }
});

app.post('/api/whatsapp/instance/:instanceName/logout', async (req, res) => {
    try {
        const { instanceName } = req.params;
        
        await logActivity('info', 'whatsapp', 'Desconectando instância', { instanceName });
        
        const result = await callEvolutionAPI(`/instance/logout/${instanceName}`, 'DELETE');
        
        res.json({
            success: result.success,
            message: result.success ? "Instância desconectada" : "Erro ao desconectar",
            data: result.data,
            error: result.error
        });
        
    } catch (error) {
        res.status(500).json({
            success: false,
            message: "Erro ao desconectar instância",
            error: error.message
        });
    }
});

// =====================================================
// WHATSAPP - MESSAGE APIs
// =====================================================

app.post('/api/whatsapp/message/send', async (req, res) => {
    try {
        const { instanceName, number, message, options = {} } = req.body;
        
        if (!instanceName || !number || !message) {
            return res.status(400).json({
                success: false,
                message: "instanceName, number e message são obrigatórios"
            });
        }

        await logActivity('info', 'whatsapp', 'Enviando mensagem', { 
            instanceName, 
            number: number.substring(0, 5) + '***' 
        });

        const messageData = {
            number,
            options: {
                delay: options.delay || 1200,
                presence: options.presence || 'composing',
                linkPreview: options.linkPreview !== false
            },
            textMessage: {
                text: message
            }
        };

        const result = await callEvolutionAPI(`/message/sendText/${instanceName}`, 'POST', messageData);
        
        res.json({
            success: result.success,
            message: result.success ? "Mensagem enviada com sucesso" : "Erro ao enviar mensagem",
            data: result.data,
            error: result.error
        });
        
    } catch (error) {
        console.error('Erro ao enviar mensagem:', error);
        res.status(500).json({
            success: false,
            message: "Erro interno ao enviar mensagem",
            error: error.message
        });
    }
});

app.post('/api/whatsapp/message/send-media', async (req, res) => {
    try {
        const { instanceName, number, media, caption, mediatype } = req.body;
        
        if (!instanceName || !number || !media) {
            return res.status(400).json({
                success: false,
                message: "instanceName, number e media são obrigatórios"
            });
        }

        const mediaData = {
            number,
            options: {
                delay: 1200,
                presence: 'composing'
            },
            mediaMessage: {
                mediatype: mediatype || 'image',
                media,
                ...(caption && { caption })
            }
        };

        const result = await callEvolutionAPI(`/message/sendMedia/${instanceName}`, 'POST', mediaData);
        
        res.json({
            success: result.success,
            message: result.success ? "Mídia enviada com sucesso" : "Erro ao enviar mídia",
            data: result.data,
            error: result.error
        });
        
    } catch (error) {
        res.status(500).json({
            success: false,
            message: "Erro ao enviar mídia",
            error: error.message
        });
    }
});

app.get('/api/whatsapp/messages/:instanceName', async (req, res) => {
    try {
        const { instanceName } = req.params;
        const { page = 1, limit = 20, where } = req.query;
        
        const queryParams = new URLSearchParams({
            page,
            limit,
            ...(where && { where })
        });
        
        const result = await callEvolutionAPI(`/chat/findMessages/${instanceName}?${queryParams}`);
        
        res.json({
            success: result.success,
            message: result.success ? "Mensagens obtidas" : "Erro ao obter mensagens",
            data: result.data || [],
            error: result.error
        });
        
    } catch (error) {
        res.status(500).json({
            success: false,
            message: "Erro ao obter mensagens",
            error: error.message
        });
    }
});

// =====================================================
// WHATSAPP - CHAT & CONTACT APIs
// =====================================================

app.get('/api/whatsapp/chats/:instanceName', async (req, res) => {
    try {
        const { instanceName } = req.params;
        
        const result = await callEvolutionAPI(`/chat/findChats/${instanceName}`);
        
        res.json({
            success: result.success,
            message: result.success ? "Chats obtidos" : "Erro ao obter chats",
            data: result.data || [],
            error: result.error
        });
        
    } catch (error) {
        res.status(500).json({
            success: false,
            message: "Erro ao obter chats",
            error: error.message
        });
    }
});

app.get('/api/whatsapp/contacts/:instanceName', async (req, res) => {
    try {
        const { instanceName } = req.params;
        
        const result = await callEvolutionAPI(`/chat/findContacts/${instanceName}`);
        
        res.json({
            success: result.success,
            message: result.success ? "Contatos obtidos" : "Erro ao obter contatos",
            data: result.data || [],
            error: result.error
        });
        
    } catch (error) {
        res.status(500).json({
            success: false,
            message: "Erro ao obter contatos",
            error: error.message
        });
    }
});

app.get('/api/whatsapp/profile/:instanceName', async (req, res) => {
    try {
        const { instanceName } = req.params;
        
        const result = await callEvolutionAPI(`/chat/whatsappProfile/${instanceName}`);
        
        res.json({
            success: result.success,
            message: result.success ? "Perfil obtido" : "Erro ao obter perfil",
            data: result.data,
            error: result.error
        });
        
    } catch (error) {
        res.status(500).json({
            success: false,
            message: "Erro ao obter perfil",
            error: error.message
        });
    }
});

// =====================================================
// WHATSAPP - GROUP APIs
// =====================================================

app.post('/api/whatsapp/group/create', async (req, res) => {
    try {
        const { instanceName, subject, participants } = req.body;
        
        if (!instanceName || !subject || !participants || !Array.isArray(participants)) {
            return res.status(400).json({
                success: false,
                message: "instanceName, subject e participants (array) são obrigatórios"
            });
        }

        const groupData = {
            subject,
            participants
        };

        const result = await callEvolutionAPI(`/group/create/${instanceName}`, 'POST', groupData);
        
        res.json({
            success: result.success,
            message: result.success ? "Grupo criado com sucesso" : "Erro ao criar grupo",
            data: result.data,
            error: result.error
        });
        
    } catch (error) {
        res.status(500).json({
            success: false,
            message: "Erro ao criar grupo",
            error: error.message
        });
    }
});

app.get('/api/whatsapp/groups/:instanceName', async (req, res) => {
    try {
        const { instanceName } = req.params;
        
        const result = await callEvolutionAPI(`/group/fetchAllGroups/${instanceName}`);
        
        res.json({
            success: result.success,
            message: result.success ? "Grupos obtidos" : "Erro ao obter grupos",
            data: result.data || [],
            error: result.error
        });
        
    } catch (error) {
        res.status(500).json({
            success: false,
            message: "Erro ao obter grupos",
            error: error.message
        });
    }
});

// =====================================================
// WHATSAPP - WEBHOOK APIs
// =====================================================

app.post('/api/whatsapp/webhook', async (req, res) => {
    try {
        const webhookData = req.body;
        
        // Log do webhook recebido
        await logActivity('info', 'whatsapp', 'Webhook recebido', {
            event: webhookData.event,
            instance: webhookData.instance,
            data_type: typeof webhookData.data
        });
        
        // Processar diferentes tipos de eventos
        switch (webhookData.event) {
            case 'messages.upsert':
                await processNewMessage(webhookData);
                break;
            case 'connection.update':
                await processConnectionUpdate(webhookData);
                break;
            case 'qrcode.updated':
                await processQrCodeUpdate(webhookData);
                break;
            default:
                console.log(`Evento não processado: ${webhookData.event}`);
        }
        
        res.json({ success: true, message: "Webhook processado" });
        
    } catch (error) {
        console.error('Erro no webhook:', error);
        res.status(500).json({
            success: false,
            message: "Erro ao processar webhook",
            error: error.message
        });
    }
});

// Funções auxiliares para processar webhooks
async function processNewMessage(webhookData) {
    try {
        const { instance, data } = webhookData;
        
        if (data && data.messages && data.messages.length > 0) {
            const message = data.messages[0];
            
            // Salvar mensagem no banco (implementar tabela se necessário)
            await logActivity('info', 'whatsapp', 'Nova mensagem recebida', {
                instance,
                from: message.key?.remoteJid,
                messageType: message.messageType,
                timestamp: message.messageTimestamp
            });
            
            // Processar comandos específicos do SPR
            await processSPRCommands(instance, message);
        }
    } catch (error) {
        console.error('Erro ao processar nova mensagem:', error);
    }
}

async function processConnectionUpdate(webhookData) {
    try {
        const { instance, data } = webhookData;
        
        await logActivity('info', 'whatsapp', 'Atualização de conexão', {
            instance,
            state: data?.state,
            isNewLogin: data?.isNewLogin
        });
        
    } catch (error) {
        console.error('Erro ao processar atualização de conexão:', error);
    }
}

async function processQrCodeUpdate(webhookData) {
    try {
        const { instance, data } = webhookData;
        
        await logActivity('info', 'whatsapp', 'QR Code atualizado', {
            instance,
            hasQrCode: !!data?.qrcode
        });
        
    } catch (error) {
        console.error('Erro ao processar QR Code:', error);
    }
}

// =====================================================
// WHATSAPP - SPR SPECIFIC FEATURES
// =====================================================

async function processSPRCommands(instance, message) {
    try {
        if (!message.message?.conversation && !message.message?.extendedTextMessage?.text) {
            return;
        }
        
        const text = message.message.conversation || message.message.extendedTextMessage?.text || '';
        const from = message.key?.remoteJid;
        
        // Comandos específicos do SPR
        if (text.toLowerCase().startsWith('/spr')) {
            const command = text.toLowerCase().split(' ')[1];
            
            switch (command) {
                case 'precos':
                    await sendMarketPrices(instance, from);
                    break;
                case 'ofertas':
                    await sendActiveOffers(instance, from);
                    break;
                case 'alertas':
                    await sendPriceAlerts(instance, from);
                    break;
                case 'help':
                default:
                    await sendSPRHelp(instance, from);
                    break;
            }
        }
        
    } catch (error) {
        console.error('Erro ao processar comandos SPR:', error);
    }
}

async function sendMarketPrices(instance, number) {
    try {
        // Buscar preços atuais do banco
        const prices = await pool.query(`
            SELECT commodity, price, variation, region, last_updated 
            FROM dados_mercado 
            ORDER BY last_updated DESC 
            LIMIT 10
        `);
        
        let message = '📊 *PREÇOS DE COMMODITIES - SPR*\n\n';
        
        if (prices.rows.length > 0) {
            prices.rows.forEach(row => {
                const variation = row.variation > 0 ? `+${row.variation}%` : `${row.variation}%`;
                message += `🌱 *${row.commodity}*: R$ ${row.price}\n`;
                message += `   📈 ${variation} | ${row.region}\n\n`;
            });
        } else {
            message += 'Nenhum dado disponível no momento.';
        }
        
        message += '\n💼 *Sistema Preditivo Royal*';
        
        await sendMessage(instance, number, message);
        
    } catch (error) {
        console.error('Erro ao enviar preços:', error);
    }
}

async function sendActiveOffers(instance, number) {
    try {
        const offers = await pool.query(`
            SELECT o.*, p.nome as produto_nome
            FROM ofertas o
            JOIN produtos p ON o.produto_id = p.id
            WHERE o.status = 'ativa'
            ORDER BY o.data_criacao DESC
            LIMIT 5
        `);
        
        let message = '💼 *OFERTAS ATIVAS - SPR*\n\n';
        
        if (offers.rows.length > 0) {
            offers.rows.forEach(offer => {
                message += `📦 *${offer.produto_nome}*\n`;
                message += `💰 R$ ${offer.preco}/ton\n`;
                message += `📍 ${offer.regiao}\n`;
                message += `📦 ${offer.quantidade} toneladas\n\n`;
            });
        } else {
            message += 'Nenhuma oferta ativa no momento.';
        }
        
        message += '\n💼 *Sistema Preditivo Royal*';
        
        await sendMessage(instance, number, message);
        
    } catch (error) {
        console.error('Erro ao enviar ofertas:', error);
    }
}

async function sendPriceAlerts(instance, number) {
    try {
        // Buscar alertas de preço (implementar sistema de alertas)
        let message = '🚨 *ALERTAS DE PREÇO - SPR*\n\n';
        message += '📈 Soja: Tendência de alta nas próximas 48h\n';
        message += '📊 Milho: Preços estáveis\n';
        message += '🌦️ Clima: Chuvas previstas para MT\n\n';
        message += 'Para alertas personalizados, entre em contato.\n\n';
        message += '💼 *Sistema Preditivo Royal*';
        
        await sendMessage(instance, number, message);
        
    } catch (error) {
        console.error('Erro ao enviar alertas:', error);
    }
}

async function sendSPRHelp(instance, number) {
    try {
        let message = '🤖 *COMANDOS SPR WHATSAPP*\n\n';
        message += '/spr precos - Preços atuais de commodities\n';
        message += '/spr ofertas - Ofertas ativas no sistema\n';
        message += '/spr alertas - Alertas de mercado\n';
        message += '/spr help - Esta mensagem de ajuda\n\n';
        message += '📱 *Sistema Preditivo Royal*\n';
        message += 'Conectando o agronegócio através da tecnologia.';
        
        await sendMessage(instance, number, message);
        
    } catch (error) {
        console.error('Erro ao enviar ajuda:', error);
    }
}

async function sendMessage(instance, number, message) {
    try {
        const messageData = {
            number,
            options: {
                delay: 1200,
                presence: 'composing'
            },
            textMessage: {
                text: message
            }
        };
        
        await callEvolutionAPI(`/message/sendText/${instance}`, 'POST', messageData);
        
    } catch (error) {
        console.error('Erro ao enviar mensagem SPR:', error);
    }
}

// =====================================================
// WHATSAPP - WEBHOOK SETTINGS
// =====================================================

app.post('/api/whatsapp/webhook/set/:instanceName', async (req, res) => {
    try {
        const { instanceName } = req.params;
        const { url, events, webhook_by_events } = req.body;
        
        const webhookData = {
            url: url || `http://localhost:${PORT}/api/whatsapp/webhook`,
            webhook_by_events: webhook_by_events !== false,
            webhook_base64: false,
            events: events || [
                'APPLICATION_STARTUP',
                'QRCODE_UPDATED',
                'MESSAGES_UPSERT',
                'MESSAGES_UPDATE',
                'MESSAGES_DELETE',
                'SEND_MESSAGE',
                'CONTACTS_SET',
                'CONTACTS_UPSERT',
                'PRESENCE_UPDATE',
                'CHATS_SET',
                'CHATS_UPSERT',
                'CHATS_UPDATE',
                'CHATS_DELETE',
                'GROUPS_UPSERT',
                'GROUP_UPDATE',
                'GROUP_PARTICIPANTS_UPDATE',
                'CONNECTION_UPDATE'
            ]
        };
        
        const result = await callEvolutionAPI(`/webhook/set/${instanceName}`, 'POST', webhookData);
        
        res.json({
            success: result.success,
            message: result.success ? "Webhook configurado" : "Erro ao configurar webhook",
            data: result.data,
            error: result.error
        });
        
    } catch (error) {
        res.status(500).json({
            success: false,
            message: "Erro ao configurar webhook",
            error: error.message
        });
    }
});

app.get('/api/whatsapp/webhook/:instanceName', async (req, res) => {
    try {
        const { instanceName } = req.params;
        
        const result = await callEvolutionAPI(`/webhook/find/${instanceName}`);
        
        res.json({
            success: result.success,
            message: result.success ? "Webhook encontrado" : "Erro ao buscar webhook",
            data: result.data,
            error: result.error
        });
        
    } catch (error) {
        res.status(500).json({
            success: false,
            message: "Erro ao buscar webhook",
            error: error.message
        });
    }
});

// Tratamento de rotas não encontradas
app.use('*', (req, res) => {
    res.status(404).json({
        success: false,
        message: `Rota não encontrada: ${req.method} ${req.originalUrl}`,
        available_endpoints: [
            "GET /api/status",
            "GET /api/analytics/market",
            "POST /api/analytics/market",
            "GET /api/analytics/trading-signals",
            "POST /api/analytics/trading-signals", 
            "GET /api/analytics/summary",
            "POST /api/analytics/query",
            "GET /api/research/reports",
            "POST /api/research/reports",
            "POST /api/research/request",
            "GET /api/research/topics",
            "POST /api/ocr/upload",
            "POST /api/ocr/analyze",
            "GET /api/ocr/results/:id",
            "GET /api/agents/status",
            "POST /api/agents/task",
            "GET /api/agents/performance",
            "GET /api/system/performance",
            "GET /api/system/logs",
            "POST /api/system/config",
            "GET /api/whatsapp/health",
            "GET /api/whatsapp/config",
            "POST /api/whatsapp/instance",
            "GET /api/whatsapp/instance/:instanceName",
            "GET /api/whatsapp/instances",
            "DELETE /api/whatsapp/instance/:instanceName",
            "GET /api/whatsapp/instance/:instanceName/qrcode",
            "POST /api/whatsapp/instance/:instanceName/connect",
            "POST /api/whatsapp/instance/:instanceName/logout",
            "POST /api/whatsapp/message/send",
            "POST /api/whatsapp/message/send-media",
            "GET /api/whatsapp/messages/:instanceName",
            "GET /api/whatsapp/chats/:instanceName",
            "GET /api/whatsapp/contacts/:instanceName",
            "GET /api/whatsapp/profile/:instanceName",
            "POST /api/whatsapp/group/create",
            "GET /api/whatsapp/groups/:instanceName",
            "POST /api/whatsapp/webhook",
            "POST /api/whatsapp/webhook/set/:instanceName",
            "GET /api/whatsapp/webhook/:instanceName"
        ]
    });
});

// Iniciar servidor
app.listen(PORT, async () => {
    console.log(`🚀 SPR Backend Extended rodando na porta ${PORT}`);
    console.log(`📊 Banco: PostgreSQL spr_db`);
    console.log(`🔗 URL: http://localhost:${PORT}`);
    console.log(`📚 APIs: Analytics, Research, OCR, Agents, System, WhatsApp`);
    
    // Teste de conexão inicial
    try {
        await pool.query('SELECT 1');
        console.log('✅ PostgreSQL conectado com sucesso');
        
        // Log inicial do sistema
        await logActivity('info', 'system', 'SPR Backend Extended iniciado', {
            port: PORT,
            version: '2.0.0',
            modules: ['Analytics', 'Research', 'OCR', 'Agents', 'System', 'WhatsApp']
        });
        
        // Atualizar heartbeat dos agentes (se existirem)
        try {
            await pool.query(`
                UPDATE agent_status 
                SET last_heartbeat = NOW() 
                WHERE agent_id = 'spr_backend_api'
            `);
        } catch (heartbeatError) {
            // Não é crítico se não existir o agente
        }
        
    } catch (err) {
        console.error('❌ Erro na conexão PostgreSQL:', err.message);
    }
});

// Graceful shutdown
process.on('SIGINT', async () => {
    console.log('\n🛑 Encerrando servidor...');
    
    try {
        await logActivity('info', 'system', 'SPR Backend Extended sendo encerrado');
        await pool.end();
        console.log('✅ Pool de conexões encerrado');
    } catch (error) {
        console.error('❌ Erro no shutdown:', error);
    }
    
    process.exit(0);
});

// Tratamento de exceções não capturadas
process.on('unhandledRejection', (reason, promise) => {
    console.error('Unhandled Rejection at:', promise, 'reason:', reason);
    logActivity('error', 'system', 'Unhandled promise rejection', { 
        reason: reason.toString() 
    });
});

process.on('uncaughtException', (error) => {
    console.error('Uncaught Exception:', error);
    logActivity('error', 'system', 'Uncaught exception', { 
        error: error.message,
        stack: error.stack 
    });
    process.exit(1);
});

module.exports = app;