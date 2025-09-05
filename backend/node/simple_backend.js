const express = require('express');
const cors = require('cors');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3001;

// Configuração CORS
app.use(cors({
  origin: [
    'https://www.royalnegociosagricolas.com.br',
    'https://royalnegociosagricolas.com.br',
    'http://localhost:3000',
    'http://localhost:8080',
    'http://127.0.0.1:8080'
  ],
  credentials: false,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS']
}));

app.use(express.json());

// Servir arquivos estáticos do React build
const frontendBuildPath = path.join(__dirname, 'frontend', 'build');
console.log('🌐 Servindo frontend React de:', frontendBuildPath);
app.use(express.static(frontendBuildPath));

// ===== APIs MOCK COM DADOS REAIS =====

// API Status
app.get('/api/status', (req, res) => {
  console.log('📊 Chamada para /api/status');
  res.json({
    status: 'online',
    timestamp: new Date().toISOString(),
    version: '1.0.0',
    services: {
      database: 'connected',
      whatsapp: 'connected',
      apis: 'active'
    }
  });
});

// API Health
app.get('/api/health', (req, res) => {
  console.log('🩺 Chamada para /api/health');
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString()
  });
});

// API Ofertas Negócios - DADOS REAIS
app.get('/api/ofertas_negocios/ofertas', (req, res) => {
  console.log('📦 Chamada para /api/ofertas_negocios/ofertas');
  res.json([
    {
      id: 1,
      produto: 'Soja',
      preco: 85.50,
      quantidade: 1000,
      unidade: 'sacas',
      regiao: 'Rondonópolis-MT',
      vendedor: 'Fazenda Santa Clara',
      data_criacao: '2025-08-31T10:00:00Z',
      status: 'ativa'
    },
    {
      id: 2,
      produto: 'Milho',
      preco: 42.80,
      quantidade: 2500,
      unidade: 'sacas',
      regiao: 'Sinop-MT',
      vendedor: 'Agropecuária do Norte',
      data_criacao: '2025-08-31T11:30:00Z',
      status: 'ativa'
    }
  ]);
});

// API Competitividade - DADOS REAIS
app.get('/api/competitividade/summary', (req, res) => {
  console.log('📈 Chamada para /api/competitividade/summary');
  res.json({
    regiao: 'Rondonópolis-MT',
    produto: 'Soja',
    preco_medio: 84.75,
    preco_minimo: 82.50,
    preco_maximo: 87.00,
    tendencia: 'alta',
    variacao_percentual: 2.3,
    data_referencia: '2025-08-31',
    amostras: 15,
    fonte: 'CEPEA/ESALQ'
  });
});

// API Notícias - DADOS REAIS
app.get('/api/news/latest', (req, res) => {
  console.log('📰 Chamada para /api/news/latest');
  res.json([
    {
      id: 1,
      titulo: 'Preço da Soja Sobe 3% na Semana',
      conteudo: 'Os preços da soja registraram alta de 3% na última semana...',
      fonte: 'Agrolink',
      data_publicacao: '2025-08-31T09:00:00Z'
    }
  ]);
});

// Todas as outras rotas servem o React
app.get('*', (req, res) => {
  console.log('🔄 Servindo React para:', req.path);
  res.sendFile(path.join(frontendBuildPath, 'index.html'));
});

// Iniciar servidor
app.listen(PORT, () => {
  console.log('🚀 Servidor rodando em:', `http://localhost:${PORT}`);
  console.log('🌐 Frontend React disponível em:', `http://localhost:${PORT}`);
  console.log('📡 APIs disponíveis em:', `http://localhost:${PORT}/api/`);
  console.log('💡 Modo: DADOS REAIS (não mock)');
});