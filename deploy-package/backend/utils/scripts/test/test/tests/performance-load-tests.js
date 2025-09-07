#!/usr/bin/env node

/**
 * SPR LICENSE SYSTEM - PERFORMANCE & LOAD TESTS
 * 
 * Testa performance e comportamento sob carga do sistema de licenças
 * Valida se o sistema mantém performance adequada com múltiplas requisições
 */

const axios = require('axios');
const fs = require('fs').promises;
const path = require('path');
const cluster = require('cluster');
const os = require('os');

const CONFIG = {
    backend: {
        baseUrl: process.env.BACKEND_URL || 'http://localhost:3002',
        timeout: 30000
    },
    load_test: {
        concurrent_users: parseInt(process.env.CONCURRENT_USERS) || 10,
        test_duration_seconds: parseInt(process.env.TEST_DURATION) || 60,
        ramp_up_seconds: parseInt(process.env.RAMP_UP) || 10,
        think_time_ms: parseInt(process.env.THINK_TIME) || 1000
    },
    performance_thresholds: {
        max_response_time_ms: 3000,
        min_success_rate: 95,
        max_error_rate: 5,
        max_95th_percentile_ms: 5000
    },
    reports: {
        outputDir: '/opt/spr/_reports'
    }
};

class PerformanceTester {
    constructor() {
        this.results = {
            start_time: Date.now(),
            end_time: null,
            requests: [],
            errors: [],
            metrics: {
                total_requests: 0,
                successful_requests: 0,
                failed_requests: 0,
                avg_response_time: 0,
                min_response_time: Infinity,
                max_response_time: 0,
                p95_response_time: 0,
                requests_per_second: 0
            }
        };
        
        this.httpClient = axios.create({
            baseURL: CONFIG.backend.baseUrl,
            timeout: CONFIG.backend.timeout,
            validateStatus: () => true
        });
    }

    log(level, message, details = null) {
        const timestamp = new Date().toISOString();
        const colors = {
            'INFO': '\x1b[34m',
            'SUCCESS': '\x1b[32m', 
            'WARNING': '\x1b[33m',
            'ERROR': '\x1b[31m',
            'RESET': '\x1b[0m'
        };
        
        const color = colors[level] || colors.RESET;
        console.log(`${color}[${timestamp}] [PERF] ${message}${colors.RESET}`);
        
        if (details) {
            console.log(`   ℹ️ ${JSON.stringify(details, null, 2)}`);
        }
    }

    async runPerformanceTests() {
        this.log('INFO', '🚀 Iniciando testes de performance do sistema de licenças');
        this.log('INFO', `Configuração: ${CONFIG.load_test.concurrent_users} usuários concorrentes por ${CONFIG.load_test.test_duration_seconds}s`);
        
        try {
            // Primeiro, executar testes de baseline
            await this.runBaselineTests();
            
            // Depois, executar testes de carga
            await this.runLoadTests();
            
            // Calcular métricas finais
            await this.calculateMetrics();
            
            // Gerar relatório
            await this.generateReport();
            
            // Avaliar resultados
            this.evaluateResults();
            
        } catch (error) {
            this.log('ERROR', 'Erro durante testes de performance', error.message);
            throw error;
        }
    }

    async runBaselineTests() {
        this.log('INFO', '📊 Executando testes baseline (single user)');
        
        const baselineTests = [
            { name: 'Health Check', method: 'GET', path: '/api/health' },
            { name: 'License Status (No License)', method: 'GET', path: '/api/license/status', headers: { 'X-Client-Id': `baseline-test-${Date.now()}` }},
            { name: 'System Status', method: 'GET', path: '/api/status' },
        ];
        
        for (const test of baselineTests) {
            const startTime = Date.now();
            
            try {
                const response = await this.httpClient({
                    method: test.method.toLowerCase(),
                    url: test.path,
                    headers: test.headers || {}
                });
                
                const responseTime = Date.now() - startTime;
                
                this.recordRequest(test.name, response.status, responseTime, 'baseline');
                
                this.log('SUCCESS', `${test.name}: ${response.status} em ${responseTime}ms`);
                
            } catch (error) {
                const responseTime = Date.now() - startTime;
                this.recordRequest(test.name, 0, responseTime, 'baseline', error.message);
                this.log('ERROR', `${test.name}: Erro após ${responseTime}ms`, error.message);
            }
            
            // Think time
            await new Promise(resolve => setTimeout(resolve, 500));
        }
    }

    async runLoadTests() {
        this.log('INFO', '🔥 Iniciando teste de carga');
        
        const testScenarios = [
            {
                name: 'License Status Check Load Test',
                weight: 60, // 60% das requisições
                execute: () => this.testLicenseStatusLoad()
            },
            {
                name: 'License Activation Load Test', 
                weight: 20, // 20% das requisições
                execute: () => this.testLicenseActivationLoad()
            },
            {
                name: 'Health Check Load Test',
                weight: 20, // 20% das requisições 
                execute: () => this.testHealthCheckLoad()
            }
        ];
        
        // Calcular número de workers baseado na configuração
        const numWorkers = Math.min(CONFIG.load_test.concurrent_users, os.cpus().length);
        
        if (cluster.isMaster) {
            this.log('INFO', `Criando ${numWorkers} workers para ${CONFIG.load_test.concurrent_users} usuários virtuais`);
            
            // Criar workers
            const workers = [];
            for (let i = 0; i < numWorkers; i++) {
                const worker = cluster.fork({
                    WORKER_ID: i,
                    USERS_PER_WORKER: Math.ceil(CONFIG.load_test.concurrent_users / numWorkers),
                    TEST_SCENARIOS: JSON.stringify(testScenarios)
                });
                workers.push(worker);
                
                worker.on('message', (message) => {
                    if (message.type === 'request_result') {
                        this.recordRequest(
                            message.data.name,
                            message.data.status,
                            message.data.responseTime,
                            'load_test',
                            message.data.error
                        );
                    }
                });
            }
            
            // Aguardar teste terminar
            const testDuration = CONFIG.load_test.test_duration_seconds * 1000;
            await new Promise(resolve => setTimeout(resolve, testDuration));
            
            // Finalizar workers
            workers.forEach(worker => worker.kill());
            this.log('INFO', 'Teste de carga concluído');
            
        } else {
            // Código do worker
            await this.runWorkerLoad(testScenarios);
        }
    }

    async runWorkerLoad(testScenarios) {
        const workerId = process.env.WORKER_ID;
        const usersPerWorker = parseInt(process.env.USERS_PER_WORKER);
        const testEndTime = Date.now() + (CONFIG.load_test.test_duration_seconds * 1000);
        
        console.log(`Worker ${workerId} iniciado com ${usersPerWorker} usuários virtuais`);
        
        // Simular múltiplos usuários
        const userPromises = [];
        for (let userId = 0; userId < usersPerWorker; userId++) {
            userPromises.push(this.simulateUser(userId, testScenarios, testEndTime));
        }
        
        await Promise.all(userPromises);
        process.exit(0);
    }

    async simulateUser(userId, testScenarios, testEndTime) {
        const clientId = `load-test-user-${process.env.WORKER_ID}-${userId}`;
        
        while (Date.now() < testEndTime) {
            // Selecionar cenário baseado no peso
            const scenario = this.selectWeightedScenario(testScenarios);
            
            const startTime = Date.now();
            let requestName = scenario.name;
            let status = 0;
            let error = null;
            
            try {
                const result = await scenario.execute(clientId);
                status = result.status;
                requestName = result.name || scenario.name;
                
            } catch (err) {
                error = err.message;
            }
            
            const responseTime = Date.now() - startTime;
            
            // Enviar resultado para master process
            process.send({
                type: 'request_result',
                data: {
                    name: requestName,
                    status: status,
                    responseTime: responseTime,
                    error: error
                }
            });
            
            // Think time (tempo entre requisições)
            if (CONFIG.load_test.think_time_ms > 0) {
                await new Promise(resolve => setTimeout(resolve, CONFIG.load_test.think_time_ms));
            }
        }
    }

    selectWeightedScenario(scenarios) {
        const totalWeight = scenarios.reduce((sum, s) => sum + s.weight, 0);
        const random = Math.random() * totalWeight;
        
        let currentWeight = 0;
        for (const scenario of scenarios) {
            currentWeight += scenario.weight;
            if (random <= currentWeight) {
                return scenario;
            }
        }
        
        return scenarios[0]; // Fallback
    }

    async testLicenseStatusLoad(clientId) {
        const response = await this.httpClient.get('/api/license/status', {
            headers: { 'X-Client-Id': clientId || `load-${Date.now()}` }
        });
        
        return {
            name: 'License Status Check',
            status: response.status
        };
    }

    async testLicenseActivationLoad(clientId) {
        // Usar licença de teste
        const testLicenseKey = 'SPR-TEST-1234-5678-ABCD';
        const uniqueClientId = clientId || `load-activation-${Date.now()}`;
        
        const response = await this.httpClient.post('/api/license/activate', {
            key: testLicenseKey,
            clientId: uniqueClientId
        });
        
        return {
            name: 'License Activation',
            status: response.status
        };
    }

    async testHealthCheckLoad(clientId) {
        const response = await this.httpClient.get('/api/health');
        
        return {
            name: 'Health Check',
            status: response.status
        };
    }

    recordRequest(name, status, responseTime, testType, error = null) {
        const request = {
            timestamp: Date.now(),
            name: name,
            status: status,
            response_time: responseTime,
            test_type: testType,
            error: error
        };
        
        this.results.requests.push(request);
        
        if (error) {
            this.results.errors.push(request);
        }
    }

    async calculateMetrics() {
        this.results.end_time = Date.now();
        const totalDuration = (this.results.end_time - this.results.start_time) / 1000; // em segundos
        
        const requests = this.results.requests;
        const successfulRequests = requests.filter(r => r.status >= 200 && r.status < 400);
        
        this.results.metrics = {
            total_requests: requests.length,
            successful_requests: successfulRequests.length,
            failed_requests: requests.length - successfulRequests.length,
            success_rate: (successfulRequests.length / requests.length * 100).toFixed(2),
            error_rate: ((requests.length - successfulRequests.length) / requests.length * 100).toFixed(2),
            requests_per_second: (requests.length / totalDuration).toFixed(2)
        };
        
        if (requests.length > 0) {
            const responseTimes = requests.map(r => r.response_time).sort((a, b) => a - b);
            
            this.results.metrics.min_response_time = responseTimes[0];
            this.results.metrics.max_response_time = responseTimes[responseTimes.length - 1];
            this.results.metrics.avg_response_time = (responseTimes.reduce((a, b) => a + b, 0) / responseTimes.length).toFixed(2);
            
            // Percentil 95
            const p95Index = Math.floor(responseTimes.length * 0.95);
            this.results.metrics.p95_response_time = responseTimes[p95Index];
        }
        
        this.log('SUCCESS', 'Métricas calculadas', this.results.metrics);
    }

    evaluateResults() {
        this.log('INFO', '📊 Avaliando resultados contra thresholds');
        
        const metrics = this.results.metrics;
        const thresholds = CONFIG.performance_thresholds;
        
        let passed = true;
        const failures = [];
        
        // Verificar taxa de sucesso
        if (parseFloat(metrics.success_rate) < thresholds.min_success_rate) {
            passed = false;
            failures.push(`Taxa de sucesso (${metrics.success_rate}%) abaixo do mínimo (${thresholds.min_success_rate}%)`);
        }
        
        // Verificar taxa de erro
        if (parseFloat(metrics.error_rate) > thresholds.max_error_rate) {
            passed = false;
            failures.push(`Taxa de erro (${metrics.error_rate}%) acima do máximo (${thresholds.max_error_rate}%)`);
        }
        
        // Verificar tempo de resposta P95
        if (metrics.p95_response_time > thresholds.max_95th_percentile_ms) {
            passed = false;
            failures.push(`P95 response time (${metrics.p95_response_time}ms) acima do máximo (${thresholds.max_95th_percentile_ms}ms)`);
        }
        
        if (passed) {
            this.log('SUCCESS', '🎉 Todos os thresholds de performance atendidos!');
            process.exitCode = 0;
        } else {
            this.log('ERROR', '❌ Thresholds de performance não atendidos:');
            failures.forEach(failure => this.log('ERROR', `  - ${failure}`));
            process.exitCode = 1;
        }
    }

    async generateReport() {
        const reportPath = path.join(CONFIG.reports.outputDir, `performance_report_${Date.now()}.json`);
        
        const report = {
            summary: {
                timestamp: new Date().toISOString(),
                test_duration_seconds: (this.results.end_time - this.results.start_time) / 1000,
                configuration: CONFIG,
                metrics: this.results.metrics
            },
            results: {
                requests: this.results.requests,
                errors: this.results.errors
            },
            analysis: {
                performance_grade: this.calculatePerformanceGrade(),
                bottlenecks: this.identifyBottlenecks(),
                recommendations: this.generateRecommendations()
            }
        };
        
        try {
            await fs.mkdir(CONFIG.reports.outputDir, { recursive: true });
            await fs.writeFile(reportPath, JSON.stringify(report, null, 2));
            this.log('SUCCESS', `Relatório salvo em: ${reportPath}`);
        } catch (error) {
            this.log('ERROR', 'Erro ao salvar relatório', error.message);
        }
        
        // Exibir sumário na console
        this.displaySummary();
    }

    calculatePerformanceGrade() {
        const metrics = this.results.metrics;
        let score = 100;
        
        // Penalizar por alta taxa de erro
        score -= parseFloat(metrics.error_rate) * 10;
        
        // Penalizar por tempo de resposta alto
        if (metrics.p95_response_time > 1000) {
            score -= Math.min(30, (metrics.p95_response_time - 1000) / 100);
        }
        
        // Penalizar por baixa taxa de sucesso
        if (parseFloat(metrics.success_rate) < 95) {
            score -= (95 - parseFloat(metrics.success_rate)) * 2;
        }
        
        score = Math.max(0, Math.round(score));
        
        if (score >= 90) return 'A';
        if (score >= 80) return 'B';
        if (score >= 70) return 'C';
        if (score >= 60) return 'D';
        return 'F';
    }

    identifyBottlenecks() {
        const bottlenecks = [];
        const metrics = this.results.metrics;
        
        if (metrics.p95_response_time > 2000) {
            bottlenecks.push('High P95 response time indicates server processing bottleneck');
        }
        
        if (parseFloat(metrics.error_rate) > 1) {
            bottlenecks.push('Elevated error rate suggests capacity or stability issues');
        }
        
        if (parseFloat(metrics.requests_per_second) < 10) {
            bottlenecks.push('Low throughput may indicate resource constraints');
        }
        
        return bottlenecks;
    }

    generateRecommendations() {
        const recommendations = [];
        const metrics = this.results.metrics;
        
        if (metrics.p95_response_time > 1000) {
            recommendations.push('Consider implementing caching to reduce response times');
            recommendations.push('Review database query performance');
        }
        
        if (parseFloat(metrics.error_rate) > 0.1) {
            recommendations.push('Investigate error logs to identify failure patterns');
            recommendations.push('Implement circuit breakers for external dependencies');
        }
        
        if (this.results.errors.length > 0) {
            const errorTypes = this.results.errors.reduce((acc, error) => {
                const type = error.error || 'Unknown';
                acc[type] = (acc[type] || 0) + 1;
                return acc;
            }, {});
            
            recommendations.push(`Most common errors: ${Object.entries(errorTypes).map(([type, count]) => `${type} (${count})`).join(', ')}`);
        }
        
        recommendations.push('Monitor system resources (CPU, memory, disk I/O) during load');
        recommendations.push('Consider horizontal scaling if vertical scaling is insufficient');
        
        return recommendations;
    }

    displaySummary() {
        const metrics = this.results.metrics;
        
        console.log('\n' + '='.repeat(70));
        console.log('📊 PERFORMANCE TEST SUMMARY');
        console.log('='.repeat(70));
        console.log(`🕐 Total Duration: ${((this.results.end_time - this.results.start_time) / 1000).toFixed(2)}s`);
        console.log(`📈 Total Requests: ${metrics.total_requests}`);
        console.log(`✅ Successful: ${metrics.successful_requests} (${metrics.success_rate}%)`);
        console.log(`❌ Failed: ${metrics.failed_requests} (${metrics.error_rate}%)`);
        console.log(`⚡ Throughput: ${metrics.requests_per_second} req/s`);
        console.log('');
        console.log('📊 RESPONSE TIMES:');
        console.log(`   Min: ${metrics.min_response_time}ms`);
        console.log(`   Avg: ${metrics.avg_response_time}ms`);
        console.log(`   Max: ${metrics.max_response_time}ms`);
        console.log(`   P95: ${metrics.p95_response_time}ms`);
        console.log('');
        console.log(`🎯 Performance Grade: ${this.calculatePerformanceGrade()}`);
        console.log('='.repeat(70));
    }
}

// Executar testes de performance
async function runPerformanceTests() {
    if (cluster.isMaster) {
        const tester = new PerformanceTester();
        await tester.runPerformanceTests();
    }
}

// Executar se chamado diretamente
if (require.main === module) {
    runPerformanceTests().catch(error => {
        console.error('❌ Performance tests failed:', error);
        process.exit(1);
    });
}

module.exports = { runPerformanceTests, PerformanceTester };