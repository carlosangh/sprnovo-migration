/**
 * WhatsApp QR Code routes for Royal Negócios Agrícolas
 * Integração com WPPConnect para geração de QR Code
 */

import { Router } from 'express';
import { Request, Response } from 'express';
import * as path from 'path';
import axios from 'axios';

export const whatsappRouter = Router();

// Configuração do WPPConnect
const WPPCONNECT_BASE_URL = process.env['WPPCONNECT_URL'] || 'http://localhost:3003/api';
const WPPCONNECT_SECRET = 'SPR_ROYAL_NEGOCIOS_SECURE_TOKEN_2025';

/**
 * Serve a página HTML do QR Code
 */
whatsappRouter.get('/whatsapp-qr', (req: Request, res: Response) => {
  try {
    const htmlPath = path.join(__dirname, '../../whatsapp-qr.html');
    res.sendFile(htmlPath);
  } catch (error) {
    console.error('Erro ao servir página WhatsApp QR:', error);
    res.status(500).json({
      success: false,
      error: 'Erro interno do servidor'
    });
  }
});

/**
 * Proxy para gerar token no WPPConnect
 */
whatsappRouter.post('/api/whatsapp/:session/:secretkey/generate-token', async (req: Request, res: Response) => {
  try {
    const { session, secretkey } = req.params;
    
    // Validar secret key
    if (secretkey !== WPPCONNECT_SECRET) {
      return res.status(401).json({
        success: false,
        error: 'Secret key inválida'
      });
    }

    const response = await axios.post(
      `${WPPCONNECT_BASE_URL}/${session}/${secretkey}/generate-token`,
      {},
      {
        headers: {
          'Content-Type': 'application/json'
        },
        timeout: 10000
      }
    );

    return res.json(response.data);
    
  } catch (error) {
    console.error('Erro no proxy generate-token:', error);
    
    if (axios.isAxiosError(error)) {
      const status = error.response?.status || 500;
      const data = error.response?.data || { error: 'Erro de comunicação com WPPConnect' };
      return res.status(status).json(data);
    } else {
      return res.status(500).json({
        success: false,
        error: 'Erro interno do servidor'
      });
    }
  }
});

/**
 * Proxy para iniciar sessão no WPPConnect
 */
whatsappRouter.post('/api/whatsapp/:session/start-session', async (req: Request, res: Response) => {
  try {
    const { session } = req.params;
    const authorization = req.headers.authorization;

    if (!authorization) {
      return res.status(401).json({
        success: false,
        error: 'Token de autorização necessário'
      });
    }

    const response = await axios.post(
      `${WPPCONNECT_BASE_URL}/${session}/start-session`,
      req.body,
      {
        headers: {
          'Content-Type': 'application/json',
          'authorization': authorization
        },
        timeout: 30000
      }
    );

    return res.json(response.data);
    
  } catch (error) {
    console.error('Erro no proxy start-session:', error);
    
    if (axios.isAxiosError(error)) {
      const status = error.response?.status || 500;
      const data = error.response?.data || { error: 'Erro de comunicação com WPPConnect' };
      return res.status(status).json(data);
    } else {
      return res.status(500).json({
        success: false,
        error: 'Erro interno do servidor'
      });
    }
  }
});

/**
 * Proxy para verificar status da sessão
 */
whatsappRouter.get('/api/whatsapp/:session/check-connection-session', async (req: Request, res: Response) => {
  try {
    const { session } = req.params;
    const authorization = req.headers.authorization;

    if (!authorization) {
      return res.status(401).json({
        success: false,
        error: 'Token de autorização necessário'
      });
    }

    const response = await axios.get(
      `${WPPCONNECT_BASE_URL}/${session}/check-connection-session`,
      {
        headers: {
          'authorization': authorization
        },
        timeout: 10000
      }
    );

    return res.json(response.data);
    
  } catch (error) {
    console.error('Erro no proxy check-connection:', error);
    
    if (axios.isAxiosError(error)) {
      const status = error.response?.status || 500;
      const data = error.response?.data || { error: 'Erro de comunicação com WPPConnect' };
      return res.status(status).json(data);
    } else {
      return res.status(500).json({
        success: false,
        error: 'Erro interno do servidor'
      });
    }
  }
});

/**
 * Endpoint para obter QR Code como imagem
 */
whatsappRouter.get('/api/whatsapp/:session/qrcode-session', async (req: Request, res: Response) => {
  try {
    const { session } = req.params;
    const authorization = req.headers.authorization;

    if (!authorization) {
      return res.status(401).json({
        success: false,
        error: 'Token de autorização necessário'
      });
    }

    const response = await axios.get(
      `${WPPCONNECT_BASE_URL}/${session}/qrcode-session`,
      {
        headers: {
          'authorization': authorization
        },
        responseType: 'arraybuffer',
        timeout: 10000
      }
    );

    res.set('Content-Type', 'image/png');
    res.send(response.data);
    
  } catch (error) {
    console.error('Erro no proxy qrcode-session:', error);
    res.status(500).json({
      success: false,
      error: 'Erro ao obter QR Code'
    });
  }
});

/**
 * Endpoint para verificar status do WhatsApp
 */
whatsappRouter.get('/api/whatsapp/status', async (req: Request, res: Response) => {
  try {
    // Verificar se WPPConnect está disponível
    const response = await axios.get(`${WPPCONNECT_BASE_URL.replace('/api', '')}/`, {
      timeout: 5000
    });
    
    res.json({
      success: true,
      status: 'connected',
      wppconnect_available: true,
      wppconnect_status: response.status === 200 ? 'running' : 'down',
      message: 'WhatsApp service disponível',
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    console.error('Erro ao verificar status WhatsApp:', error);
    
    res.json({
      success: false,
      status: 'disconnected',
      wppconnect_available: false,
      wppconnect_status: 'down',
      message: 'WPPConnect não disponível ou não configurado',
      error: axios.isAxiosError(error) ? error.message : 'Erro interno',
      timestamp: new Date().toISOString()
    });
  }
});

/**
 * Health check do serviço WhatsApp
 */
whatsappRouter.get('/api/whatsapp/health', async (req: Request, res: Response) => {
  try {
    const response = await axios.get(`${WPPCONNECT_BASE_URL.replace('/api', '')}/`, {
      timeout: 5000
    });
    
    res.json({
      success: true,
      wppconnect_status: 'running',
      wppconnect_response: response.status === 200,
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    console.error('Erro no health check WhatsApp:', error);
    
    res.status(503).json({
      success: false,
      wppconnect_status: 'down',
      error: 'WPPConnect não disponível',
      timestamp: new Date().toISOString()
    });
  }
});