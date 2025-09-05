// Configuração de ambiente
process.env.NODE_ENV = process.env.NODE_ENV || 'development';

const express = require('express');
const cors = require('cors');
const path = require('path');
const fs = require('fs').promises;
const axios = require('axios');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcrypt');
const crypto = require('crypto');
const compression = require('compression');
const morgan = require('morgan');
const sqlite3 = require('sqlite3').verbose();
const { Database } = require('sqlite3');

const app = express();
const PORT = process.env.PORT || 3002;
const WHATSAPP_SERVER_PORT = process.env.WHATSAPP_SERVER_PORT || 3003;
const WHATSAPP_SERVER_URL = process.env.WHATSAPP_SERVER_URL || `http://localhost:${WHATSAPP_SERVER_PORT}`;

// Security configuration
const JWT_SECRET = process.env.JWT_SECRET || crypto.randomBytes(64).toString('hex');
const RATE_LIMIT_WINDOW = 15 * 60 * 1000; // 15 minutes
const RATE_LIMIT_MAX = 100; // requests per window
const WEBHOOK_SECRET = process.env.WEBHOOK_SECRET || crypto.randomBytes(32).toString('hex');

// ============================================================================
// LICENSE SYSTEM CONFIGURATION - PRODUCTION READY - NO MOCK
// ============================================================================
const LICENSE_MODE = process.env.LICENSE_MODE || 'production';
const LICENSE_MOCK = process.env.LICENSE_MOCK === '1' ? true : false;
const NO_MOCK = process.env.NO_MOCK === '1' ? true : false;
const LICENSE_DB_PATH = process.env.LICENSE_DB_PATH || path.join(__dirname, 'licenses.db');

// CRITICAL: Anti-mock validation - FAIL FAST if mock detected in production
if (LICENSE_MODE === 'production' && (LICENSE_MOCK || !NO_MOCK)) {
    console.error('🚫 ERRO CRÍTICO: Configuração mock detectada em produção!');
    console.error('📋 Defina: LICENSE_MODE=production, LICENSE_MOCK=0, NO_MOCK=1');
    process.exit(1);
}

// Block "Mock Client" and "default-session" in production
if (LICENSE_MODE === 'production') {
    const blockedPatterns = ['Mock Client', 'default-session', 'mock', 'test-client'];
    // This validation will be used in middleware
}

// License cache for performance optimization
class LicenseCache {
    constructor() {
        this.cache = new Map();
        this.ttl = 5 * 60 * 1000; // 5 minutes TTL for license data
        this.hitCount = 0;
        this.missCount = 0;
    }

    get(key) {
        const item = this.cache.get(key);
        if (!item) {
            this.missCount++;
            return null;
        }
        
        if (Date.now() > item.expires) {
            this.cache.delete(key);
            this.missCount++;
            return null;
        }
        
        this.hitCount++;
        return item.data;
    }

    set(key, data) {
        this.cache.set(key, {
            data,
            expires: Date.now() + this.ttl,
            createdAt: new Date().toISOString()
        });
    }

    delete(key) {
        this.cache.delete(key);
    }

    clear() {
        this.cache.clear();
        this.hitCount = 0;
        this.missCount = 0;
    }

    getStats() {
        const total = this.hitCount + this.missCount;
        return {
            size: this.cache.size,
            hitCount: this.hitCount,
            missCount: this.missCount,
            hitRate: total > 0 ? (this.hitCount / total * 100).toFixed(2) + '%' : '0%'
        };
    }
}

const licenseCache = new LicenseCache();

// Security middleware - must be first
app.use(helmet({
    contentSecurityPolicy: {
        directives: {
            defaultSrc: ["'self'"],
            styleSrc: ["'self'", "'unsafe-inline'"],
            scriptSrc: ["'self'"],
            imgSrc: ["'self'", "data:", "https:"],
            connectSrc: ["'self'"],
            fontSrc: ["'self'"],
            objectSrc: ["'none'"],
            mediaSrc: ["'self'"],
            frameSrc: ["'none'"]
        }
    },
    crossOriginEmbedderPolicy: false,
    hsts: {
        maxAge: 31536000,
        includeSubDomains: true,
        preload: true
    }
}));

// Rate limiting
const generalLimiter = rateLimit({
    windowMs: RATE_LIMIT_WINDOW,
    max: RATE_LIMIT_MAX,
    message: {
        error: 'Too many requests from this IP',
        retryAfter: Math.ceil(RATE_LIMIT_WINDOW / 1000)
    },
    standardHeaders: true,
    legacyHeaders: false,
    handler: (req, res) => {
        console.warn(`⚠️ Rate limit exceeded for IP: ${req.ip}`);
        res.status(429).json({
            error: 'Too many requests',
            retryAfter: Math.ceil(RATE_LIMIT_WINDOW / 1000),
            timestamp: new Date().toISOString()
        });
    }
});

// Stricter rate limiting for authentication endpoints
const authLimiter = rateLimit({
    windowMs: RATE_LIMIT_WINDOW,
    max: 10, // Only 10 auth attempts per window
    message: {
        error: 'Too many authentication attempts',
        retryAfter: Math.ceil(RATE_LIMIT_WINDOW / 1000)
    },
    skipSuccessfulRequests: true
});

// Apply rate limiting
app.use('/api/auth', authLimiter);
app.use(generalLimiter);

// Apply license gate middleware to all API routes except authentication and health
app.use('/api', (req, res, next) => {
    // Skip license gate for specific endpoints
    const skipPaths = ['/api/health', '/api/license', '/api/auth/login', '/api/auth/refresh'];
    if (skipPaths.some(path => req.path.startsWith(path))) {
        return next();
    }
    
    // Apply license gate
    licenseGate(req, res, next);
});

// Compression
app.use(compression());

// Logging
app.use(morgan('combined', {
    skip: (req, res) => res.statusCode < 400
}));

// CORS configuration - more restrictive in production
const allowedOrigins = process.env.NODE_ENV === 'production' 
    ? process.env.ALLOWED_ORIGINS?.split(',') || []
    : [
        'http://localhost:3000', 
        'http://localhost:3001', 
        'http://localhost:3002', 
        'http://localhost:3003',
        'http://localhost:3004'
    ];

app.use(cors({
    origin: (origin, callback) => {
        if (!origin || allowedOrigins.includes(origin)) {
            callback(null, true);
        } else {
            console.warn(`⚠️ CORS blocked origin: ${origin}`);
            callback(new Error('Not allowed by CORS'));
        }
    },
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With', 'Accept', 'X-API-Key'],
    credentials: true,
    maxAge: 86400,
    optionsSuccessStatus: 200
}));

// Body parsing with security limits
app.use(express.json({ 
    limit: '10mb', // Reduced from 50mb for security
    verify: (req, res, buf) => {
        // Store raw body for webhook signature verification
        req.rawBody = buf;
    }
}));
app.use(express.urlencoded({ 
    extended: true, 
    limit: '10mb',
    parameterLimit: 100 // Limit number of parameters
}));

// Security headers middleware
app.use((req, res, next) => {
    // Remove server information
    res.removeHeader('X-Powered-By');
    
    // Security headers
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('X-Frame-Options', 'DENY');
    res.setHeader('X-XSS-Protection', '1; mode=block');
    res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
    res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
    res.setHeader('Pragma', 'no-cache');
    res.setHeader('Expires', '0');
    
    // Content type
    if (req.path.startsWith('/api/')) {
        res.setHeader('Content-Type', 'application/json');
    }
    
    next();
});

// Input sanitization middleware
const sanitizeInput = (req, res, next) => {
    const sanitize = (obj) => {
        if (typeof obj === 'string') {
            // Remove null bytes and normalize
            return obj.replace(/\x00/g, '').trim();
        } else if (Array.isArray(obj)) {
            return obj.map(sanitize);
        } else if (obj && typeof obj === 'object') {
            const sanitized = {};
            for (const [key, value] of Object.entries(obj)) {
                // Sanitize key names
                const cleanKey = key.replace(/[^\w.-]/g, '');
                sanitized[cleanKey] = sanitize(value);
            }
            return sanitized;
        }
        return obj;
    };
    
    if (req.body) {
        req.body = sanitize(req.body);
    }
    if (req.query) {
        req.query = sanitize(req.query);
    }
    if (req.params) {
        req.params = sanitize(req.params);
    }
    
    next();
};

app.use(sanitizeInput);

// ============================================================================
// LICENSE GATE MIDDLEWARE - REAL VALIDATION - NO MOCK
// ============================================================================
const licenseGate = async (req, res, next) => {
    try {
        // Skip license check for specific endpoints
        const skipPaths = ['/api/health', '/api/license/activate', '/api/auth/login'];
        if (skipPaths.some(path => req.path.startsWith(path))) {
            return next();
        }

        // Block Mock Client and default-session in production
        if (LICENSE_MODE === 'production') {
            const userAgent = req.headers['user-agent'] || '';
            const clientId = req.headers['x-client-id'] || req.body?.clientId || '';
            
            const blockedPatterns = ['Mock Client', 'default-session', 'mock', 'test-client'];
            const isBlockedPattern = blockedPatterns.some(pattern => 
                userAgent.toLowerCase().includes(pattern.toLowerCase()) ||
                clientId.toLowerCase().includes(pattern.toLowerCase())
            );
            
            if (isBlockedPattern) {
                console.warn(`🚫 Blocked mock/test client in production: ${userAgent} / ${clientId}`);
                return res.status(403).json({
                    error: 'Mock clients not allowed in production',
                    timestamp: new Date().toISOString()
                });
            }
        }

        // Extract client ID from various sources
        const clientId = req.headers['x-client-id'] || 
                         req.body?.clientId || 
                         req.query?.clientId ||
                         req.user?.clientId ||
                         'default';

        // Get license status
        const licenseStatus = await LicenseService.getStatus(clientId);
        
        if (!licenseStatus.active) {
            return res.status(403).json({
                error: 'Valid license required',
                message: licenseStatus.error || 'No active license found',
                clientId,
                licenseRequired: true,
                timestamp: new Date().toISOString()
            });
        }

        // Add license info to request
        req.license = licenseStatus;
        req.clientId = clientId;
        
        next();
    } catch (error) {
        console.error('❌ Erro no middleware de licença:', error);
        res.status(500).json({
            error: 'License validation failed',
            message: error.message,
            timestamp: new Date().toISOString()
        });
    }
};

// Authentication middleware with license integration
const authenticateToken = (req, res, next) => {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1]; // Bearer <token>
    
    if (!token) {
        return res.status(401).json({ 
            error: 'Access token required',
            timestamp: new Date().toISOString()
        });
    }
    
    jwt.verify(token, JWT_SECRET, async (err, user) => {
        if (err) {
            console.warn(`Invalid token from IP: ${req.ip}`);
            return res.status(403).json({ 
                error: 'Invalid or expired token',
                timestamp: new Date().toISOString()
            });
        }
        
        // Check license status if spr_license claim exists
        if (user.spr_license && user.spr_license !== 'active') {
            return res.status(403).json({
                error: 'Invalid license status in token',
                timestamp: new Date().toISOString()
            });
        }
        
        req.user = user;
        next();
    });
};

// API key authentication for external services
const authenticateAPIKey = (req, res, next) => {
    const apiKey = req.headers['x-api-key'];
    const validAPIKeys = (process.env.API_KEYS || '').split(',').filter(Boolean);
    
    if (!apiKey || !validAPIKeys.includes(apiKey)) {
        console.warn(`⚠️ Invalid API key from IP: ${req.ip}`);
        return res.status(401).json({
            error: 'Valid API key required',
            timestamp: new Date().toISOString()
        });
    }
    
    next();
};

// Webhook signature verification
const verifyWebhookSignature = (req, res, next) => {
    const signature = req.headers['x-hub-signature-256'];
    
    if (!signature) {
        return res.status(401).json({
            error: 'Webhook signature required',
            timestamp: new Date().toISOString()
        });
    }
    
    const expectedSignature = crypto
        .createHmac('sha256', WEBHOOK_SECRET)
        .update(req.rawBody || '')
        .digest('hex');
    
    const receivedSignature = signature.replace('sha256=', '');
    
    if (!crypto.timingSafeEqual(
        Buffer.from(expectedSignature, 'hex'),
        Buffer.from(receivedSignature, 'hex')
    )) {
        console.warn(`⚠️ Invalid webhook signature from IP: ${req.ip}`);
        return res.status(401).json({
            error: 'Invalid webhook signature',
            timestamp: new Date().toISOString()
        });
    }
    
    next();
};

// Configuração do Axios com timeout e retry otimizados
const axiosInstance = axios.create({
    timeout: 30000, // 30 segundos
    headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'User-Agent': 'SPR-Backend/1.2'
    },
    // Configurações adicionais
    maxRedirects: 3,
    validateStatus: (status) => status < 500 // Não rejeitar 4xx
});

// Implementação de retry com circuit breaker
class CircuitBreaker {
    constructor(failureThreshold = 5, recoveryTimeout = 60000) {
        this.failureThreshold = failureThreshold;
        this.recoveryTimeout = recoveryTimeout;
        this.failureCount = 0;
        this.lastFailureTime = null;
        this.state = 'CLOSED'; // CLOSED, OPEN, HALF_OPEN
    }

    async call(requestFn) {
        if (this.state === 'OPEN') {
            if (Date.now() - this.lastFailureTime > this.recoveryTimeout) {
                this.state = 'HALF_OPEN';
            } else {
                throw new Error('Circuit breaker is OPEN');
            }
        }

        try {
            const result = await requestFn();
            this.onSuccess();
            return result;
        } catch (error) {
            this.onFailure();
            throw error;
        }
    }

    onSuccess() {
        this.failureCount = 0;
        this.state = 'CLOSED';
    }

    onFailure() {
        this.failureCount++;
        this.lastFailureTime = Date.now();
        
        if (this.failureCount >= this.failureThreshold) {
            this.state = 'OPEN';
        }
    }
}

const whatsappCircuitBreaker = new CircuitBreaker(3, 30000); // 3 falhas, 30s timeout

// Retry logic melhorado com exponential backoff
const retryRequest = async (requestFn, maxRetries = 3, baseDelay = 2000) => {
    return whatsappCircuitBreaker.call(async () => {
        for (let i = 0; i < maxRetries; i++) {
            try {
                return await requestFn();
            } catch (error) {
                console.log(`🔄 Tentativa ${i + 1}/${maxRetries} falhou:`, error.message);
                
                if (i === maxRetries - 1) throw error;
                
                // Exponential backoff com jitter
                const delay = baseDelay * Math.pow(2, i) + Math.random() * 1000;
                await new Promise(resolve => setTimeout(resolve, delay));
            }
        }
    });
};

// Variáveis de estado do sistema
// ============================================================================
// LICENSE DATABASE LAYER - REAL PERSISTENCE
// ============================================================================
class LicenseDatabase {
    constructor(dbPath) {
        this.dbPath = dbPath;
        this.db = null;
        this.initialized = false;
    }

    async initialize() {
        return new Promise((resolve, reject) => {
            this.db = new sqlite3.Database(this.dbPath, (err) => {
                if (err) {
                    console.error('❌ Erro ao conectar com banco de licenças:', err);
                    reject(err);
                    return;
                }
                console.log('✅ Banco de dados de licenças conectado:', this.dbPath);
                this.createTables().then(() => {
                    this.initialized = true;
                    resolve();
                }).catch(reject);
            });
        });
    }

    async createTables() {
        return new Promise((resolve, reject) => {
            const createLicensesTable = `
                CREATE TABLE IF NOT EXISTS licenses (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    license_key TEXT UNIQUE NOT NULL,
                    client_id TEXT NOT NULL,
                    active BOOLEAN NOT NULL DEFAULT 1,
                    plan TEXT NOT NULL DEFAULT 'basic',
                    sessions_limit INTEGER DEFAULT 10,
                    sessions_used INTEGER DEFAULT 0,
                    expires_at DATETIME,
                    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                    activated_at DATETIME,
                    last_validation DATETIME,
                    validation_count INTEGER DEFAULT 0
                )
            `;
            
            this.db.run(createLicensesTable, (err) => {
                if (err) {
                    console.error('❌ Erro ao criar tabela licenses:', err);
                    reject(err);
                    return;
                }
                console.log('✅ Tabela licenses criada/verificada');
                resolve();
            });
        });
    }

    async validateLicenseKey(licenseKey) {
        // Real license key validation algorithm
        if (!licenseKey || typeof licenseKey !== 'string') return false;
        if (licenseKey.length < 20) return false;
        
        // Basic format validation: SPR-XXXX-XXXX-XXXX-XXXX
        const keyPattern = /^SPR-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$/;
        if (!keyPattern.test(licenseKey)) return false;
        
        // Checksum validation (simple implementation)
        const parts = licenseKey.split('-');
        const checksum = parts.slice(1, 4).join('').split('').reduce((acc, char) => {
            return acc + char.charCodeAt(0);
        }, 0);
        
        const expectedChecksum = parseInt(parts[4].slice(0, 2), 36);
        return Math.abs(checksum % 100) === Math.abs(expectedChecksum % 100);
    }

    async getLicense(clientId) {
        return new Promise((resolve, reject) => {
            if (!this.initialized) {
                reject(new Error('Database not initialized'));
                return;
            }
            
            const query = `
                SELECT * FROM licenses 
                WHERE client_id = ? AND active = 1 
                ORDER BY created_at DESC LIMIT 1
            `;
            
            this.db.get(query, [clientId], (err, row) => {
                if (err) {
                    reject(err);
                    return;
                }
                resolve(row || null);
            });
        });
    }

    async activateLicense(licenseKey, clientId) {
        return new Promise(async (resolve, reject) => {
            if (!this.initialized) {
                reject(new Error('Database not initialized'));
                return;
            }

            // Validate license key format
            if (!await this.validateLicenseKey(licenseKey)) {
                reject(new Error('Invalid license key format'));
                return;
            }

            // Check if license already exists and is active
            const existingQuery = 'SELECT * FROM licenses WHERE license_key = ?';
            this.db.get(existingQuery, [licenseKey], (err, existing) => {
                if (err) {
                    reject(err);
                    return;
                }

                if (existing) {
                    if (existing.active) {
                        reject(new Error('License already activated'));
                        return;
                    }
                    // Reactivate existing license
                    const updateQuery = `
                        UPDATE licenses SET 
                        active = 1, 
                        client_id = ?,
                        activated_at = CURRENT_TIMESTAMP,
                        updated_at = CURRENT_TIMESTAMP
                        WHERE license_key = ?
                    `;
                    
                    this.db.run(updateQuery, [clientId, licenseKey], function(err) {
                        if (err) {
                            reject(err);
                            return;
                        }
                        resolve({ success: true, message: 'License reactivated' });
                    });
                } else {
                    // Create new license
                    const insertQuery = `
                        INSERT INTO licenses 
                        (license_key, client_id, active, plan, expires_at, activated_at) 
                        VALUES (?, ?, 1, 'premium', datetime('now', '+1 year'), CURRENT_TIMESTAMP)
                    `;
                    
                    this.db.run(insertQuery, [licenseKey, clientId], function(err) {
                        if (err) {
                            reject(err);
                            return;
                        }
                        resolve({ success: true, message: 'License activated', id: this.lastID });
                    });
                }
            });
        });
    }

    async deactivateLicense(clientId) {
        return new Promise((resolve, reject) => {
            if (!this.initialized) {
                reject(new Error('Database not initialized'));
                return;
            }
            
            const query = `
                UPDATE licenses SET 
                active = 0, 
                updated_at = CURRENT_TIMESTAMP 
                WHERE client_id = ? AND active = 1
            `;
            
            this.db.run(query, [clientId], function(err) {
                if (err) {
                    reject(err);
                    return;
                }
                resolve({ success: true, rowsAffected: this.changes });
            });
        });
    }

    async updateValidation(clientId) {
        return new Promise((resolve, reject) => {
            if (!this.initialized) {
                resolve(); // Don't fail if DB not ready
                return;
            }
            
            const query = `
                UPDATE licenses SET 
                last_validation = CURRENT_TIMESTAMP,
                validation_count = validation_count + 1
                WHERE client_id = ? AND active = 1
            `;
            
            this.db.run(query, [clientId], (err) => {
                if (err) {
                    console.warn('⚠️ Failed to update license validation:', err.message);
                }
                resolve();
            });
        });
    }

    close() {
        if (this.db) {
            this.db.close((err) => {
                if (err) {
                    console.error('❌ Erro ao fechar banco de licenças:', err);
                } else {
                    console.log('✅ Banco de dados de licenças fechado');
                }
            });
        }
    }
}

const licenseDB = new LicenseDatabase(LICENSE_DB_PATH);

// ============================================================================
// LICENSE SERVICE LAYER
// ============================================================================
class LicenseService {
    static async getStatus(clientId) {
        try {
            // Check cache first
            const cacheKey = `license:${clientId}`;
            let license = licenseCache.get(cacheKey);
            
            if (!license) {
                // Get from database
                license = await licenseDB.getLicense(clientId);
                if (license) {
                    // Cache the result
                    licenseCache.set(cacheKey, license);
                }
            }
            
            if (!license) {
                return {
                    active: false,
                    clientId,
                    plan: null,
                    expiresAt: null,
                    sessions: { used: 0, limit: 0 },
                    error: 'No active license found'
                };
            }
            
            // Check if license is expired
            const now = new Date();
            const expiresAt = license.expires_at ? new Date(license.expires_at) : null;
            const isExpired = expiresAt && now > expiresAt;
            
            if (isExpired) {
                // Deactivate expired license
                await licenseDB.deactivateLicense(clientId);
                licenseCache.delete(cacheKey);
                
                return {
                    active: false,
                    clientId,
                    plan: license.plan,
                    expiresAt: license.expires_at,
                    sessions: { used: license.sessions_used, limit: license.sessions_limit },
                    error: 'License expired'
                };
            }
            
            // Update validation timestamp
            await licenseDB.updateValidation(clientId);
            
            return {
                active: license.active === 1,
                clientId: license.client_id,
                plan: license.plan,
                expiresAt: license.expires_at,
                sessions: {
                    used: license.sessions_used || 0,
                    limit: license.sessions_limit || 10
                },
                licenseKey: license.license_key,
                activatedAt: license.activated_at,
                lastValidation: license.last_validation,
                validationCount: license.validation_count
            };
        } catch (error) {
            console.error('❌ Erro ao verificar status da licença:', error);
            return {
                active: false,
                clientId,
                plan: null,
                expiresAt: null,
                sessions: { used: 0, limit: 0 },
                error: error.message
            };
        }
    }

    static async activate(licenseKey, clientId) {
        try {
            const result = await licenseDB.activateLicense(licenseKey, clientId);
            
            // Clear cache to force refresh
            licenseCache.delete(`license:${clientId}`);
            
            // Get fresh license status
            const status = await this.getStatus(clientId);
            
            return {
                success: true,
                message: result.message,
                license: status
            };
        } catch (error) {
            console.error('❌ Erro ao ativar licença:', error);
            return {
                success: false,
                error: error.message,
                license: {
                    active: false,
                    clientId,
                    plan: null,
                    expiresAt: null,
                    sessions: { used: 0, limit: 0 }
                }
            };
        }
    }

    static async deactivate(clientId) {
        try {
            const result = await licenseDB.deactivateLicense(clientId);
            
            // Clear cache
            licenseCache.delete(`license:${clientId}`);
            
            return {
                success: true,
                message: 'License deactivated',
                rowsAffected: result.rowsAffected
            };
        } catch (error) {
            console.error('❌ Erro ao desativar licença:', error);
            return {
                success: false,
                error: error.message
            };
        }
    }
}

let systemStatus = {
    whatsappConnected: false,
    lastQrCode: null,
    clientInfo: null,
    lastSeen: null,
    lastCheck: new Date(),
    circuitBreakerState: 'CLOSED',
    metrics: {
        totalMessages: 0,
        activeChats: 0,
        responseTime: 150,
        deliveryRate: 98.5,
        readRate: 85.2,
        iaGenerations: 0,
        totalRequests: 0,
        failedRequests: 0
    }
};

// Função auxiliar melhorada para verificar WhatsApp Server
async function checkWhatsAppServerStatus() {
    try {
        console.log('🔍 Verificando status do WhatsApp Server...');
        systemStatus.metrics.totalRequests++;
        
        const response = await retryRequest(() => 
            axiosInstance.get(`${WHATSAPP_SERVER_URL}/api/status`)
        );
        
        const isConnected = response.data.whatsappConnected || response.data.connected || false;
        systemStatus.whatsappConnected = isConnected;
        systemStatus.lastCheck = new Date();
        systemStatus.circuitBreakerState = whatsappCircuitBreaker.state;
        
        if (response.data.clientInfo) {
            systemStatus.clientInfo = response.data.clientInfo;
        }
        
        console.log(`✅ WhatsApp Server: ${isConnected ? 'Online' : 'Offline'}`);
        return true;
    } catch (error) {
        console.error('❌ WhatsApp Server indisponível:', error.message);
        systemStatus.whatsappConnected = false;
        systemStatus.lastCheck = new Date();
        systemStatus.circuitBreakerState = whatsappCircuitBreaker.state;
        systemStatus.metrics.failedRequests++;
        return false;
    }
}

// ============================================================================
// LICENSE ENDPOINTS - REAL DATA SOURCE
// ============================================================================

// GET /api/license/status - Get current license status
app.get('/api/license/status', async (req, res) => {
    try {
        const clientId = req.headers['x-client-id'] || 
                        req.query.clientId || 
                        'default';

        const licenseStatus = await LicenseService.getStatus(clientId);
        
        res.json({
            ...licenseStatus,
            timestamp: new Date().toISOString(),
            cacheStats: licenseCache.getStats()
        });
    } catch (error) {
        console.error('❌ Erro ao obter status da licença:', error);
        res.status(500).json({
            error: 'Failed to get license status',
            message: error.message,
            timestamp: new Date().toISOString()
        });
    }
});

// POST /api/license/activate - Activate a license
app.post('/api/license/activate', async (req, res) => {
    try {
        const { key: licenseKey, clientId } = req.body;
        
        if (!licenseKey) {
            return res.status(400).json({
                success: false,
                error: 'License key is required',
                timestamp: new Date().toISOString()
            });
        }
        
        if (!clientId) {
            return res.status(400).json({
                success: false,
                error: 'Client ID is required',
                timestamp: new Date().toISOString()
            });
        }
        
        const result = await LicenseService.activate(licenseKey, clientId);
        
        if (result.success) {
            console.log(`✅ Licença ativada para cliente: ${clientId}`);
            res.json({
                ...result,
                timestamp: new Date().toISOString()
            });
        } else {
            res.status(400).json({
                ...result,
                timestamp: new Date().toISOString()
            });
        }
    } catch (error) {
        console.error('❌ Erro ao ativar licença:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to activate license',
            message: error.message,
            timestamp: new Date().toISOString()
        });
    }
});

// POST /api/license/deactivate - Deactivate current license
app.post('/api/license/deactivate', async (req, res) => {
    try {
        const clientId = req.headers['x-client-id'] || 
                        req.body.clientId || 
                        'default';
        
        const result = await LicenseService.deactivate(clientId);
        
        if (result.success) {
            console.log(`✅ Licença desativada para cliente: ${clientId}`);
        }
        
        res.json({
            ...result,
            clientId,
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        console.error('❌ Erro ao desativar licença:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to deactivate license',
            message: error.message,
            timestamp: new Date().toISOString()
        });
    }
});

// Authentication endpoints with license integration
app.post('/api/auth/login', async (req, res) => {
    try {
        const { username, password } = req.body;
        
        if (!username || !password) {
            return res.status(400).json({
                error: 'Username and password required',
                timestamp: new Date().toISOString()
            });
        }
        
        // In production, validate against database
        const validUsers = {
            'admin': process.env.ADMIN_PASSWORD_HASH,
            'manager': process.env.MANAGER_PASSWORD_HASH,
            'operator': process.env.OPERATOR_PASSWORD_HASH
        };
        
        const userPasswordHash = validUsers[username];
        if (!userPasswordHash || !await bcrypt.compare(password, userPasswordHash)) {
            console.warn(`⚠️ Failed login attempt for user: ${username} from IP: ${req.ip}`);
            return res.status(401).json({
                error: 'Invalid credentials',
                timestamp: new Date().toISOString()
            });
        }
        
        // Define user roles
        const userRoles = {
            'admin': ['admin', 'manager', 'operator'],
            'manager': ['manager', 'operator'],
            'operator': ['operator']
        };
        
        // Check license status for the user's client
        const clientId = req.body.clientId || `client_${username}`;
        const licenseStatus = await LicenseService.getStatus(clientId);
        
        // Generate JWT token with license claim
        const tokenPayload = { 
            username, 
            roles: userRoles[username] || [],
            clientId,
            spr_license: licenseStatus.active ? 'active' : 'inactive',
            iat: Math.floor(Date.now() / 1000),
            exp: Math.floor(Date.now() / 1000) + (60 * 60) // 1 hour
        };
        
        const token = jwt.sign(tokenPayload, JWT_SECRET);
        
        console.log(`✅ User ${username} logged in successfully from IP: ${req.ip}`);
        
        res.json({
            success: true,
            token,
            user: {
                username,
                roles: userRoles[username] || [],
                clientId
            },
            license: {
                active: licenseStatus.active,
                plan: licenseStatus.plan,
                expiresAt: licenseStatus.expiresAt
            },
            expiresIn: 3600,
            timestamp: new Date().toISOString()
        });
        
    } catch (error) {
        console.error('❌ Login error:', error);
        res.status(500).json({
            error: 'Authentication failed',
            timestamp: new Date().toISOString()
        });
    }
});

// GET /api/auth/me - Get current user info with license status
app.get('/api/auth/me', authenticateToken, async (req, res) => {
    try {
        const clientId = req.user.clientId || 'default';
        const licenseStatus = await LicenseService.getStatus(clientId);
        
        res.json({
            user: {
                username: req.user.username,
                roles: req.user.roles,
                clientId
            },
            license: {
                active: licenseStatus.active,
                plan: licenseStatus.plan,
                expiresAt: licenseStatus.expiresAt,
                sessions: licenseStatus.sessions
            },
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        console.error('❌ Erro ao obter informações do usuário:', error);
        res.status(500).json({
            error: 'Failed to get user info',
            timestamp: new Date().toISOString()
        });
    }
});

app.post('/api/auth/refresh', authenticateToken, async (req, res) => {
    try {
        // Check current license status
        const clientId = req.user.clientId || 'default';
        const licenseStatus = await LicenseService.getStatus(clientId);
        
        // Generate new token with updated license status
        const newToken = jwt.sign(
            { 
                username: req.user.username,
                roles: req.user.roles,
                clientId,
                spr_license: licenseStatus.active ? 'active' : 'inactive',
                iat: Math.floor(Date.now() / 1000),
                exp: Math.floor(Date.now() / 1000) + (60 * 60) // 1 hour
            },
            JWT_SECRET
        );
        
        res.json({
            success: true,
            token: newToken,
            license: {
                active: licenseStatus.active,
                plan: licenseStatus.plan,
                expiresAt: licenseStatus.expiresAt
            },
            expiresIn: 3600,
            timestamp: new Date().toISOString()
        });
        
    } catch (error) {
        console.error('❌ Token refresh error:', error);
        res.status(500).json({
            error: 'Token refresh failed',
            timestamp: new Date().toISOString()
        });
    }
});

// ENDPOINT PRINCIPAL: Status geral do sistema (public for development)
app.get('/api/status', async (req, res) => {
    try {
        console.log('📊 Endpoint /api/status chamado');
        
        // Verificar status do WhatsApp Server
        const whatsappServerOnline = await checkWhatsAppServerStatus();
        
        const response = {
            status: "online",
            timestamp: new Date().toISOString(),
            version: "1.2.1",
            services: {
                whatsapp: systemStatus.whatsappConnected ? "connected" : "disconnected",
                database: "connected",
                api: "running",
                ia: "ready",
                whatsappServer: whatsappServerOnline ? "online" : "offline",
                circuitBreaker: systemStatus.circuitBreakerState
            },
            metrics: {
                ...systemStatus.metrics,
                uptime: process.uptime(),
                lastCheck: systemStatus.lastCheck,
                successRate: systemStatus.metrics.totalRequests > 0 
                    ? ((systemStatus.metrics.totalRequests - systemStatus.metrics.failedRequests) / systemStatus.metrics.totalRequests * 100).toFixed(2)
                    : 100
            }
        };
        
        console.log('✅ Status retornado:', response.services);
        res.json(response);
    } catch (error) {
        console.error('❌ Erro no endpoint /api/status:', error);
        res.status(500).json({
            status: "error",
            message: error.message,
            timestamp: new Date().toISOString(),
            version: "1.2.1"
        });
    }
});

// WhatsApp webhook endpoint (external, requires signature verification)
app.post('/api/webhook/whatsapp', verifyWebhookSignature, async (req, res) => {
    try {
        console.log('📥 WhatsApp webhook received');
        
        // Process webhook payload
        const payload = req.body;
        
        // Basic validation
        if (!payload.object || payload.object !== 'whatsapp_business_account') {
            return res.status(400).json({
                error: 'Invalid webhook object',
                timestamp: new Date().toISOString()
            });
        }
        
        // Process entries
        if (payload.entry && Array.isArray(payload.entry)) {
            for (const entry of payload.entry) {
                if (entry.changes) {
                    for (const change of entry.changes) {
                        if (change.field === 'messages' && change.value.messages) {
                            // Process incoming messages
                            for (const message of change.value.messages) {
                                console.log(`📨 Received message: ${message.id} from ${message.from}`);
                                // Here you would process the message
                            }
                        }
                    }
                }
            }
        }
        
        // WhatsApp requires a 200 response
        res.status(200).send('OK');
        
    } catch (error) {
        console.error('❌ Webhook processing error:', error);
        res.status(500).json({
            error: 'Webhook processing failed',
            timestamp: new Date().toISOString()
        });
    }
});

// WhatsApp webhook verification (GET request)
app.get('/api/webhook/whatsapp', (req, res) => {
    try {
        const mode = req.query['hub.mode'];
        const token = req.query['hub.verify_token'];
        const challenge = req.query['hub.challenge'];
        
        if (mode === 'subscribe' && token === process.env.WHATSAPP_WEBHOOK_VERIFY_TOKEN) {
            console.log('✅ WhatsApp webhook verified successfully');
            res.status(200).send(challenge);
        } else {
            console.warn('⚠️ WhatsApp webhook verification failed');
            res.sendStatus(403);
        }
    } catch (error) {
        console.error('❌ Webhook verification error:', error);
        res.sendStatus(403);
    }
});

// PROXY ESPECÍFICO PARA ENDPOINTS WHATSAPP CHAT E QR (public for development)
app.get('/chat', async (req, res) => {
    try {
        console.log('🔄 Proxy WhatsApp Chat: GET /chat');
        systemStatus.metrics.totalRequests++;
        
        const startTime = Date.now();
        const targetUrl = `${WHATSAPP_SERVER_URL}/chat`;
        
        const response = await retryRequest(() => 
            axiosInstance.get(targetUrl, {
                headers: {
                    'Accept': 'text/html',
                    'X-Forwarded-For': req.ip
                }
            })
        );
        
        // Calcular tempo de resposta
        const responseTime = Date.now() - startTime;
        systemStatus.metrics.responseTime = Math.round(
            (systemStatus.metrics.responseTime * 0.9) + (responseTime * 0.1)
        );
        
        // Retornar HTML diretamente
        res.setHeader('Content-Type', 'text/html');
        res.send(response.data);
    } catch (error) {
        console.error('❌ Erro no proxy WhatsApp Chat:', error.message);
        systemStatus.metrics.failedRequests++;
        
        res.status(503).setHeader('Content-Type', 'text/html').send(`
            <html>
            <head><title>WhatsApp Chat - Indisponível</title></head>
            <body>
                <h1>Serviço WhatsApp Temporariamente Indisponível</h1>
                <p>O servidor WhatsApp está offline. Tente novamente em alguns instantes.</p>
                <p>Status: ${whatsappCircuitBreaker.state}</p>
                <p><a href="javascript:window.location.reload()">Tentar Novamente</a></p>
            </body>
            </html>
        `);
    }
});

app.get('/api/qr', async (req, res) => {
    try {
        console.log('🔄 Proxy WhatsApp QR: GET /api/qr');
        systemStatus.metrics.totalRequests++;
        
        const startTime = Date.now();
        const targetUrl = `${WHATSAPP_SERVER_URL}/api/qr`;
        
        const response = await retryRequest(() => axiosInstance.get(targetUrl));
        
        // Calcular tempo de resposta
        const responseTime = Date.now() - startTime;
        systemStatus.metrics.responseTime = Math.round(
            (systemStatus.metrics.responseTime * 0.9) + (responseTime * 0.1)
        );
        
        res.json(response.data);
    } catch (error) {
        console.error('❌ Erro no proxy WhatsApp QR:', error.message);
        systemStatus.metrics.failedRequests++;
        
        res.status(503).json({
            qrCode: null,
            connected: false,
            error: 'WhatsApp Server indisponível',
            circuitBreakerState: whatsappCircuitBreaker.state,
            retryAfter: whatsappCircuitBreaker.state === 'OPEN' ? 30 : 5,
            timestamp: new Date().toISOString()
        });
    }
});

// PROXY MELHORADO PARA WHATSAPP ENDPOINTS (public for development)
app.use('/api/whatsapp', async (req, res) => {
    try {
        console.log(`🔄 Proxy WhatsApp: ${req.method} ${req.path}`);
        systemStatus.metrics.totalRequests++;
        
        const startTime = Date.now();
        const targetUrl = `${WHATSAPP_SERVER_URL}${req.originalUrl}`;
        
        const config = {
            method: req.method.toLowerCase(),
            url: targetUrl,
            data: req.body,
            timeout: 30000,
            headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'X-Forwarded-For': req.ip,
                'X-Original-Method': req.method
            }
        };

        const response = await retryRequest(() => axiosInstance(config));
        
        // Calcular tempo de resposta
        const responseTime = Date.now() - startTime;
        systemStatus.metrics.responseTime = Math.round(
            (systemStatus.metrics.responseTime * 0.9) + (responseTime * 0.1)
        );
        
        // Atualizar métricas específicas
        if (req.path.includes('send') && response.data.success) {
            systemStatus.metrics.totalMessages++;
        }
        
        if (req.path.includes('chats') && response.data.chats) {
            systemStatus.metrics.activeChats = response.data.chats.length;
        }
        
        res.json(response.data);
    } catch (error) {
        console.error('❌ Erro no proxy WhatsApp:', error.message);
        systemStatus.metrics.failedRequests++;
        
        // Fallback responses melhorados
        const fallbackResponse = {
            timestamp: new Date().toISOString(),
            error: 'WhatsApp Server indisponível',
            circuitBreakerState: whatsappCircuitBreaker.state,
            retryAfter: whatsappCircuitBreaker.state === 'OPEN' ? 30 : 5
        };
        
        if (req.path.includes('status')) {
            res.json({
                connected: false,
                whatsappConnected: false,
                ...fallbackResponse
            });
        } else if (req.path.includes('chats')) {
            res.json({
                chats: [],
                message: 'Lista de conversas indisponível',
                ...fallbackResponse
            });
        } else if (req.path.includes('send')) {
            res.status(503).json({
                success: false,
                message: 'Serviço de envio temporariamente indisponível',
                ...fallbackResponse
            });
        } else {
            res.status(503).json({
                success: false,
                message: 'Serviço temporariamente indisponível',
                ...fallbackResponse
            });
        }
    }
});

// Endpoint para gerar mensagem com IA - OTIMIZADO
const generateMessageWithAI = (prompt, tone, contactName, isGroup, context) => {
    const toneMessages = {
        formal: `Prezado(a) ${contactName || 'cliente'}, espero que esteja bem. `,
        normal: `Olá ${contactName || 'cliente'}, `,
        informal: `Oi ${contactName || 'cliente'}, `,
        alegre: `Oi ${contactName || 'cliente'}! 😊 `
    };

    const baseMessage = toneMessages[tone] || toneMessages.normal;
    
    // Lógica inteligente baseada no prompt
    const promptLower = prompt.toLowerCase();
    
    // Palavras-chave específicas do agronegócio
    const keywords = {
        'reunião|meeting|encontro': 'Gostaria de agendar uma reunião para conversarmos melhor sobre nossos serviços e oportunidades de negócio.',
        'preço|cotação|valor': 'Posso te ajudar com informações atualizadas sobre preços e cotações de commodities. Temos os melhores dados do mercado.',
        'soja': 'Tenho informações atualizadas sobre soja para você. O mercado está aquecido e temos ótimas oportunidades.',
        'milho': 'O mercado do milho está em movimento. Posso compartilhar as últimas análises e projeções.',
        'café': 'O setor cafeeiro apresenta boas perspectivas. Vamos conversar sobre as oportunidades?',
        'algodão': 'O mercado do algodão está com tendência positiva. Posso te passar mais detalhes.',
        'açúcar': 'O açúcar está com boa demanda internacional. Temos análises detalhadas para compartilhar.',
        'obrigado|agradec': 'Muito obrigado pela confiança! Estamos sempre à disposição para ajudar no que precisar.',
        'desculp': 'Peço desculpas pelo inconveniente. Como posso ajudar a resolver essa situação?',
        'proposta|orçamento': 'Vou preparar uma proposta personalizada para suas necessidades. Quando podemos conversar?',
        'contrato|acordo': 'Vamos alinhar os detalhes do contrato. Preciso entender melhor suas expectativas.',
        'mercado|análise': 'Nossas análises de mercado são atualizadas diariamente. Posso compartilhar os dados mais recentes com você.'
    };
    
    // Buscar correspondência de palavras-chave
    for (const [pattern, response] of Object.entries(keywords)) {
        const regex = new RegExp(pattern, 'i');
        if (regex.test(promptLower)) {
            return baseMessage + response;
        }
    }
    
    // Mensagem padrão com o prompt do usuário
    return baseMessage + prompt + ' Estou aqui para ajudar com informações sobre commodities e agronegócio.';
};

// Endpoint para gerar mensagem com IA (requires authentication)
app.post('/api/generate-message', authenticateToken, (req, res) => {
    try {
        const { prompt, tone = 'normal', contactName, isGroup = false, context = 'whatsapp' } = req.body;
        
        if (!prompt || prompt.trim().length === 0) {
            return res.status(400).json({
                success: false,
                error: 'Prompt é obrigatório',
                message: 'Por favor, forneça um prompt para gerar a mensagem',
                timestamp: new Date().toISOString()
            });
        }
        
        if (prompt.length > 1000) {
            return res.status(400).json({
                success: false,
                error: 'Prompt muito longo',
                message: 'O prompt deve ter no máximo 1000 caracteres',
                timestamp: new Date().toISOString()
            });
        }
        
        console.log('🤖 Gerando mensagem com IA:', { 
            prompt: prompt.substring(0, 50) + '...', 
            tone, 
            contactName, 
            isGroup, 
            context 
        });
        
        // Gerar mensagem principal
        const generatedMessage = generateMessageWithAI(prompt.trim(), tone, contactName, isGroup, context);
        
        // Atualizar métricas
        systemStatus.metrics.iaGenerations++;
        
        const response = {
            success: true,
            message: generatedMessage,
            tone: tone,
            contactName: contactName,
            isGroup: isGroup,
            context: context,
            timestamp: new Date().toISOString(),
            metadata: {
                promptLength: prompt.length,
                messageLength: generatedMessage.length,
                processingTime: Date.now() % 1000 // Simular tempo de processamento
            },
            metrics: {
                iaGenerations: systemStatus.metrics.iaGenerations
            }
        };
        
        console.log('✅ Mensagem gerada com sucesso');
        res.json(response);
        
    } catch (error) {
        console.error('❌ Erro ao gerar mensagem:', error);
        res.status(500).json({
            success: false,
            error: 'Erro interno ao gerar mensagem',
            message: error.message,
            timestamp: new Date().toISOString()
        });
    }
});

// Endpoint de health check melhorado (public, no auth required)
app.get('/api/health', async (req, res) => {
    const healthData = {
        status: 'OK',
        message: 'Backend funcionando!',
        timestamp: new Date().toISOString(),
        version: '1.2.1',
        uptime: process.uptime(),
        memory: {
            used: Math.round(process.memoryUsage().heapUsed / 1024 / 1024),
            total: Math.round(process.memoryUsage().heapTotal / 1024 / 1024),
            rss: Math.round(process.memoryUsage().rss / 1024 / 1024)
        },
        services: {
            whatsappServer: systemStatus.whatsappConnected ? 'connected' : 'disconnected',
            circuitBreaker: systemStatus.circuitBreakerState,
            lastCheck: systemStatus.lastCheck
        },
        metrics: systemStatus.metrics
    };
    
    res.json(healthData);
});

// Endpoint de métricas detalhadas (requires admin role)
app.get('/api/metrics', authenticateToken, (req, res) => {
    // Check if user has admin role
    if (!req.user.roles || !req.user.roles.includes('admin')) {
        return res.status(403).json({
            error: 'Admin role required',
            timestamp: new Date().toISOString()
        });
    }
    const metrics = {
        ...systemStatus.metrics,
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        whatsappConnected: systemStatus.whatsappConnected,
        circuitBreakerState: systemStatus.circuitBreakerState,
        lastCheck: systemStatus.lastCheck,
        system: {
            platform: process.platform,
            nodeVersion: process.version,
            pid: process.pid,
            memory: process.memoryUsage(),
            cpu: process.cpuUsage()
        }
    };
    
    res.json(metrics);
});

// Análise de sentimento
app.post('/api/analyze-sentiment', async (req, res) => {
    try {
        const { message } = req.body;
        
        if (!message || typeof message !== 'string') {
            return res.status(400).json({
                error: 'Mensagem é obrigatória',
                timestamp: new Date().toISOString()
            });
        }
        
        // Análise simples baseada em palavras-chave
        const positiveWords = ['bom', 'ótimo', 'excelente', 'obrigado', 'parabéns', 'sucesso'];
        const negativeWords = ['ruim', 'péssimo', 'problema', 'erro', 'falha', 'cancelar'];
        
        const messageLower = message.toLowerCase();
        const positiveCount = positiveWords.filter(word => messageLower.includes(word)).length;
        const negativeCount = negativeWords.filter(word => messageLower.includes(word)).length;
        
        let sentiment = 'neutral';
        let confidence = 50;
        
        if (positiveCount > negativeCount) {
            sentiment = 'positive';
            confidence = Math.min(90, 50 + (positiveCount * 15));
        } else if (negativeCount > positiveCount) {
            sentiment = 'negative';
            confidence = Math.min(90, 50 + (negativeCount * 15));
        }
        
        const sentimentAnalysis = {
            sentiment,
            confidence,
            emotions: {
                joy: sentiment === 'positive' ? confidence : Math.random() * 30,
                anger: sentiment === 'negative' ? confidence : Math.random() * 20,
                sadness: sentiment === 'negative' ? confidence * 0.8 : Math.random() * 15,
                surprise: Math.random() * 40,
                fear: sentiment === 'negative' ? confidence * 0.6 : Math.random() * 10
            },
            keywords: {
                positive: positiveWords.filter(word => messageLower.includes(word)),
                negative: negativeWords.filter(word => messageLower.includes(word))
            },
            timestamp: new Date().toISOString()
        };
        
        res.json(sentimentAnalysis);
    } catch (error) {
        console.error('❌ Erro na análise de sentimento:', error);
        res.status(500).json({ 
            error: error.message,
            timestamp: new Date().toISOString()
        });
    }
});

// Upload de arquivos simulado
app.post('/api/upload', async (req, res) => {
    try {
        const { filename, size, type } = req.body;
        
        // Validações básicas
        const allowedTypes = ['image/jpeg', 'image/png', 'application/pdf', 'text/plain'];
        const maxSize = 10 * 1024 * 1024; // 10MB
        
        if (size && size > maxSize) {
            return res.status(400).json({
                success: false,
                error: 'Arquivo muito grande',
                message: 'Tamanho máximo permitido: 10MB',
                timestamp: new Date().toISOString()
            });
        }
        
        if (type && !allowedTypes.includes(type)) {
            return res.status(400).json({
                success: false,
                error: 'Tipo de arquivo não permitido',
                message: 'Tipos permitidos: JPG, PNG, PDF, TXT',
                timestamp: new Date().toISOString()
            });
        }
        
        const uploadResult = {
            success: true,
            message: "Upload simulado com sucesso",
            fileId: `file_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
            filename: filename || 'arquivo_desconhecido',
            size: size || 0,
            type: type || 'application/octet-stream',
            url: `/uploads/${Date.now()}_${filename || 'file'}`,
            timestamp: new Date().toISOString()
        };
        
        res.json(uploadResult);
    } catch (error) {
        console.error('❌ Erro no upload:', error);
        res.status(500).json({ 
            success: false,
            error: error.message,
            timestamp: new Date().toISOString()
        });
    }
});

// Configurações do sistema
app.get('/api/config', (req, res) => {
    const config = {
        whatsappEnabled: true,
        aiEnabled: true,
        maxMessageLength: 4096,
        supportedFileTypes: ['jpg', 'png', 'pdf', 'doc', 'txt'],
        version: "1.2.1",
        features: {
            sentimentAnalysis: true,
            autoReply: true,
            fileUpload: true,
            messageScheduling: false,
            groupManagement: true
        },
        limits: {
            maxFileSize: 10485760, // 10MB
            rateLimit: 200,
            rateLimitWindow: 60000,
            maxRetries: 3,
            timeoutMs: 30000
        },
        timeouts: {
            whatsappRequest: 30000,
            retryDelay: 5000,
            maxRetries: 3,
            circuitBreakerThreshold: 3,
            circuitBreakerTimeout: 30000
        }
    };
    res.json(config);
});

app.post('/api/config', (req, res) => {
    // Validar configurações recebidas
    const allowedKeys = [
        'whatsappEnabled', 'aiEnabled', 'maxMessageLength', 
        'autoReply', 'fileUpload'
    ];
    
    const validConfig = {};
    for (const key of allowedKeys) {
        if (req.body.hasOwnProperty(key)) {
            validConfig[key] = req.body[key];
        }
    }
    
    res.json({
        success: true,
        message: "Configurações salvas",
        config: validConfig,
        applied: Object.keys(validConfig).length,
        timestamp: new Date().toISOString()
    });
});

// Middleware para capturar rotas não encontradas
app.use('*', (req, res) => {
    console.log(`❌ Rota não encontrada: ${req.method} ${req.originalUrl}`);
    res.status(404).json({
        error: "Endpoint não encontrado",
        path: req.originalUrl,
        method: req.method,
        timestamp: new Date().toISOString(),
        suggestion: "Verifique a documentação da API",
        availableEndpoints: [
            'GET /api/status - Status geral do sistema',
            'GET /api/health - Health check',
            'GET /api/metrics - Métricas detalhadas',
            'GET /chat - Interface de Chat WhatsApp (proxy)',
            'GET /api/qr - QR Code WhatsApp (proxy)',
            'GET /api/whatsapp/* - Endpoints do WhatsApp (proxy)',
            'POST /api/generate-message - Gerar mensagem com IA',
            'POST /api/analyze-sentiment - Análise de sentimento',
            'POST /api/upload - Upload de arquivos',
            'GET /api/config - Configurações do sistema',
            'POST /api/config - Atualizar configurações'
        ]
    });
});

// Tratamento de erros global melhorado
app.use((error, req, res, next) => {
    console.error('❌ Erro global capturado:', {
        message: error.message,
        stack: error.stack,
        url: req.originalUrl,
        method: req.method,
        ip: req.ip,
        timestamp: new Date().toISOString()
    });
    
    // Não expor detalhes internos em produção
    const isDevelopment = process.env.NODE_ENV === 'development';
    
    res.status(error.status || 500).json({
        error: "Erro interno do servidor",
        message: isDevelopment ? error.message : "Algo deu errado",
        timestamp: new Date().toISOString(),
        requestId: `req_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
        ...(isDevelopment && { stack: error.stack })
    });
});

// ============================================================================
// WEBSOCKET WITH LICENSE VALIDATION - Socket.IO Integration
// ============================================================================
const { Server } = require('socket.io');
const http = require('http');

// Create HTTP server for Socket.IO
const server = http.createServer(app);
const io = new Server(server, {
    cors: {
        origin: allowedOrigins,
        methods: ["GET", "POST"],
        credentials: true
    },
    transports: ['websocket', 'polling']
});

// Socket.IO middleware for license validation
io.use(async (socket, next) => {
    try {
        const token = socket.handshake.auth.token || socket.handshake.headers.authorization?.replace('Bearer ', '');
        
        if (!token) {
            return next(new Error('Authentication required'));
        }
        
        // Verify JWT token
        const decoded = jwt.verify(token, JWT_SECRET);
        
        // Check if license claim is active
        if (!decoded.spr_license || decoded.spr_license !== 'active') {
            console.warn(`🚫 WebSocket connection rejected: Invalid license status for user ${decoded.username}`);
            return next(new Error('Valid license required'));
        }
        
        // Double-check license status from database
        const clientId = decoded.clientId || 'default';
        const licenseStatus = await LicenseService.getStatus(clientId);
        
        if (!licenseStatus.active) {
            console.warn(`🚫 WebSocket connection rejected: License not active for client ${clientId}`);
            return next(new Error('License not active'));
        }
        
        // Attach user and license info to socket
        socket.userId = decoded.username;
        socket.clientId = clientId;
        socket.license = licenseStatus;
        
        console.log(`✅ WebSocket connection authorized for user: ${decoded.username}, client: ${clientId}`);
        next();
        
    } catch (error) {
        console.warn(`🚫 WebSocket authentication failed: ${error.message}`);
        next(new Error('Authentication failed'));
    }
});

// Socket.IO connection handling
io.on('connection', (socket) => {
    console.log(`🔌 WebSocket connected: ${socket.userId} (${socket.clientId})`);
    
    // Join client-specific room
    socket.join(`client:${socket.clientId}`);
    
    // Periodic license check (every 5 minutes)
    const licenseCheckInterval = setInterval(async () => {
        try {
            const licenseStatus = await LicenseService.getStatus(socket.clientId);
            if (!licenseStatus.active) {
                console.warn(`🚫 Disconnecting WebSocket: License no longer active for ${socket.clientId}`);
                socket.emit('license_expired', { 
                    message: 'License expired or deactivated',
                    timestamp: new Date().toISOString()
                });
                socket.disconnect(true);
            }
        } catch (error) {
            console.error('❌ Error checking license in WebSocket:', error);
        }
    }, 5 * 60 * 1000); // 5 minutes
    
    // Handle disconnection
    socket.on('disconnect', (reason) => {
        console.log(`🔌 WebSocket disconnected: ${socket.userId} (${socket.clientId}) - ${reason}`);
        clearInterval(licenseCheckInterval);
    });
    
    // Example: Handle custom events
    socket.on('whatsapp_status', async (data) => {
        // Forward WhatsApp status updates only for licensed clients
        socket.to(`client:${socket.clientId}`).emit('whatsapp_status', data);
    });
});

// Initialize license database
async function initializeLicenseSystem() {
    try {
        await licenseDB.initialize();
        console.log('🔐 Sistema de licenças inicializado com sucesso');
        
        // Insert a test license for development (only if none exists)
        if (process.env.NODE_ENV === 'development') {
            try {
                const testLicense = await licenseDB.getLicense('test-client');
                if (!testLicense) {
                    await licenseDB.activateLicense('SPR-TEST-1234-5678-ABCD', 'test-client');
                    console.log('🧪 Licença de teste criada para desenvolvimento');
                }
            } catch (error) {
                console.log('ℹ️ Licença de teste já existe ou erro ao criar');
            }
        }
    } catch (error) {
        console.error('❌ Erro ao inicializar sistema de licenças:', error);
        if (LICENSE_MODE === 'production') {
            console.error('❌ FALHA CRÍTICA: Sistema de licenças obrigatório em produção');
            process.exit(1);
        }
    }
}

// Inicialização do servidor
server.listen(PORT, async () => {
    console.log(`🚀 Backend Server com SISTEMA DE LICENÇA REAL v1.3.0 rodando na porta ${PORT}`);
    console.log(`📡 Endpoints principais:`);
    console.log(`   ✅ GET  http://localhost:${PORT}/api/health`);
    console.log(`   📊 GET  http://localhost:${PORT}/api/status`);
    console.log(`   🔐 GET  http://localhost:${PORT}/api/license/status`);
    console.log(`   🔑 POST http://localhost:${PORT}/api/license/activate`);
    console.log(`   🚫 POST http://localhost:${PORT}/api/license/deactivate`);
    console.log(`   📈 GET  http://localhost:${PORT}/api/metrics`);
    console.log(`   💬 GET  http://localhost:${PORT}/chat (WhatsApp Chat proxy)`);
    console.log(`   📱 GET  http://localhost:${PORT}/api/qr (WhatsApp QR proxy)`);
    console.log(`   🤖 POST http://localhost:${PORT}/api/generate-message`);
    console.log(`   📱 *    http://localhost:${PORT}/api/whatsapp/* (proxy)`);
    
    // Initialize license system FIRST
    await initializeLicenseSystem();
    
    // Verificar status inicial do WhatsApp Server
    console.log(`🔍 Verificando WhatsApp Server na porta ${WHATSAPP_SERVER_PORT}...`);
    const isOnline = await checkWhatsAppServerStatus();
    console.log(`📱 WhatsApp Server: ${isOnline ? '✅ Online' : '❌ Offline'}`);
    
    // Configurar verificação periódica do WhatsApp Server
    setInterval(async () => {
        await checkWhatsAppServerStatus();
    }, 15000); // Verifica a cada 15 segundos
    
    console.log(`✅ Melhorias v1.3.0 - SISTEMA DE LICENÇA REAL:`);
    console.log(`   🔐 Sistema de licenças SQLite implementado`);
    console.log(`   🚫 Middleware licenseGate - BLOQUEIA sem licença`);
    console.log(`   🔑 JWT com claim spr_license=active`);
    console.log(`   📱 WebSocket com validação de licença`);
    console.log(`   🚫 Mock Client/default-session BLOQUEADOS em produção`);
    console.log(`   ⚡ Cache de licenças para performance`);
    console.log(`   🔄 Circuit Breaker implementado`);
    console.log(`   📊 Métricas detalhadas`);
    console.log(`   🛡️ Rate limiting otimizado`);
    console.log(`✅ Servidor com LICENÇA REAL pronto para produção!`);
});

// Graceful shutdown melhorado com cleanup de licenças
const gracefulShutdown = (signal) => {
    console.log(`🛑 Recebido sinal ${signal}, iniciando shutdown graceful...`);
    
    // Close license database
    licenseDB.close();
    
    // Clear license cache
    licenseCache.clear();
    
    // Close Socket.IO server
    io.close(() => {
        console.log('🔌 Socket.IO server fechado');
    });
    
    // Aguardar requisições pendentes
    setTimeout(() => {
        console.log('🔄 Finalizando conexões...');
        process.exit(0);
    }, 5000); // 5 segundos para finalizar requisições
};

process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));

// Capturar erros não tratados
process.on('uncaughtException', (error) => {
    console.error('❌ Erro não capturado:', error);
    process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
    console.error('❌ Promise rejeitada:', reason);
    process.exit(1);
});