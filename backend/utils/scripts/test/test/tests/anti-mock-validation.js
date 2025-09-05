#!/usr/bin/env node

/**
 * SPR LICENSE SYSTEM - ANTI-MOCK VALIDATION TESTS
 * 
 * Validações específicas para detectar e bloquear sistemas mock
 * Garantir que apenas fonte única real seja aceita em produção
 * 
 * CRÍTICO: Testes que DEVEM falhar em produção com mock
 */

const axios = require('axios');
const fs = require('fs').promises;
const path = require('path');
const crypto = require('crypto');

const CONFIG = {
    backend: {
        baseUrl: process.env.BACKEND_URL || 'http://localhost:3002',
        timeout: 15000
    },
    environment: process.env.NODE_ENV || 'development',
    reports: {
        outputDir: '/opt/spr/_reports'
    }
};

class AntiMockValidator {
    constructor() {
        this.results = [];
        this.startTime = Date.now();
        this.httpClient = axios.create({
            baseURL: CONFIG.backend.baseUrl,
            timeout: CONFIG.backend.timeout,
            validateStatus: () => true
        });
    }

    log(level, test, result, details = '') {
        const timestamp = new Date().toISOString();
        const message = `[ANTI-MOCK] ${test}: ${result}`;
        
        console.log(this.formatConsoleMessage(level, test, result));
        
        this.results.push({
            timestamp,
            level,
            category: 'ANTI-MOCK',
            test,
            result,
            details
        });

        if (details) {
            console.log(`   ℹ️ ${details}`);
        }
    }

    formatConsoleMessage(level, test, result) {
        const icons = {
            'PASS': '✅',
            'FAIL': '❌', 
            'CRITICAL': '🚫',
            'INFO': 'ℹ️',
            'WARN': '⚠️'
        };
        
        const colors = {
            'PASS': '\x1b[32m',
            'FAIL': '\x1b[31m',
            'CRITICAL': '\x1b[91m',
            'INFO': '\x1b[34m',
            'WARN': '\x1b[33m',
            'RESET': '\x1b[0m'
        };
        
        const icon = icons[level] || '';
        const color = colors[level] || '';
        const reset = colors.RESET;
        
        return `${icon} ${color}[ANTI-MOCK] ${test}: ${result}${reset}`;
    }

    async runAll() {
        console.log('🚫 SPR LICENSE SYSTEM - ANTI-MOCK VALIDATION');
        console.log('='.repeat(60));
        console.log(`Environment: ${CONFIG.environment}`);
        console.log(`Backend: ${CONFIG.backend.baseUrl}`);
        console.log(`Time: ${new Date().toISOString()}`);
        console.log('='.repeat(60));

        // Executar validações anti-mock
        await this.validateMockClientRejection();
        await this.validateDefaultSessionRejection();
        await this.validateMockLicenseKeyRejection();
        await this.validateMockUserAgentBlocking();
        await this.validateBuildMockDetection();
        await this.validateEnvironmentVariables();
        await this.validateDatabaseMockPrevention();
        await this.validateProductionModeEnforcement();
        
        await this.generateReport();
    }

    async validateMockClientRejection() {
        try {
            this.log('INFO', 'Mock Client rejection', 'TESTING');
            
            // Testar diferentes variações de Mock Client
            const mockClients = [
                'Mock Client',
                'MockClient',
                'mock-client',
                'Mock Client v1.0',
                'Test Mock Client',
                'SPR Mock Client'
            ];
            
            let allBlocked = true;
            let blockedCount = 0;
            
            for (const mockClient of mockClients) {
                const response = await this.httpClient.get('/api/license/status', {
                    headers: {
                        'User-Agent': mockClient,
                        'X-Client-Id': mockClient
                    }
                });
                
                if (CONFIG.environment === 'production') {
                    if (response.status === 403) {
                        blockedCount++;
                    } else {
                        allBlocked = false;
                        this.log('CRITICAL', 'Mock Client rejection', `CRITICAL - ${mockClient} not blocked in production`);
                    }
                } else {
                    // Em desenvolvimento, pode ou não ser bloqueado
                    if (response.status === 403) {
                        blockedCount++;
                    }
                }
            }
            
            if (CONFIG.environment === 'production') {
                if (allBlocked && blockedCount === mockClients.length) {
                    this.log('PASS', 'Mock Client rejection', 'PASS - All mock clients blocked in production');
                } else {
                    this.log('CRITICAL', 'Mock Client rejection', `CRITICAL - ${blockedCount}/${mockClients.length} mock clients blocked`);
                }
            } else {
                this.log('INFO', 'Mock Client rejection', `INFO - Development mode: ${blockedCount}/${mockClients.length} blocked`);
            }
            
        } catch (error) {
            this.log('FAIL', 'Mock Client rejection', 'FAIL', error.message);
        }
    }

    async validateDefaultSessionRejection() {
        try {
            this.log('INFO', 'Default session rejection', 'TESTING');
            
            const defaultSessions = [
                'default-session',
                'default',
                'defaultSession',
                'test-session',
                'mock-session',
                'demo-session'
            ];
            
            let allBlocked = true;
            let blockedCount = 0;
            
            for (const session of defaultSessions) {
                const response = await this.httpClient.get('/api/license/status', {
                    headers: {
                        'X-Client-Id': session
                    }
                });
                
                // Verificar se sessão default não tem licença ativa
                if (response.data && response.data.active === false) {
                    blockedCount++;
                } else if (response.data && response.data.active === true) {
                    allBlocked = false;
                    
                    if (CONFIG.environment === 'production') {
                        this.log('CRITICAL', 'Default session rejection', `CRITICAL - ${session} has active license in production`);
                    }
                }
            }
            
            if (CONFIG.environment === 'production') {
                if (allBlocked) {
                    this.log('PASS', 'Default session rejection', 'PASS - No default sessions have active licenses in production');
                } else {
                    this.log('CRITICAL', 'Default session rejection', 'CRITICAL - Default sessions found with active licenses');
                }
            } else {
                this.log('INFO', 'Default session rejection', `INFO - Development mode: ${blockedCount}/${defaultSessions.length} without license`);
            }
            
        } catch (error) {
            this.log('FAIL', 'Default session rejection', 'FAIL', error.message);
        }
    }

    async validateMockLicenseKeyRejection() {
        try {
            this.log('INFO', 'Mock license key rejection', 'TESTING');
            
            const mockLicenseKeys = [
                'MOCK-1234-5678-9012-ABCD',
                'TEST-0000-0000-0000-0000',
                'FAKE-FAKE-FAKE-FAKE-FAKE',
                'SPR-MOCK-MOCK-MOCK-MOCK',
                'DEV-1111-2222-3333-4444'
            ];
            
            let allRejected = true;
            
            for (const mockKey of mockLicenseKeys) {
                const response = await this.httpClient.post('/api/license/activate', {
                    key: mockKey,
                    clientId: `test-${Date.now()}`
                });
                
                if (response.data && response.data.success === true) {
                    allRejected = false;
                    
                    if (CONFIG.environment === 'production') {
                        this.log('CRITICAL', 'Mock license key rejection', `CRITICAL - Mock license ${mockKey} accepted in production`);
                    }
                }
            }
            
            if (CONFIG.environment === 'production') {
                if (allRejected) {
                    this.log('PASS', 'Mock license key rejection', 'PASS - All mock license keys rejected in production');
                } else {
                    this.log('CRITICAL', 'Mock license key rejection', 'CRITICAL - Some mock license keys accepted');
                }
            } else {
                this.log('INFO', 'Mock license key rejection', `INFO - Development mode: mock keys ${allRejected ? 'rejected' : 'possibly accepted'}`);
            }
            
        } catch (error) {
            this.log('FAIL', 'Mock license key rejection', 'FAIL', error.message);
        }
    }

    async validateMockUserAgentBlocking() {
        try {
            this.log('INFO', 'Mock User-Agent blocking', 'TESTING');
            
            const mockUserAgents = [
                'Mozilla/5.0 (Mock Browser)',
                'TestClient/1.0',
                'MockHTTP/1.0', 
                'PostmanRuntime/7.29.0',
                'curl/7.68.0',
                'wget/1.20.3'
            ];
            
            let suspiciousAllowed = 0;
            
            for (const userAgent of mockUserAgents) {
                const response = await this.httpClient.get('/api/status', {
                    headers: {
                        'User-Agent': userAgent
                    }
                });
                
                // Em produção, alguns user agents podem ser suspeitos
                if (CONFIG.environment === 'production' && response.status === 200) {
                    if (userAgent.includes('Mock') || userAgent.includes('Test')) {
                        suspiciousAllowed++;
                        this.log('WARN', 'Mock User-Agent blocking', `WARN - Suspicious UA allowed: ${userAgent}`);
                    }
                }
            }
            
            if (CONFIG.environment === 'production') {
                if (suspiciousAllowed === 0) {
                    this.log('PASS', 'Mock User-Agent blocking', 'PASS - No obviously suspicious User-Agents allowed');
                } else {
                    this.log('WARN', 'Mock User-Agent blocking', `WARN - ${suspiciousAllowed} suspicious User-Agents allowed`);
                }
            } else {
                this.log('INFO', 'Mock User-Agent blocking', 'INFO - Development mode allows all User-Agents');
            }
            
        } catch (error) {
            this.log('FAIL', 'Mock User-Agent blocking', 'FAIL', error.message);
        }
    }

    async validateBuildMockDetection() {
        try {
            this.log('INFO', 'Build mock detection', 'TESTING');
            
            // Verificar se o build contém código mock
            const buildPaths = [
                '/opt/spr/frontend/build',
                '/opt/spr/frontend/dist',
                path.join(process.cwd(), 'dist'),
                path.join(process.cwd(), 'build')
            ];
            
            let mockFoundInBuild = false;
            let checkedPaths = [];
            
            for (const buildPath of buildPaths) {
                try {
                    const exists = await fs.stat(buildPath);
                    if (exists.isDirectory()) {
                        checkedPaths.push(buildPath);
                        const mockFound = await this.scanForMockCode(buildPath);
                        if (mockFound.length > 0) {
                            mockFoundInBuild = true;
                            
                            if (CONFIG.environment === 'production') {
                                this.log('CRITICAL', 'Build mock detection', `CRITICAL - Mock code found in production build: ${mockFound.join(', ')}`);
                            } else {
                                this.log('WARN', 'Build mock detection', `WARN - Mock code found in build: ${mockFound.join(', ')}`);
                            }
                        }
                    }
                } catch (err) {
                    // Path não existe ou não é acessível
                    continue;
                }
            }
            
            if (checkedPaths.length === 0) {
                this.log('WARN', 'Build mock detection', 'WARN - No build directories found to check');
            } else if (!mockFoundInBuild) {
                this.log('PASS', 'Build mock detection', `PASS - No mock code found in ${checkedPaths.length} build directories`);
            }
            
        } catch (error) {
            this.log('FAIL', 'Build mock detection', 'FAIL', error.message);
        }
    }

    async scanForMockCode(directory) {
        const mockPatterns = [
            'Mock Client',
            'MOCK_LICENSE',
            'mockLicense',
            'fake-license',
            'test-license-key',
            'default-session',
            'mockSession'
        ];
        
        const foundMocks = [];
        
        try {
            const files = await this.findJavaScriptFiles(directory);
            
            for (const file of files) {
                try {
                    const content = await fs.readFile(file, 'utf8');
                    
                    for (const pattern of mockPatterns) {
                        if (content.includes(pattern)) {
                            foundMocks.push(`${pattern} in ${path.basename(file)}`);
                        }
                    }
                } catch (readError) {
                    // Arquivo pode estar em uso
                    continue;
                }
            }
        } catch (scanError) {
            // Diretório pode não ser acessível
        }
        
        return foundMocks;
    }

    async findJavaScriptFiles(dir) {
        const files = [];
        try {
            const entries = await fs.readdir(dir, { withFileTypes: true });
            
            for (const entry of entries) {
                const fullPath = path.join(dir, entry.name);
                if (entry.isDirectory() && entry.name !== 'node_modules') {
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

    async validateEnvironmentVariables() {
        try {
            this.log('INFO', 'Environment variables validation', 'TESTING');
            
            const criticalEnvVars = {
                'LICENSE_MODE': CONFIG.environment === 'production' ? 'production' : null,
                'LICENSE_MOCK': CONFIG.environment === 'production' ? ['0', 'false', undefined] : null,
                'NO_MOCK': CONFIG.environment === 'production' ? ['1', 'true'] : null,
                'NODE_ENV': CONFIG.environment === 'production' ? 'production' : null
            };
            
            let envVarsValid = true;
            
            for (const [envVar, expectedValues] of Object.entries(criticalEnvVars)) {
                const actualValue = process.env[envVar];
                
                if (CONFIG.environment === 'production' && expectedValues !== null) {
                    if (Array.isArray(expectedValues)) {
                        if (!expectedValues.includes(actualValue)) {
                            envVarsValid = false;
                            this.log('CRITICAL', 'Environment variables validation', `CRITICAL - ${envVar}=${actualValue}, expected one of: ${expectedValues.join(', ')}`);
                        }
                    } else if (actualValue !== expectedValues) {
                        envVarsValid = false;
                        this.log('CRITICAL', 'Environment variables validation', `CRITICAL - ${envVar}=${actualValue}, expected: ${expectedValues}`);
                    }
                }
            }
            
            if (envVarsValid || CONFIG.environment !== 'production') {
                this.log('PASS', 'Environment variables validation', 'PASS - Environment variables correctly configured');
            }
            
        } catch (error) {
            this.log('FAIL', 'Environment variables validation', 'FAIL', error.message);
        }
    }

    async validateDatabaseMockPrevention() {
        try {
            this.log('INFO', 'Database mock prevention', 'TESTING');
            
            // Verificar se existe licenças de teste/mock ativas
            const testClientIds = [
                'mock-client',
                'test-client',
                'demo-client', 
                'default-session',
                'fake-client'
            ];
            
            let mockLicensesFound = 0;
            
            for (const clientId of testClientIds) {
                const response = await this.httpClient.get('/api/license/status', {
                    headers: { 'X-Client-Id': clientId }
                });
                
                if (response.data && response.data.active === true) {
                    mockLicensesFound++;
                    
                    if (CONFIG.environment === 'production') {
                        this.log('CRITICAL', 'Database mock prevention', `CRITICAL - Mock license active for ${clientId} in production`);
                    }
                }
            }
            
            if (CONFIG.environment === 'production') {
                if (mockLicensesFound === 0) {
                    this.log('PASS', 'Database mock prevention', 'PASS - No mock licenses active in production database');
                } else {
                    this.log('CRITICAL', 'Database mock prevention', `CRITICAL - ${mockLicensesFound} mock licenses found in production`);
                }
            } else {
                this.log('INFO', 'Database mock prevention', `INFO - Development mode: ${mockLicensesFound} test licenses found`);
            }
            
        } catch (error) {
            this.log('FAIL', 'Database mock prevention', 'FAIL', error.message);
        }
    }

    async validateProductionModeEnforcement() {
        try {
            this.log('INFO', 'Production mode enforcement', 'TESTING');
            
            if (CONFIG.environment === 'production') {
                // Verificar se servidor está executando em modo produção
                const healthResponse = await this.httpClient.get('/api/health');
                
                if (healthResponse.data) {
                    const isProduction = healthResponse.data.environment === 'production' ||
                                       healthResponse.data.mode === 'production' ||
                                       healthResponse.data.version === 'production';
                    
                    if (isProduction) {
                        this.log('PASS', 'Production mode enforcement', 'PASS - Server running in production mode');
                    } else {
                        this.log('CRITICAL', 'Production mode enforcement', 'CRITICAL - Server not in production mode');
                    }
                }
                
                // Verificar se debug está desabilitado
                const debugDisabled = !process.env.DEBUG || process.env.DEBUG === 'false';
                if (debugDisabled) {
                    this.log('PASS', 'Production mode enforcement', 'PASS - Debug mode disabled');
                } else {
                    this.log('WARN', 'Production mode enforcement', 'WARN - Debug mode may be enabled in production');
                }
                
            } else {
                this.log('INFO', 'Production mode enforcement', 'INFO - Not in production environment');
            }
            
        } catch (error) {
            this.log('FAIL', 'Production mode enforcement', 'FAIL', error.message);
        }
    }

    async generateReport() {
        const duration = Date.now() - this.startTime;
        const reportPath = path.join(CONFIG.reports.outputDir, 'anti_mock_validation.json');
        
        const passed = this.results.filter(r => r.result.includes('PASS')).length;
        const failed = this.results.filter(r => r.result.includes('FAIL')).length;
        const critical = this.results.filter(r => r.result.includes('CRITICAL')).length;
        const warnings = this.results.filter(r => r.result.includes('WARN')).length;
        
        const report = {
            summary: {
                timestamp: new Date().toISOString(),
                environment: CONFIG.environment,
                duration: `${duration}ms`,
                total: this.results.length,
                passed,
                failed,
                critical,
                warnings,
                securityScore: critical === 0 ? 'HIGH' : critical < 3 ? 'MEDIUM' : 'LOW'
            },
            results: this.results,
            configuration: CONFIG
        };

        try {
            await fs.mkdir(CONFIG.reports.outputDir, { recursive: true });
            await fs.writeFile(reportPath, JSON.stringify(report, null, 2));
        } catch (err) {
            console.warn('⚠️ Failed to save anti-mock report:', err.message);
        }

        console.log('\n' + '='.repeat(60));
        console.log('🚫 ANTI-MOCK VALIDATION RESULTS');
        console.log('='.repeat(60));
        console.log(`Environment: ${CONFIG.environment}`);
        console.log(`Total Checks: ${report.summary.total}`);
        console.log(`✅ Passed: ${passed}`);
        console.log(`❌ Failed: ${failed}`);
        console.log(`🚫 Critical: ${critical}`);
        console.log(`⚠️ Warnings: ${warnings}`);
        console.log(`🔐 Security Score: ${report.summary.securityScore}`);
        console.log(`⏱️ Duration: ${report.summary.duration}`);
        
        if (critical > 0) {
            console.log('\n🚨 CRITICAL ISSUES DETECTED:');
            console.log('These issues MUST be resolved before production deployment!');
        }
        
        console.log(`\n📄 Full report: ${reportPath}`);
        
        return report;
    }
}

// Executar validação anti-mock
async function runAntiMockValidation() {
    const validator = new AntiMockValidator();
    const report = await validator.runAll();
    
    // Exit code baseado na criticidade
    const exitCode = report.summary.critical > 0 ? 2 : 
                    report.summary.failed > 0 ? 1 : 0;
    process.exit(exitCode);
}

// Executar se chamado diretamente
if (require.main === module) {
    runAntiMockValidation().catch(error => {
        console.error('❌ Anti-mock validation failed:', error);
        process.exit(3);
    });
}

module.exports = { runAntiMockValidation, AntiMockValidator };