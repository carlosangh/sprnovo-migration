#!/usr/bin/env node

/**
 * Script de teste automatizado para detectar erro SSH no React
 * Usa puppeteer para simular navegador e capturar erros JavaScript
 */

const puppeteer = require('puppeteer');
const fs = require('fs');
const path = require('path');

async function testReactSSHError() {
  console.log('🔍 Iniciando teste de erro SSH no React...\n');
  
  let browser;
  let testResults = {
    timestamp: new Date().toISOString(),
    success: false,
    errors: [],
    sshErrors: [],
    consoleMessages: [],
    pageLoaded: false,
    reactMounted: false
  };

  try {
    // Configurar puppeteer
    browser = await puppeteer.launch({
      headless: true,
      args: [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage',
        '--disable-accelerated-2d-canvas',
        '--no-first-run',
        '--no-zygote',
        '--disable-gpu'
      ]
    });

    const page = await browser.newPage();
    
    // Capturar erros e logs
    page.on('console', msg => {
      const text = msg.text();
      testResults.consoleMessages.push({
        type: msg.type(),
        text: text,
        timestamp: new Date().toISOString()
      });
      
      console.log(`📝 Console [${msg.type()}]: ${text}`);
      
      // Detectar erros SSH específicos
      if (text.toLowerCase().includes('ssh') && text.toLowerCase().includes('error')) {
        testResults.sshErrors.push({
          message: text,
          timestamp: new Date().toISOString()
        });
        console.log(`🚨 ERRO SSH DETECTADO: ${text}`);
      }
    });

    page.on('pageerror', error => {
      const errorMsg = error.message;
      testResults.errors.push({
        message: errorMsg,
        stack: error.stack,
        timestamp: new Date().toISOString()
      });
      
      console.log(`❌ Erro na página: ${errorMsg}`);
      
      // Verificar se é erro SSH
      if (errorMsg.toLowerCase().includes('ssh') || errorMsg.toLowerCase().includes('authentication')) {
        testResults.sshErrors.push({
          message: errorMsg,
          timestamp: new Date().toISOString()
        });
        console.log(`🚨 ERRO SSH DETECTADO: ${errorMsg}`);
      }
    });

    // Navegar para a aplicação React
    console.log('🌐 Navegando para http://localhost:3002...');
    
    const response = await page.goto('http://localhost:3002', {
      waitUntil: 'networkidle0',
      timeout: 30000
    });

    testResults.pageLoaded = response.status() === 200;
    console.log(`📄 Página carregada: ${testResults.pageLoaded ? '✅' : '❌'} (Status: ${response.status()})`);

    // Aguardar um pouco para React carregar completamente
    await page.waitForTimeout(5000);
    
    // Verificar se React montou corretamente
    try {
      const reactRoot = await page.$('#root');
      if (reactRoot) {
        const rootContent = await page.evaluate(() => {
          const root = document.getElementById('root');
          return root ? root.innerHTML.length > 0 : false;
        });
        testResults.reactMounted = rootContent;
        console.log(`⚛️  React montado: ${testResults.reactMounted ? '✅' : '❌'}`);
      }
    } catch (error) {
      console.log(`⚛️  Erro ao verificar React: ${error.message}`);
    }

    // Aguardar mais um pouco para capturar erros que podem aparecer depois
    console.log('⏳ Aguardando possíveis erros assíncronos...');
    await page.waitForTimeout(10000);

    // Verificar se houve tentativa de conexão SSH
    const sshAttempts = await page.evaluate(() => {
      // Verificar se há código que tenta fazer SSH
      const scripts = Array.from(document.scripts);
      let sshCode = false;
      
      scripts.forEach(script => {
        if (script.src) {
          // Não podemos verificar conteúdo de scripts externos por CORS
          return;
        }
        if (script.innerHTML.includes('ssh') || script.innerHTML.includes('SSH')) {
          sshCode = true;
        }
      });
      
      return sshCode;
    });
    
    console.log(`🔍 Código SSH detectado no cliente: ${sshAttempts ? '⚠️  SIM' : '✅ NÃO'}`);

  } catch (error) {
    console.log(`❌ Erro durante o teste: ${error.message}`);
    testResults.errors.push({
      message: error.message,
      stack: error.stack,
      timestamp: new Date().toISOString()
    });
  } finally {
    if (browser) {
      await browser.close();
    }
  }

  // Análise dos resultados
  console.log('\n📊 RESULTADOS DO TESTE:');
  console.log('========================');
  
  const hasSSHErrors = testResults.sshErrors.length > 0;
  const hasOtherErrors = testResults.errors.length > testResults.sshErrors.length;
  
  console.log(`🌐 Página carregada: ${testResults.pageLoaded ? '✅' : '❌'}`);
  console.log(`⚛️  React montado: ${testResults.reactMounted ? '✅' : '❌'}`);
  console.log(`🚨 Erros SSH detectados: ${hasSSHErrors ? '❌ SIM (' + testResults.sshErrors.length + ')' : '✅ NÃO'}`);
  console.log(`⚠️  Outros erros: ${hasOtherErrors ? '⚠️  SIM (' + (testResults.errors.length - testResults.sshErrors.length) + ')' : '✅ NÃO'}`);
  console.log(`📝 Total de logs: ${testResults.consoleMessages.length}`);

  if (hasSSHErrors) {
    console.log('\n🚨 DETALHES DOS ERROS SSH:');
    testResults.sshErrors.forEach((error, index) => {
      console.log(`${index + 1}. ${error.message}`);
    });
  }

  testResults.success = testResults.pageLoaded && testResults.reactMounted && !hasSSHErrors;
  
  console.log(`\n🎯 STATUS FINAL: ${testResults.success ? '✅ SUCESSO - Sem erros SSH' : '❌ PROBLEMA DETECTADO'}`);

  // Salvar resultados em arquivo
  const resultsFile = path.join(__dirname, 'test-results-ssh.json');
  fs.writeFileSync(resultsFile, JSON.stringify(testResults, null, 2));
  console.log(`💾 Resultados salvos em: ${resultsFile}`);

  return testResults.success;
}

// Executar teste se chamado diretamente
if (require.main === module) {
  testReactSSHError()
    .then(success => {
      process.exit(success ? 0 : 1);
    })
    .catch(error => {
      console.error('❌ Erro fatal no teste:', error);
      process.exit(1);
    });
}

module.exports = { testReactSSHError };