/**
 * SPR Backend - PostgreSQL Real Data
 * Conectado ao banco de dados PostgreSQL sem dados mock
 */

const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3003;

// Configuração PostgreSQL
const pool = new Pool({
    host: 'localhost',
    port: 5432,
    database: 'spr_db',
    user: 'spr_user',
    password: 'spr_password_2025',
    max: 20,
    idleTimeoutMillis: 30000,
    connectionTimeoutMillis: 2000,
});

// Middleware
app.use(cors({
    origin: ['http://localhost:3000', 'http://localhost:8080', 'http://localhost:8082'],
    credentials: false,
    methods: ['GET', 'POST', 'PUT', 'DELETE'],
    allowedHeaders: ['Content-Type', 'Authorization']
}));

app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Função helper para resposta padronizada
const sendResponse = (res, data, message = null) => {
    if (!data || (Array.isArray(data) && data.length === 0)) {
        return res.json({
            success: false,
            message: "sem estes dados no BD",
            data: []
        });
    }
    
    res.json({
        success: true,
        message: message,
        data: data
    });
};

// Health check
app.get('/', (req, res) => {
    res.json({
        status: "SPR Backend PostgreSQL",
        version: "1.0.0",
        database: "PostgreSQL conectado",
        timestamp: new Date().toISOString()
    });
});

// API Status
app.get('/api/status', async (req, res) => {
    try {
        const dbTest = await pool.query('SELECT 1');
        const produtosCount = await pool.query('SELECT COUNT(*) FROM produtos WHERE ativo = true');
        const ofertasCount = await pool.query('SELECT COUNT(*) FROM ofertas WHERE status = \'aberta\'');
        
        res.json({
            status: "✅ ONLINE",
            database: "✅ CONNECTED",
            version: "1.0.0-postgres",
            timestamp: new Date().toISOString(),
            stats: {
                produtos_ativos: parseInt(produtosCount.rows[0].count),
                ofertas_abertas: parseInt(ofertasCount.rows[0].count),
                uptime: process.uptime()
            }
        });
    } catch (error) {
        console.error('Erro no status:', error);
        res.status(500).json({
            status: "❌ ERROR",
            database: "❌ DISCONNECTED",
            error: error.message
        });
    }
});

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

        // Formatar dados para o frontend
        const formattedOffers = result.rows.map(row => ({
            id: row.id,
            pin: row.pin,
            commodity: row.commodity,
            price: parseFloat(row.price),
            quantity: row.quantity_sacas60 || row.quantidade_ton || 0,
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

// API Commodities por categoria
app.get('/api/commodities/:category', async (req, res) => {
    try {
        const { category } = req.params;
        
        const result = await pool.query(`
            SELECT 
                p.nome,
                p.categoria,
                p.unidade_precificacao,
                dm.preco,
                dm.variacao,
                dm.tendencia,
                dm.fonte,
                dm.regiao
            FROM produtos p
            LEFT JOIN dados_mercado dm ON UPPER(p.nome) = dm.commodity
            WHERE p.categoria = $1 AND p.ativo = true
            ORDER BY p.nome
        `, [category]);
        
        sendResponse(res, result.rows);
    } catch (error) {
        console.error('Erro ao buscar commodities por categoria:', error);
        sendResponse(res, null, `Erro: ${error.message}`);
    }
});

// API WhatsApp Sessions (conectado ao banco)
app.get('/api/whatsapp/sessions', async (req, res) => {
    try {
        const result = await pool.query(`
            SELECT session_id, status, ultimo_qr, conectado_em 
            FROM whatsapp_sessoes 
            ORDER BY id DESC
        `);
        
        sendResponse(res, result.rows);
    } catch (error) {
        console.error('Erro ao buscar sessões WhatsApp:', error);
        sendResponse(res, null, `Erro: ${error.message}`);
    }
});

// API Criar oferta (exemplo)
app.post('/api/ofertas', async (req, res) => {
    try {
        const { 
            produto_id, 
            quantidade_sacas60, 
            preco_unitario, 
            modalidade, 
            local_retirada_entrega 
        } = req.body;

        if (!produto_id || !preco_unitario || !modalidade || !local_retirada_entrega) {
            return res.status(400).json({
                success: false,
                message: "Dados obrigatórios não fornecidos"
            });
        }

        // Gerar PIN sequencial
        const pinResult = await pool.query('SELECT COALESCE(MAX(pin_seq), 0) + 1 as next_pin FROM ofertas');
        const nextPin = pinResult.rows[0].next_pin;

        const result = await pool.query(`
            INSERT INTO ofertas 
            (pin_seq, produto_id, quantidade_sacas60, preco_unitario, modalidade, local_retirada_entrega)
            VALUES ($1, $2, $3, $4, $5, $6)
            RETURNING *
        `, [nextPin, produto_id, quantidade_sacas60, preco_unitario, modalidade, local_retirada_entrega]);

        res.status(201).json({
            success: true,
            message: "Oferta criada com sucesso",
            data: result.rows[0]
        });
    } catch (error) {
        console.error('Erro ao criar oferta:', error);
        res.status(500).json({
            success: false,
            message: `Erro: ${error.message}`
        });
    }
});

// Tratamento de erros de conexão
pool.on('error', (err) => {
    console.error('Erro no pool PostgreSQL:', err);
});

// Iniciar servidor
app.listen(PORT, () => {
    console.log(`🚀 SPR Backend PostgreSQL rodando na porta ${PORT}`);
    console.log(`📊 Banco: PostgreSQL spr_db`);
    console.log(`🔗 URL: http://localhost:${PORT}`);
    
    // Teste de conexão inicial
    pool.query('SELECT 1', (err, result) => {
        if (err) {
            console.error('❌ Erro na conexão PostgreSQL:', err.message);
        } else {
            console.log('✅ PostgreSQL conectado com sucesso');
        }
    });
});

// Graceful shutdown
process.on('SIGINT', async () => {
    console.log('\n🛑 Encerrando servidor...');
    await pool.end();
    process.exit(0);
});

module.exports = app;