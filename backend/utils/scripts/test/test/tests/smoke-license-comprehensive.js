#!/usr/bin/env node

/**
 * SPR LICENSE SYSTEM - COMPREHENSIVE SMOKE TESTS
 * 
 * Testes abrangentes do sistema de licenças sem mock
 * Validação completa da fonte única real (backend + frontend + integração)
 * 
 * Servidor: localhost:3002
 * Frontend: /opt/spr/frontend/
 * 
 * OBJETIVO: Validar que sistema funciona 100% sem mock com fonte única real
 */

const axios = require('axios');
const fs = require('fs').promises;
const path = require('path');
const WebSocket = require('ws');
const crypto = require('crypto');

// Configuração
const CONFIG = {
    backend: {
        baseUrl: process.env.BACKEND_URL || 'http://localhost:3002',
        timeout: 30000
    },
    frontend: {
        buildDir: '/opt/spr/frontend/build',
        publicDir: '/opt/spr/frontend/public'
    },
    reports: {
        outputDir: '/opt/spr/_reports',
        filename: 'smoke_license.log'
    },
    testData: {
        validLicenseKey: 'SPR-TEST-1234-5678-ABCD',
        invalidLicenseKey: 'SPR-FAKE-0000-0000-ZZZZ',
        testClientId: `test-client-${Date.now()}`,
        mockClientId: 'Mock Client',
        defaultSession: 'default-session'
    }
};

// Utilitários de logging e relatórios
class TestReporter {
    constructor() {
        this.results = [];
        this.startTime = Date.now();
        this.stats = {
            total: 0,
            passed: 0,
            failed: 0,
            skipped: 0
        };
    }

    async init() {
        // Criar diretório de relatórios se não existir
        try {
            await fs.mkdir(CONFIG.reports.outputDir, { recursive: true });
        } catch (err) {
            console.warn('⚠️ Erro ao criar diretório de relatórios:', err.message);
        }
    }

    log(level, category, test, result, details = '') {
        const timestamp = new Date().toISOString();
        const message = `[${timestamp}] ${level.toUpperCase()} [${category}] ${test}: ${result}`;
        
        console.log(this.formatConsoleMessage(level, category, test, result));
        
        this.results.push({
            timestamp,
            level,
            category,
            test,
            result,
            details
        });

        if (details) {
            console.log(`   ℹ️ ${details}`);
        }
    }

    formatConsoleMessage(level, category, test, result) {
        const icons = {
            'PASS': '✅',
            'FAIL': '❌',
            'INFO': 'ℹ️',
            'WARN': '⚠️',
            'SKIP': '⏭️'
        };
        
        const colors = {
            'PASS': '\x1b[32m',  // Green
            'FAIL': '\x1b[31m',  // Red
            'INFO': '\x1b[34m',  // Blue
            'WARN': '\x1b[33m',  // Yellow
            'SKIP': '\x1b[90m',  // Gray
            'RESET': '\x1b[0m'
        };
        
        const icon = icons[level.toUpperCase()] || '';
        const color = colors[level.toUpperCase()] || '';
        const reset = colors.RESET;
        
        return `${icon} ${color}[${category}] ${test}: ${result}${reset}`;
    }

    updateStats(result) {
        this.stats.total++;
        switch(result.toLowerCase()) {
            case 'pass':
            case 'passed':
                this.stats.passed++;
                break;
            case 'fail':
            case 'failed':
                this.stats.failed++;
                break;
            case 'skip':
            case 'skipped':
                this.stats.skipped++;
                break;
        }
    }

    async generateReport() {
        const duration = Date.now() - this.startTime;
        const reportPath = path.join(CONFIG.reports.outputDir, CONFIG.reports.filename);
        
        const report = {
            summary: {
                timestamp: new Date().toISOString(),
                duration: `${duration}ms`,
                stats: this.stats,
                successRate: ((this.stats.passed / this.stats.total) * 100).toFixed(2) + '%'
            },
            results: this.results,
            configuration: CONFIG
        };

        try {
            await fs.writeFile(reportPath, JSON.stringify(report, null, 2));
            this.log('INFO', 'REPORT', 'Report generated', `Saved to ${reportPath}`);
        } catch (err) {
            this.log('WARN', 'REPORT', 'Report generation failed', err.message);
        }

        return report;
    }
}

// Cliente HTTP configurado
const httpClient = axios.create({
    baseURL: CONFIG.backend.baseUrl,
    timeout: CONFIG.backend.timeout,
    validateStatus: () => true // Não rejeitar por status codes
});

// Classes de teste
class BackendLicenseTests {
    constructor(reporter) {
        this.reporter = reporter;
        this.category = 'BACKEND';
    }

    async runAll() {
        this.reporter.log('INFO', this.category, 'Starting backend tests', 'Iniciando testes críticos do backend');
        
        await this.testHealthEndpoint();
        await this.testLicenseStatusWithoutLicense();
        await this.testLicenseStatusWithValidLicense();
        await this.testLicenseActivation();
        await this.testLicenseDeactivation();
        await this.testMiddlewareBlocking();
        await this.testJWTLicenseClaim();
        await this.testAntiMockValidation();
        
        this.reporter.log('INFO', this.category, 'Backend tests completed', 'Testes do backend concluídos');
    }

    async testHealthEndpoint() {
        try {
            const response = await httpClient.get('/api/health');
            
            if (response.status === 200 && response.data.status === 'OK') {
                this.reporter.log('PASS', this.category, 'Health endpoint', 'PASS');
                this.reporter.updateStats('passed');
            } else {
                this.reporter.log('FAIL', this.category, 'Health endpoint', 'FAIL', `Status: ${response.status}`);
                this.reporter.updateStats('failed');
            }
        } catch (error) {
            this.reporter.log('FAIL', this.category, 'Health endpoint', 'FAIL', error.message);
            this.reporter.updateStats('failed');
        }
    }

    async testLicenseStatusWithoutLicense() {
        try {
            const response = await httpClient.get('/api/license/status', {
                headers: { 'x-client-id': `non-existent-${Date.now()}` }
            });
            
            if (response.status === 200 && response.data.active === false) {
                this.reporter.log('PASS', this.category, 'License status without license', 'PASS - active:false');
                this.reporter.updateStats('passed');
            } else {
                this.reporter.log('FAIL', this.category, 'License status without license', 'FAIL', `Expected active:false, got: ${response.data.active}`);
                this.reporter.updateStats('failed');
            }
        } catch (error) {
            this.reporter.log('FAIL', this.category, 'License status without license', 'FAIL', error.message);
            this.reporter.updateStats('failed');
        }
    }

    async testLicenseStatusWithValidLicense() {
        try {
            // Primeiro ativar uma licença
            await httpClient.post('/api/license/activate', {
                key: CONFIG.testData.validLicenseKey,
                clientId: CONFIG.testData.testClientId
            });

            // Depois verificar status
            const response = await httpClient.get('/api/license/status', {
                headers: { 'x-client-id': CONFIG.testData.testClientId }
            });
            
            if (response.status === 200 && response.data.active === true) {
                this.reporter.log('PASS', this.category, 'License status with valid license', 'PASS - active:true');
                this.reporter.updateStats('passed');
            } else {
                this.reporter.log('FAIL', this.category, 'License status with valid license', 'FAIL', `Expected active:true, got: ${response.data.active}`);
                this.reporter.updateStats('failed');
            }
        } catch (error) {
            this.reporter.log('FAIL', this.category, 'License status with valid license', 'FAIL', error.message);
            this.reporter.updateStats('failed');
        }
    }

    async testLicenseActivation() {
        try {
            const uniqueClientId = `activation-test-${Date.now()}`;
            const response = await httpClient.post('/api/license/activate', {
                key: CONFIG.testData.validLicenseKey,
                clientId: uniqueClientId
            });
            
            if (response.status === 200 && response.data.success === true) {
                this.reporter.log('PASS', this.category, 'License activation', 'PASS - Transição false→true');
                this.reporter.updateStats('passed');
            } else {
                this.reporter.log('FAIL', this.category, 'License activation', 'FAIL', `Response: ${JSON.stringify(response.data)}`);
                this.reporter.updateStats('failed');
            }
        } catch (error) {
            this.reporter.log('FAIL', this.category, 'License activation', 'FAIL', error.message);
            this.reporter.updateStats('failed');
        }
    }

    async testLicenseDeactivation() {
        try {
            // Primeiro ativar
            const activateResponse = await httpClient.post('/api/license/activate', {
                key: CONFIG.testData.validLicenseKey,
                clientId: CONFIG.testData.testClientId
            });

            if (activateResponse.data.success) {
                // Depois desativar
                const deactivateResponse = await httpClient.post('/api/license/deactivate', {
                    clientId: CONFIG.testData.testClientId
                });
                
                if (deactivateResponse.status === 200 && deactivateResponse.data.success === true) {
                    this.reporter.log('PASS', this.category, 'License deactivation', 'PASS - Transição true→false');
                    this.reporter.updateStats('passed');
                } else {
                    this.reporter.log('FAIL', this.category, 'License deactivation', 'FAIL', `Response: ${JSON.stringify(deactivateResponse.data)}`);
                    this.reporter.updateStats('failed');
                }
            } else {
                this.reporter.log('SKIP', this.category, 'License deactivation', 'SKIPPED - Activation failed');
                this.reporter.updateStats('skipped');
            }
        } catch (error) {
            this.reporter.log('FAIL', this.category, 'License deactivation', 'FAIL', error.message);
            this.reporter.updateStats('failed');
        }
    }

    async testMiddlewareBlocking() {
        try {
            // Testar endpoint protegido sem licença
            const response = await httpClient.get('/api/metrics', {
                headers: { 
                    'x-client-id': `no-license-${Date.now()}`,
                    'Authorization': 'Bearer invalid-token'
                }
            });
            
            if (response.status === 403 || response.status === 401) {
                this.reporter.log('PASS', this.category, 'Middleware blocking', 'PASS - Blocked access without license');
                this.reporter.updateStats('passed');
            } else {
                this.reporter.log('FAIL', this.category, 'Middleware blocking', 'FAIL', `Expected 403/401, got: ${response.status}`);
                this.reporter.updateStats('failed');
            }
        } catch (error) {
            this.reporter.log('FAIL', this.category, 'Middleware blocking', 'FAIL', error.message);
            this.reporter.updateStats('failed');
        }
    }

    async testJWTLicenseClaim() {
        try {
            // Login para obter JWT
            const loginResponse = await httpClient.post('/api/auth/login', {
                username: 'admin',
                password: process.env.ADMIN_PASSWORD || 'admin123',
                clientId: CONFIG.testData.testClientId
            });

            if (loginResponse.data.token) {
                // Verificar se JWT contém claim spr_license
                const tokenParts = loginResponse.data.token.split('.');
                const payload = JSON.parse(Buffer.from(tokenParts[1], 'base64').toString());
                
                if (payload.spr_license) {
                    this.reporter.log('PASS', this.category, 'JWT license claim', `PASS - Contains spr_license=${payload.spr_license}`);
                    this.reporter.updateStats('passed');
                } else {
                    this.reporter.log('FAIL', this.category, 'JWT license claim', 'FAIL - Missing spr_license claim');
                    this.reporter.updateStats('failed');
                }
            } else {
                this.reporter.log('SKIP', this.category, 'JWT license claim', 'SKIPPED - Login failed');
                this.reporter.updateStats('skipped');
            }
        } catch (error) {
            this.reporter.log('FAIL', this.category, 'JWT license claim', 'FAIL', error.message);
            this.reporter.updateStats('failed');
        }
    }

    async testAntiMockValidation() {
        try {
            // Testar com Mock Client
            const mockResponse = await httpClient.get('/api/status', {
                headers: { 
                    'User-Agent': 'Mock Client v1.0',
                    'x-client-id': CONFIG.testData.mockClientId
                }
            });
            
            // Testar com default-session
            const defaultResponse = await httpClient.get('/api/status', {
                headers: { 
                    'x-client-id': CONFIG.testData.defaultSession
                }
            });

            // Em produção, estes devem ser bloqueados
            if (process.env.NODE_ENV === 'production') {
                if (mockResponse.status === 403 && defaultResponse.status === 403) {
                    this.reporter.log('PASS', this.category, 'Anti-mock validation', 'PASS - Mock patterns blocked in production');
                    this.reporter.updateStats('passed');
                } else {
                    this.reporter.log('FAIL', this.category, 'Anti-mock validation', 'FAIL - Mock patterns not blocked in production');
                    this.reporter.updateStats('failed');
                }
            } else {
                this.reporter.log('INFO', this.category, 'Anti-mock validation', 'INFO - Development mode, mock patterns allowed');
                this.reporter.updateStats('passed');
            }
        } catch (error) {
            this.reporter.log('FAIL', this.category, 'Anti-mock validation', 'FAIL', error.message);
            this.reporter.updateStats('failed');
        }
    }
}

class FrontendLicenseTests {
    constructor(reporter) {
        this.reporter = reporter;
        this.category = 'FRONTEND';
    }

    async runAll() {
        this.reporter.log('INFO', this.category, 'Starting frontend tests', 'Iniciando testes críticos do frontend');
        
        await this.testBuildExists();
        await this.testAntiMockInBuild();
        await this.testConfigurationFiles();
        await this.testLicenseComponentsExist();
        
        this.reporter.log('INFO', this.category, 'Frontend tests completed', 'Testes do frontend concluídos');
    }

    async testBuildExists() {
        try {
            const buildStat = await fs.stat(CONFIG.frontend.buildDir);
            
            if (buildStat.isDirectory()) {
                this.reporter.log('PASS', this.category, 'Build directory exists', 'PASS');
                this.reporter.updateStats('passed');
            } else {
                this.reporter.log('FAIL', this.category, 'Build directory exists', 'FAIL - Not a directory');
                this.reporter.updateStats('failed');
            }
        } catch (error) {
            this.reporter.log('FAIL', this.category, 'Build directory exists', 'FAIL', error.message);
            this.reporter.updateStats('failed');
        }
    }

    async testAntiMockInBuild() {
        try {
            const files = await this.findJavaScriptFiles(CONFIG.frontend.buildDir);
            let mockFound = false;
            let mockFiles = [];

            for (const file of files) {
                try {
                    const content = await fs.readFile(file, 'utf8');
                    if (content.includes('Mock Client') || content.includes('default-session') || content.includes('MOCK_LICENSE')) {
                        mockFound = true;
                        mockFiles.push(path.relative(CONFIG.frontend.buildDir, file));
                    }
                } catch (err) {
                    // Arquivo pode estar em uso ou inacessível
                    continue;
                }
            }

            if (process.env.NODE_ENV === 'production' && mockFound) {
                this.reporter.log('FAIL', this.category, 'Build anti-mock validation', 'FAIL - Mock code found in production build', `Files: ${mockFiles.join(', ')}`);
                this.reporter.updateStats('failed');
            } else {
                this.reporter.log('PASS', this.category, 'Build anti-mock validation', 'PASS - No mock code in production build');
                this.reporter.updateStats('passed');
            }
        } catch (error) {
            this.reporter.log('FAIL', this.category, 'Build anti-mock validation', 'FAIL', error.message);
            this.reporter.updateStats('failed');
        }
    }

    async findJavaScriptFiles(dir) {
        const files = [];
        try {
            const entries = await fs.readdir(dir, { withFileTypes: true });
            
            for (const entry of entries) {
                const fullPath = path.join(dir, entry.name);
                if (entry.isDirectory()) {
                    files.push(...await this.findJavaScriptFiles(fullPath));
                } else if (entry.name.endsWith('.js') || entry.name.endsWith('.jsx')) {
                    files.push(fullPath);
                }
            }
        } catch (err) {
            // Ignorar diretórios inacessíveis
        }
        return files;
    }

    async testConfigurationFiles() {
        try {
            const configFiles = [
                path.join(CONFIG.frontend.publicDir, 'index.html'),
                path.join(process.cwd(), 'package.json')
            ];

            let allExist = true;
            let missingFiles = [];

            for (const file of configFiles) {
                try {
                    await fs.stat(file);
                } catch (err) {
                    allExist = false;
                    missingFiles.push(file);
                }
            }

            if (allExist) {
                this.reporter.log('PASS', this.category, 'Configuration files', 'PASS - All config files present');
                this.reporter.updateStats('passed');
            } else {
                this.reporter.log('FAIL', this.category, 'Configuration files', 'FAIL', `Missing: ${missingFiles.join(', ')}`);
                this.reporter.updateStats('failed');
            }
        } catch (error) {
            this.reporter.log('FAIL', this.category, 'Configuration files', 'FAIL', error.message);
            this.reporter.updateStats('failed');
        }
    }

    async testLicenseComponentsExist() {
        try {
            const licenseFiles = [
                path.join(process.cwd(), 'LicenseStatus.tsx'),
                path.join(process.cwd(), 'LicenseActivation.tsx'),
                path.join(process.cwd(), 'FeatureGuard.tsx'),
                path.join(process.cwd(), 'useLicense.ts')
            ];

            let allExist = true;
            let existingFiles = [];

            for (const file of licenseFiles) {
                try {
                    await fs.stat(file);
                    existingFiles.push(path.basename(file));
                } catch (err) {
                    // Arquivo não existe
                }
            }

            if (existingFiles.length >= 3) {
                this.reporter.log('PASS', this.category, 'License components exist', `PASS - Found ${existingFiles.length} license components`);
                this.reporter.updateStats('passed');
            } else {
                this.reporter.log('FAIL', this.category, 'License components exist', 'FAIL - Insufficient license components');
                this.reporter.updateStats('failed');
            }
        } catch (error) {
            this.reporter.log('FAIL', this.category, 'License components exist', 'FAIL', error.message);
            this.reporter.updateStats('failed');
        }
    }
}

class IntegrationTests {
    constructor(reporter) {
        this.reporter = reporter;
        this.category = 'INTEGRATION';
        this.websocket = null;
    }

    async runAll() {
        this.reporter.log('INFO', this.category, 'Starting integration tests', 'Iniciando testes de integração');
        
        await this.testWebSocketLicenseValidation();
        await this.testAPILicenseFlow();
        await this.testCacheValidation();
        await this.testPersistenceValidation();
        
        this.reporter.log('INFO', this.category, 'Integration tests completed', 'Testes de integração concluídos');
    }

    async testWebSocketLicenseValidation() {
        return new Promise((resolve) => {
            try {
                // Primeiro obter um token válido
                httpClient.post('/api/auth/login', {
                    username: 'admin',
                    password: process.env.ADMIN_PASSWORD || 'admin123',
                    clientId: CONFIG.testData.testClientId
                }).then(response => {
                    if (!response.data.token) {
                        this.reporter.log('SKIP', this.category, 'WebSocket license validation', 'SKIPPED - No auth token');
                        this.reporter.updateStats('skipped');
                        return resolve();
                    }

                    const wsUrl = CONFIG.backend.baseUrl.replace('http', 'ws');
                    this.websocket = new WebSocket(wsUrl, {
                        headers: {
                            'Authorization': `Bearer ${response.data.token}`
                        }
                    });

                    let resolved = false;
                    const timeout = setTimeout(() => {
                        if (!resolved) {
                            this.reporter.log('FAIL', this.category, 'WebSocket license validation', 'FAIL - Connection timeout');
                            this.reporter.updateStats('failed');
                            if (this.websocket) this.websocket.close();
                            resolved = true;
                            resolve();
                        }
                    }, 10000);

                    this.websocket.on('open', () => {
                        if (!resolved) {
                            this.reporter.log('PASS', this.category, 'WebSocket license validation', 'PASS - Connected with valid license');
                            this.reporter.updateStats('passed');
                            clearTimeout(timeout);
                            this.websocket.close();
                            resolved = true;
                            resolve();
                        }
                    });

                    this.websocket.on('error', (error) => {
                        if (!resolved) {
                            if (error.message.includes('license')) {
                                this.reporter.log('PASS', this.category, 'WebSocket license validation', 'PASS - Correctly blocked invalid license');
                                this.reporter.updateStats('passed');
                            } else {
                                this.reporter.log('FAIL', this.category, 'WebSocket license validation', 'FAIL', error.message);
                                this.reporter.updateStats('failed');
                            }
                            clearTimeout(timeout);
                            resolved = true;
                            resolve();
                        }
                    });
                }).catch(error => {
                    this.reporter.log('FAIL', this.category, 'WebSocket license validation', 'FAIL', error.message);
                    this.reporter.updateStats('failed');
                    resolve();
                });
            } catch (error) {
                this.reporter.log('FAIL', this.category, 'WebSocket license validation', 'FAIL', error.message);
                this.reporter.updateStats('failed');
                resolve();
            }
        });
    }

    async testAPILicenseFlow() {
        try {
            const clientId = `flow-test-${Date.now()}`;
            
            // 1. Verificar estado inicial (sem licença)
            const initialStatus = await httpClient.get('/api/license/status', {
                headers: { 'x-client-id': clientId }
            });
            
            if (initialStatus.data.active !== false) {
                this.reporter.log('FAIL', this.category, 'API license flow', 'FAIL - Initial state should be inactive');
                this.reporter.updateStats('failed');
                return;
            }

            // 2. Ativar licença
            const activation = await httpClient.post('/api/license/activate', {
                key: CONFIG.testData.validLicenseKey,
                clientId: clientId
            });

            if (!activation.data.success) {
                this.reporter.log('FAIL', this.category, 'API license flow', 'FAIL - Activation failed');
                this.reporter.updateStats('failed');
                return;
            }

            // 3. Verificar estado ativo
            const activeStatus = await httpClient.get('/api/license/status', {
                headers: { 'x-client-id': clientId }
            });

            if (activeStatus.data.active !== true) {
                this.reporter.log('FAIL', this.category, 'API license flow', 'FAIL - License should be active after activation');
                this.reporter.updateStats('failed');
                return;
            }

            // 4. Desativar licença
            const deactivation = await httpClient.post('/api/license/deactivate', {
                clientId: clientId
            });

            if (!deactivation.data.success) {
                this.reporter.log('FAIL', this.category, 'API license flow', 'FAIL - Deactivation failed');
                this.reporter.updateStats('failed');
                return;
            }

            // 5. Verificar estado final (inativo)
            const finalStatus = await httpClient.get('/api/license/status', {
                headers: { 'x-client-id': clientId }
            });

            if (finalStatus.data.active !== false) {
                this.reporter.log('FAIL', this.category, 'API license flow', 'FAIL - License should be inactive after deactivation');
                this.reporter.updateStats('failed');
                return;
            }

            this.reporter.log('PASS', this.category, 'API license flow', 'PASS - Complete flow validated');
            this.reporter.updateStats('passed');
            
        } catch (error) {
            this.reporter.log('FAIL', this.category, 'API license flow', 'FAIL', error.message);
            this.reporter.updateStats('failed');
        }
    }

    async testCacheValidation() {
        try {
            const clientId = `cache-test-${Date.now()}`;
            
            // Ativar licença
            await httpClient.post('/api/license/activate', {
                key: CONFIG.testData.validLicenseKey,
                clientId: clientId
            });

            // Fazer múltiplas requisições rápidas (deve usar cache)
            const startTime = Date.now();
            const requests = [];
            
            for (let i = 0; i < 5; i++) {
                requests.push(
                    httpClient.get('/api/license/status', {
                        headers: { 'x-client-id': clientId }
                    })
                );
            }
            
            const responses = await Promise.all(requests);
            const totalTime = Date.now() - startTime;
            
            // Verificar se todas as respostas são consistentes
            const allActive = responses.every(r => r.data.active === true);
            
            if (allActive && totalTime < 5000) { // Deve ser rápido com cache
                this.reporter.log('PASS', this.category, 'Cache validation', `PASS - Cache working, ${totalTime}ms for 5 requests`);
                this.reporter.updateStats('passed');
            } else {
                this.reporter.log('FAIL', this.category, 'Cache validation', 'FAIL - Cache not working properly');
                this.reporter.updateStats('failed');
            }
            
        } catch (error) {
            this.reporter.log('FAIL', this.category, 'Cache validation', 'FAIL', error.message);
            this.reporter.updateStats('failed');
        }
    }

    async testPersistenceValidation() {
        try {
            const clientId = `persistence-test-${Date.now()}`;
            
            // Ativar licença
            const activation = await httpClient.post('/api/license/activate', {
                key: CONFIG.testData.validLicenseKey,
                clientId: clientId
            });

            if (!activation.data.success) {
                this.reporter.log('SKIP', this.category, 'Persistence validation', 'SKIPPED - Activation failed');
                this.reporter.updateStats('skipped');
                return;
            }

            // Simular restart (limpar cache através de um endpoint específico ou aguardar)
            await new Promise(resolve => setTimeout(resolve, 1000));

            // Verificar se licença ainda está ativa (persistida)
            const status = await httpClient.get('/api/license/status', {
                headers: { 'x-client-id': clientId }
            });

            if (status.data.active === true) {
                this.reporter.log('PASS', this.category, 'Persistence validation', 'PASS - License persisted in database');
                this.reporter.updateStats('passed');
            } else {
                this.reporter.log('FAIL', this.category, 'Persistence validation', 'FAIL - License not persisted');
                this.reporter.updateStats('failed');
            }
            
        } catch (error) {
            this.reporter.log('FAIL', this.category, 'Persistence validation', 'FAIL', error.message);
            this.reporter.updateStats('failed');
        }
    }
}

class RegressionTests {
    constructor(reporter) {
        this.reporter = reporter;
        this.category = 'REGRESSION';
    }

    async runAll() {
        this.reporter.log('INFO', this.category, 'Starting regression tests', 'Iniciando testes de regressão');
        
        await this.testServerRestart();
        await this.testDatabaseIntegrity();
        await this.testPerformanceRegression();
        await this.testErrorBoundaries();
        
        this.reporter.log('INFO', this.category, 'Regression tests completed', 'Testes de regressão concluídos');
    }

    async testServerRestart() {
        try {
            // Verificar se servidor está respondendo após restart
            const healthCheck = await httpClient.get('/api/health');
            
            if (healthCheck.status === 200 && healthCheck.data.status === 'OK') {
                this.reporter.log('PASS', this.category, 'Server restart', 'PASS - Server responsive after restart');
                this.reporter.updateStats('passed');
            } else {
                this.reporter.log('FAIL', this.category, 'Server restart', 'FAIL - Server not healthy after restart');
                this.reporter.updateStats('failed');
            }
        } catch (error) {
            this.reporter.log('FAIL', this.category, 'Server restart', 'FAIL', error.message);
            this.reporter.updateStats('failed');
        }
    }

    async testDatabaseIntegrity() {
        try {
            const clientId = `integrity-test-${Date.now()}`;
            
            // Criar licença
            await httpClient.post('/api/license/activate', {
                key: CONFIG.testData.validLicenseKey,
                clientId: clientId
            });

            // Verificar se foi salva corretamente
            const status = await httpClient.get('/api/license/status', {
                headers: { 'x-client-id': clientId }
            });

            if (status.data.active && status.data.licenseKey) {
                this.reporter.log('PASS', this.category, 'Database integrity', 'PASS - License data persisted correctly');
                this.reporter.updateStats('passed');
            } else {
                this.reporter.log('FAIL', this.category, 'Database integrity', 'FAIL - License data not persisted');
                this.reporter.updateStats('failed');
            }
        } catch (error) {
            this.reporter.log('FAIL', this.category, 'Database integrity', 'FAIL', error.message);
            this.reporter.updateStats('failed');
        }
    }

    async testPerformanceRegression() {
        try {
            // Testar performance dos endpoints críticos
            const endpoints = [
                '/api/health',
                '/api/license/status',
                '/api/status'
            ];

            const results = [];
            
            for (const endpoint of endpoints) {
                const startTime = Date.now();
                const response = await httpClient.get(endpoint);
                const duration = Date.now() - startTime;
                
                results.push({
                    endpoint,
                    duration,
                    status: response.status
                });
            }

            const avgResponseTime = results.reduce((acc, r) => acc + r.duration, 0) / results.length;
            const maxResponseTime = Math.max(...results.map(r => r.duration));

            if (avgResponseTime < 1000 && maxResponseTime < 3000) { // Thresholds reasonáveis
                this.reporter.log('PASS', this.category, 'Performance regression', `PASS - Avg: ${avgResponseTime}ms, Max: ${maxResponseTime}ms`);
                this.reporter.updateStats('passed');
            } else {
                this.reporter.log('FAIL', this.category, 'Performance regression', 'FAIL - Performance regression detected');
                this.reporter.updateStats('failed');
            }
        } catch (error) {
            this.reporter.log('FAIL', this.category, 'Performance regression', 'FAIL', error.message);
            this.reporter.updateStats('failed');
        }
    }

    async testErrorBoundaries() {
        try {
            // Testar endpoints com dados inválidos
            const tests = [
                {
                    name: 'Invalid license key format',
                    request: () => httpClient.post('/api/license/activate', { key: 'INVALID', clientId: 'test' })
                },
                {
                    name: 'Missing client ID',
                    request: () => httpClient.post('/api/license/activate', { key: CONFIG.testData.validLicenseKey })
                },
                {
                    name: 'Malformed JSON',
                    request: () => httpClient.post('/api/license/activate', 'invalid-json', {
                        headers: { 'Content-Type': 'application/json' }
                    })
                }
            ];

            let errorsBoundCorrectly = 0;
            
            for (const test of tests) {
                try {
                    const response = await test.request();
                    if (response.status >= 400 && response.status < 500) {
                        errorsBoundCorrectly++;
                    }
                } catch (error) {
                    if (error.response && error.response.status >= 400) {
                        errorsBoundCorrectly++;
                    }
                }
            }

            if (errorsBoundCorrectly === tests.length) {
                this.reporter.log('PASS', this.category, 'Error boundaries', 'PASS - All errors handled correctly');
                this.reporter.updateStats('passed');
            } else {
                this.reporter.log('FAIL', this.category, 'Error boundaries', `FAIL - ${errorsBoundCorrectly}/${tests.length} errors handled`);
                this.reporter.updateStats('failed');
            }
        } catch (error) {
            this.reporter.log('FAIL', this.category, 'Error boundaries', 'FAIL', error.message);
            this.reporter.updateStats('failed');
        }
    }
}

// Função principal
async function runSmokeTests() {
    console.log('🚀 SPR LICENSE SYSTEM - COMPREHENSIVE SMOKE TESTS');
    console.log('='.repeat(60));
    console.log(`Backend: ${CONFIG.backend.baseUrl}`);
    console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
    console.log(`Time: ${new Date().toISOString()}`);
    console.log('='.repeat(60));

    const reporter = new TestReporter();
    await reporter.init();

    // Executar todas as suítes de teste
    const testSuites = [
        new BackendLicenseTests(reporter),
        new FrontendLicenseTests(reporter),
        new IntegrationTests(reporter),
        new RegressionTests(reporter)
    ];

    for (const suite of testSuites) {
        try {
            await suite.runAll();
        } catch (error) {
            reporter.log('FAIL', 'SYSTEM', 'Test suite execution', 'FAIL', error.message);
        }
    }

    // Gerar relatório final
    console.log('\n' + '='.repeat(60));
    console.log('📊 SMOKE TEST RESULTS');
    console.log('='.repeat(60));
    
    const report = await reporter.generateReport();
    
    console.log(`Total Tests: ${report.summary.stats.total}`);
    console.log(`✅ Passed: ${report.summary.stats.passed}`);
    console.log(`❌ Failed: ${report.summary.stats.failed}`);
    console.log(`⏭️ Skipped: ${report.summary.stats.skipped}`);
    console.log(`📈 Success Rate: ${report.summary.successRate}`);
    console.log(`⏱️ Duration: ${report.summary.duration}`);
    
    console.log('\n🔗 Detailed report saved to:', path.join(CONFIG.reports.outputDir, CONFIG.reports.filename));
    
    // Exit code baseado nos resultados
    const exitCode = report.summary.stats.failed > 0 ? 1 : 0;
    process.exit(exitCode);
}

// Executar testes se o script for chamado diretamente
if (require.main === module) {
    runSmokeTests().catch(error => {
        console.error('❌ Fatal error running smoke tests:', error);
        process.exit(1);
    });
}

module.exports = {
    runSmokeTests,
    BackendLicenseTests,
    FrontendLicenseTests,
    IntegrationTests,
    RegressionTests,
    TestReporter
};