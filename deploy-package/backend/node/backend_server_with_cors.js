const express = require('express');
const cors = require('cors');
const newEndpoints = require('./new_endpoints');
const basisEndpoints = require('./basis_endpoints');

const app = express();

// Configuração CORS para Royal Negócios Agrícolas
const corsConfig = {
  origin: [
    'https://www.royalnegociosagricolas.com.br',
    'http://localhost:3000',
    'http://localhost:8080',
    'http://127.0.0.1:8080'
  ],
  credentials: false,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
  optionsSuccessStatus: 200
};

console.log('🔧 Aplicando configuração CORS...');
console.log('📋 Origens permitidas:', corsConfig.origin);

// Middleware - CORS DEVE ser primeiro
app.use(cors(corsConfig));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Routes
app.use('/api', newEndpoints);
app.use('/api', basisEndpoints);

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: Date.now(), cors: 'enabled' });
});

// Root endpoint
app.get('/', (req, res) => {
  res.json({ 
    message: 'SPR Backend Server',
    status: 'ok', 
    timestamp: Date.now(),
    cors: 'enabled',
    allowedOrigins: corsConfig.origin
  });
});

const PORT = process.env.PORT || 3002;
app.set("trust proxy", 1);
app.listen(PORT, () => {
  console.log(`[spr] listening ${PORT}`);
  console.log('✅ CORS configurado com sucesso!');
});

module.exports = app;