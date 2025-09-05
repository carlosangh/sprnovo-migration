#!/usr/bin/env node

/**
 * Script de verificação simples do status SSH no React
 * Usa apenas requisições HTTP para verificar se os arquivos estão sendo servidos
 */

const http = require('http');
const fs = require('fs');
const path = require('path');

function makeRequest(url) {
  return new Promise((resolve, reject) => {
    const req = http.get(url, (res) => {
      let data = '';
      
      res.on('data', (chunk) => {
        data += chunk;
      });
      
      res.on('end', () => {
        resolve({
          statusCode: res.statusCode,
          headers: res.headers,
          data: data
        });
      });
    });
    
    req.on('error', reject);
    req.setTimeout(10000, () => {
      req.destroy();
      reject(new Error('Timeout'));
    });
  });
}

async function checkSSHStatus() {
  console.log('🔍 Verificando status do erro SSH no React...\n');
  
  const results = {
    timestamp: new Date().toISOString(),
    serverRunning: false,
    reactPageServed: false,
    jsFilesAccessible: false,
    sshCodeInFiles: false,
    errors: []
  };

  try {
    // 1. Verificar se o servidor está rodando
    console.log('1️⃣ Testando servidor...');
    const healthCheck = await makeRequest('http://localhost:3002/health');
    results.serverRunning = healthCheck.statusCode === 200;
    console.log(`   Servidor: ${results.serverRunning ? '✅ Rodando' : '❌ Não acessível'}`);
    
    if (results.serverRunning) {
      const healthData = JSON.parse(healthCheck.data);
      console.log(`   Uptime: ${Math.floor(healthData.uptime)}s`);
      console.log(`   Versão: ${healthData.version}`);
    }

    // 2. Verificar se a página React é servida
    console.log('\n2️⃣ Testando página React...');
    const reactPage = await makeRequest('http://localhost:3002/');
    results.reactPageServed = reactPage.statusCode === 200 && reactPage.data.includes('SPR 1.1 - Sistema de Precificação Rural');
    console.log(`   Página React: ${results.reactPageServed ? '✅ Servida corretamente' : '❌ Problema no carregamento'}`);
    
    if (results.reactPageServed) {
      console.log(`   Content-Type: ${reactPage.headers['content-type']}`);
      console.log(`   Tamanho: ${reactPage.data.length} bytes`);
    }

    // 3. Verificar se arquivos JS estão acessíveis
    console.log('\n3️⃣ Testando arquivos JavaScript...');
    const jsFile = await makeRequest('http://localhost:3002/static/js/main.538a247b.js');
    results.jsFilesAccessible = jsFile.statusCode === 200;
    console.log(`   Arquivo JS principal: ${results.jsFilesAccessible ? '✅ Acessível' : '❌ Não encontrado'}`);
    
    if (results.jsFilesAccessible) {
      console.log(`   Content-Type: ${jsFile.headers['content-type']}`);
      console.log(`   Tamanho: ${Math.round(jsFile.data.length / 1024)}KB`);
      
      // 4. Procurar por código SSH no arquivo JS
      console.log('\n4️⃣ Analisando código SSH...');
      const jsContent = jsFile.data.toLowerCase();
      
      const sshTerms = [
        'ssh error',
        'authentication.*failed',
        'all configured authentication methods failed',
        'ssh2',
        'node-ssh',
        'webssh',
        'xterm.js'
      ];
      
      let foundTerms = [];
      sshTerms.forEach(term => {
        if (jsContent.includes(term)) {
          foundTerms.push(term);
        }
      });
      
      results.sshCodeInFiles = foundTerms.length > 0;
      
      if (results.sshCodeInFiles) {
        console.log(`   🚨 Código SSH encontrado: ${foundTerms.join(', ')}`);
      } else {
        console.log('   ✅ Nenhum código SSH detectado nos arquivos principais');
      }
    }

    // 5. Verificar chunks adicionais que podem conter SSH
    console.log('\n5️⃣ Verificando chunks adicionais...');
    try {
      const chunk703 = await makeRequest('http://localhost:3002/static/js/703.c97da9c1.chunk.js');
      if (chunk703.statusCode === 200) {
        const chunkContent = chunk703.data.toLowerCase();
        const hasSSHInChunk = chunkContent.includes('ssh') || chunkContent.includes('xterm') || chunkContent.includes('terminal');
        
        console.log(`   Chunk 703: ${hasSSHInChunk ? '⚠️  Contém código SSH/Terminal' : '✅ Sem código SSH'}`);
        
        if (hasSSHInChunk) {
          results.sshCodeInFiles = true;
          console.log('   🔍 Este chunk pode ser responsável pelo terminal web integrado');
        }
      }
    } catch (error) {
      console.log(`   Chunk 703: ⚠️  Não verificável (${error.message})`);
    }

  } catch (error) {
    console.log(`❌ Erro durante verificação: ${error.message}`);
    results.errors.push(error.message);
  }

  // Resumo final
  console.log('\n📊 RESUMO DA VERIFICAÇÃO:');
  console.log('========================');
  console.log(`🌐 Servidor funcionando: ${results.serverRunning ? '✅' : '❌'}`);
  console.log(`📄 Página React servida: ${results.reactPageServed ? '✅' : '❌'}`);
  console.log(`📜 Arquivos JS acessíveis: ${results.jsFilesAccessible ? '✅' : '❌'}`);
  console.log(`🔍 Código SSH detectado: ${results.sshCodeInFiles ? '⚠️  SIM' : '✅ NÃO'}`);

  const overallSuccess = results.serverRunning && results.reactPageServed && results.jsFilesAccessible;
  console.log(`\n🎯 STATUS GERAL: ${overallSuccess ? '✅ SISTEMA FUNCIONANDO' : '❌ PROBLEMA DETECTADO'}`);

  if (results.sshCodeInFiles) {
    console.log('\n💡 RECOMENDAÇÃO:');
    console.log('   O código SSH detectado pode ser um terminal web integrado.');
    console.log('   Se causar problemas, considere:');
    console.log('   1. Desabilitar funcionalidade de terminal');
    console.log('   2. Configurar SSH adequadamente');
    console.log('   3. Remover dependência de terminal se não necessária');
  }

  // Salvar resultados
  const resultsFile = path.join(__dirname, 'ssh-check-results.json');
  fs.writeFileSync(resultsFile, JSON.stringify(results, null, 2));
  console.log(`\n💾 Resultados salvos em: ${resultsFile}`);

  return overallSuccess && !results.sshCodeInFiles;
}

// Executar se chamado diretamente
if (require.main === module) {
  checkSSHStatus()
    .then(success => {
      process.exit(success ? 0 : 1);
    })
    .catch(error => {
      console.error('❌ Erro fatal:', error);
      process.exit(1);
    });
}

module.exports = { checkSSHStatus };