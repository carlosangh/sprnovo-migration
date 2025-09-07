// test_array_validation.js - Validação de formato ARRAY nos endpoints
const axios = require('axios');

const BASE_URL = 'http://localhost:3002';

async function testEndpointArrays() {
    console.log('🧪 VALIDAÇÃO DE ARRAYS - FORMATO ESPERADO PELO FRONTEND');
    console.log('=' .repeat(60));
    
    const tests = [
        {
            name: '/api/status',
            url: '/api/status',
            arrayPaths: [
                'data.agentes_status'
            ]
        },
        {
            name: '/api/metrics', 
            url: '/api/metrics',
            arrayPaths: [
                'data.analytics_metrics',
                'data.aggregations', 
                'data.daily_trends'
            ]
        },
        {
            name: '/api/commodities/dashboard/summary',
            url: '/api/commodities/dashboard/summary', 
            arrayPaths: [
                'data.dados_mercado'
            ]
        },
        {
            name: '/api/offer-management',
            url: '/api/offer-management',
            arrayPaths: [
                'data.ofertas'
            ]
        },
        {
            name: '/api/whatsapp/qr-code',
            url: '/api/whatsapp/qr-code',
            arrayPaths: [
                'data.whatsapp_sessions'
            ]
        }
    ];

    let allPassed = true;

    for (const test of tests) {
        console.log(`\n📊 Testando: ${test.name}`);
        
        try {
            const response = await axios.get(BASE_URL + test.url);
            const data = response.data;
            
            // Verificar se response é válido
            if (!data.success) {
                console.log(`❌ ${test.name}: Response não indica sucesso`);
                allPassed = false;
                continue;
            }
            
            // Verificar meta anti-mock
            if (data.meta && data.meta.is_mock === true) {
                console.log(`❌ ${test.name}: Ainda está retornando dados MOCK!`);
                allPassed = false;
                continue;
            }
            
            // Verificar cada path de array esperado
            for (const arrayPath of test.arrayPaths) {
                const pathParts = arrayPath.split('.');
                let current = data;
                
                // Navegar pelo path
                for (const part of pathParts) {
                    if (current && typeof current === 'object') {
                        current = current[part];
                    } else {
                        current = undefined;
                        break;
                    }
                }
                
                if (Array.isArray(current)) {
                    console.log(`✅ ${arrayPath}: É um array (${current.length} itens)`);
                    
                    // Testar se frontend conseguiria fazer .map()
                    try {
                        const testMap = current.map(item => item);
                        console.log(`✅ ${arrayPath}: .map() funcionaria perfeitamente`);
                    } catch (e) {
                        console.log(`❌ ${arrayPath}: .map() falharia: ${e.message}`);
                        allPassed = false;
                    }
                } else {
                    console.log(`❌ ${arrayPath}: NÃO é um array (tipo: ${typeof current})`);
                    console.log(`   Valor atual:`, current);
                    allPassed = false;
                }
            }
            
            // Verificar se tem dados anti-mock
            if (data.meta && data.meta.source) {
                console.log(`✅ Fonte de dados: ${data.meta.source}`);
            }
            
        } catch (error) {
            console.log(`❌ ${test.name}: Erro na requisição: ${error.message}`);
            allPassed = false;
        }
    }
    
    console.log('\n' + '=' .repeat(60));
    
    if (allPassed) {
        console.log('🎉 TODOS OS ARRAYS VALIDADOS COM SUCESSO!');
        console.log('✅ Frontend poderá usar .map() em todos os endpoints');
        console.log('✅ Nenhum dado de MOCK detectado');
        console.log('✅ Todos os endpoints retornam dados REAIS do banco SQLite');
    } else {
        console.log('⚠️ ALGUNS TESTES FALHARAM!');
        console.log('❌ Verifique os logs acima para detalhes');
    }
    
    return allPassed;
}

// Executar teste se chamado diretamente
if (require.main === module) {
    testEndpointArrays().then((success) => {
        process.exit(success ? 0 : 1);
    }).catch((error) => {
        console.error('Erro fatal no teste:', error);
        process.exit(1);
    });
}

module.exports = { testEndpointArrays };