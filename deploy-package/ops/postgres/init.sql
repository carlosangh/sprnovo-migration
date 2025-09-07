-- SPR Database Schema - Estrutura Real do Projeto
-- Baseado no banco existente

-- Tabela de produtos conforme schema real
CREATE TABLE produtos (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(255) NOT NULL,
    categoria VARCHAR(50) NOT NULL CHECK (categoria IN ('graos', 'boi', 'algodao', 'subprodutos', 'outros')),
    unidade_precificacao VARCHAR(20) NOT NULL CHECK (unidade_precificacao IN ('saca60kg', 'ton', 'unidade')),
    comissao_padrao_percent DECIMAL(5,3) DEFAULT NULL,
    comissao_padrao_unitaria DECIMAL(10,2) DEFAULT NULL,
    ativo BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabela de ofertas conforme schema real
CREATE TABLE ofertas (
    id SERIAL PRIMARY KEY,
    pin_seq INTEGER NOT NULL UNIQUE,
    produto_id INTEGER NOT NULL,
    quantidade_sacas60 INTEGER,
    quantidade_ton DECIMAL(10,3),
    preco_unitario DECIMAL(10,2) NOT NULL,
    modalidade VARCHAR(10) NOT NULL CHECK (modalidade IN ('FOB', 'CIF')),
    local_retirada_entrega VARCHAR(255) NOT NULL,
    janela_embarque_ini DATE,
    janela_embarque_fim DATE,
    status VARCHAR(20) NOT NULL DEFAULT 'aberta' CHECK (status IN ('aberta', 'editada', 'cancelada', 'vinculada', 'fechada')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (produto_id) REFERENCES produtos(id)
);

-- Tabela de dados de mercado conforme schema real
CREATE TABLE dados_mercado (
    id SERIAL PRIMARY KEY,
    commodity VARCHAR(100) NOT NULL,
    preco DECIMAL(10,2),
    variacao DECIMAL(5,2),
    volume INTEGER,
    data_coleta TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fonte VARCHAR(100),
    regiao VARCHAR(100),
    tendencia VARCHAR(50)
);

-- Tabela de configurações do sistema
CREATE TABLE configuracoes (
    id SERIAL PRIMARY KEY,
    chave VARCHAR(100) UNIQUE NOT NULL,
    valor TEXT,
    descricao TEXT,
    modificado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabela de instâncias WhatsApp
CREATE TABLE whatsapp_sessoes (
    id SERIAL PRIMARY KEY,
    session_id VARCHAR(100) UNIQUE NOT NULL,
    status VARCHAR(50) DEFAULT 'disconnected',
    qr_code TEXT,
    ultimo_qr TIMESTAMP,
    conectado_em TIMESTAMP,
    desconectado_em TIMESTAMP
);

-- Inserir produtos reais baseados no schema
INSERT INTO produtos (nome, categoria, unidade_precificacao, ativo) VALUES 
('Soja', 'graos', 'saca60kg', true),
('Milho', 'graos', 'saca60kg', true),
('Trigo', 'graos', 'saca60kg', true),
('Algodão', 'algodao', 'saca60kg', true),
('Boi Gordo', 'boi', 'unidade', true),
('Suínos', 'outros', 'kg', true),
('Café', 'graos', 'saca60kg', true);

-- Inserir dados de mercado reais (exemplo baseado nos padrões encontrados)
INSERT INTO dados_mercado (commodity, preco, variacao, volume, fonte, regiao, tendencia) VALUES 
('SOJA', 145.50, 2.3, 15000, 'CEPEA', 'MT', 'alta'),
('MILHO', 72.80, -1.1, 8000, 'CEPEA', 'MT', 'estavel'),
('BOI', 320.00, 0.8, 2500, 'CEPEA', 'SP', 'alta'),
('TRIGO', 89.50, 1.5, 3000, 'CEPEA', 'PR', 'alta'),
('ALGODAO', 280.00, -0.5, 1200, 'CEPEA', 'MT', 'baixa');

-- Inserir configurações do sistema
INSERT INTO configuracoes (chave, valor, descricao) VALUES 
('system_status', 'online', 'Status geral do sistema'),
('evolution_api_url', '', 'URL da Evolution API'),
('evolution_api_token', '', 'Token da Evolution API');

-- Índices para performance
CREATE INDEX idx_ofertas_produto_id ON ofertas(produto_id);
CREATE INDEX idx_ofertas_status ON ofertas(status);
CREATE INDEX idx_dados_mercado_commodity ON dados_mercado(commodity);
CREATE INDEX idx_dados_mercado_data ON dados_mercado(data_coleta);
