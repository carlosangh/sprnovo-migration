#!/usr/bin/env node

/**
 * SPR License System Test Script
 * Tests the complete license system functionality
 * 
 * Usage: node test-license-system.js [server-url]
 * Example: node test-license-system.js http://localhost:3002
 */

const axios = require('axios');

const BASE_URL = process.argv[2] || 'http://localhost:3002';
const TEST_CLIENT_ID = 'test-client-' + Math.random().toString(36).substr(2, 9);
const TEST_LICENSE_KEY = 'SPR-TEST-1234-5678-ABCD';

console.log('🧪 SPR License System Test Suite');
console.log('================================');
console.log(`🌐 Server: ${BASE_URL}`);
console.log(`🔑 Client ID: ${TEST_CLIENT_ID}`);
console.log('');

let testResults = {
    passed: 0,
    failed: 0,
    tests: []
};

function logTest(name, success, details = '') {
    const status = success ? '✅ PASS' : '❌ FAIL';
    console.log(`${status} ${name}`);
    if (details) console.log(`   ${details}`);
    
    testResults.tests.push({ name, success, details });
    if (success) testResults.passed++;
    else testResults.failed++;
}

async function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

async function testHealthCheck() {
    try {
        const response = await axios.get(`${BASE_URL}/api/health`);
        logTest('Health Check', response.status === 200, `Status: ${response.data.status}`);
        return true;
    } catch (error) {
        logTest('Health Check', false, `Error: ${error.message}`);
        return false;
    }
}

async function testLicenseGateBlocking() {
    try {
        const response = await axios.post(`${BASE_URL}/api/generate-message`, {
            prompt: 'test message'
        }, { timeout: 5000 });
        
        logTest('License Gate Blocking', false, 'Should have been blocked but was allowed');
        return false;
    } catch (error) {
        if (error.response && error.response.status === 403) {
            const errorData = error.response.data;
            const hasLicenseError = errorData.error && errorData.error.includes('license');
            logTest('License Gate Blocking', hasLicenseError, 'Correctly blocked without license');
            return true;
        }
        logTest('License Gate Blocking', false, `Unexpected error: ${error.message}`);
        return false;
    }
}

async function testLicenseActivation() {
    try {
        const response = await axios.post(`${BASE_URL}/api/license/activate`, {
            key: TEST_LICENSE_KEY,
            clientId: TEST_CLIENT_ID
        });
        
        const success = response.status === 200 && response.data.success;
        logTest('License Activation', success, success ? 'License activated successfully' : 'Activation failed');
        return success;
    } catch (error) {
        logTest('License Activation', false, `Error: ${error.response?.data?.error || error.message}`);
        return false;
    }
}

async function testLicenseStatus() {
    try {
        const response = await axios.get(`${BASE_URL}/api/license/status`, {
            params: { clientId: TEST_CLIENT_ID }
        });
        
        const data = response.data;
        const isActive = data.active === true;
        const hasClientId = data.clientId === TEST_CLIENT_ID;
        const hasPlan = data.plan !== null;
        
        const success = isActive && hasClientId && hasPlan;
        logTest('License Status Check', success, 
            `Active: ${data.active}, Plan: ${data.plan}, Cache Hit Rate: ${data.cacheStats?.hitRate || 'N/A'}`);
        return success;
    } catch (error) {
        logTest('License Status Check', false, `Error: ${error.response?.data?.error || error.message}`);
        return false;
    }
}

async function testMockClientBlocking() {
    try {
        const response = await axios.post(`${BASE_URL}/api/generate-message`, {
            prompt: 'test message'
        }, { 
            headers: {
                'User-Agent': 'Mock Client Test',
                'x-client-id': TEST_CLIENT_ID
            },
            timeout: 5000 
        });
        
        logTest('Mock Client Blocking', false, 'Mock client should have been blocked');
        return false;
    } catch (error) {
        if (error.response && error.response.status === 403) {
            const errorData = error.response.data;
            const isMockBlocked = errorData.error && errorData.error.includes('Mock clients not allowed');
            logTest('Mock Client Blocking', isMockBlocked, 'Mock client correctly blocked in production');
            return isMockBlocked;
        }
        logTest('Mock Client Blocking', false, `Unexpected error: ${error.message}`);
        return false;
    }
}

async function testAuthLoginWithLicense() {
    try {
        const response = await axios.post(`${BASE_URL}/api/auth/login`, {
            username: 'admin',
            password: 'admin123',  // Default test password
            clientId: TEST_CLIENT_ID
        });
        
        const data = response.data;
        const hasToken = !!data.token;
        const hasLicense = data.license && data.license.active;
        
        const success = hasToken && hasLicense;
        logTest('Auth Login with License', success, 
            `Token: ${hasToken ? 'Present' : 'Missing'}, License Active: ${hasLicense}`);
        
        if (success) {
            // Store token for further tests
            global.authToken = data.token;
        }
        
        return success;
    } catch (error) {
        logTest('Auth Login with License', false, `Error: ${error.response?.data?.error || error.message}`);
        return false;
    }
}

async function testAuthMeWithLicense() {
    if (!global.authToken) {
        logTest('Auth Me Endpoint', false, 'No auth token available');
        return false;
    }
    
    try {
        const response = await axios.get(`${BASE_URL}/api/auth/me`, {
            headers: {
                'Authorization': `Bearer ${global.authToken}`
            }
        });
        
        const data = response.data;
        const hasUser = !!data.user;
        const hasLicense = data.license && data.license.active;
        
        const success = hasUser && hasLicense;
        logTest('Auth Me Endpoint', success, 
            `User: ${data.user?.username || 'Missing'}, License: ${hasLicense ? 'Active' : 'Inactive'}`);
        return success;
    } catch (error) {
        logTest('Auth Me Endpoint', false, `Error: ${error.response?.data?.error || error.message}`);
        return false;
    }
}

async function testLicensedEndpoint() {
    if (!global.authToken) {
        logTest('Licensed Endpoint Access', false, 'No auth token available');
        return false;
    }
    
    try {
        const response = await axios.post(`${BASE_URL}/api/generate-message`, {
            prompt: 'test message with license'
        }, {
            headers: {
                'Authorization': `Bearer ${global.authToken}`,
                'x-client-id': TEST_CLIENT_ID
            }
        });
        
        const success = response.status === 200 && response.data.success;
        logTest('Licensed Endpoint Access', success, 
            success ? 'Successfully accessed with valid license' : 'Access failed despite valid license');
        return success;
    } catch (error) {
        logTest('Licensed Endpoint Access', false, `Error: ${error.response?.data?.error || error.message}`);
        return false;
    }
}

async function testLicenseDeactivation() {
    try {
        const response = await axios.post(`${BASE_URL}/api/license/deactivate`, {
            clientId: TEST_CLIENT_ID
        });
        
        const success = response.status === 200 && response.data.success;
        logTest('License Deactivation', success, 
            success ? `Deactivated (${response.data.rowsAffected} rows affected)` : 'Deactivation failed');
        return success;
    } catch (error) {
        logTest('License Deactivation', false, `Error: ${error.response?.data?.error || error.message}`);
        return false;
    }
}

async function testDeactivatedLicenseBlocking() {
    await sleep(1000); // Wait for cache to expire or clear
    
    try {
        const response = await axios.get(`${BASE_URL}/api/license/status`, {
            params: { clientId: TEST_CLIENT_ID }
        });
        
        const isInactive = response.data.active === false;
        logTest('Deactivated License Blocking', isInactive, 
            `License status: ${response.data.active ? 'Active (should be inactive)' : 'Inactive (correct)'}`);
        return isInactive;
    } catch (error) {
        logTest('Deactivated License Blocking', false, `Error: ${error.response?.data?.error || error.message}`);
        return false;
    }
}

async function testSystemStatus() {
    try {
        const response = await axios.get(`${BASE_URL}/api/status`);
        const data = response.data;
        
        const hasServices = !!data.services;
        const hasVersion = !!data.version;
        const isOnline = data.status === 'online';
        
        const success = hasServices && hasVersion && isOnline;
        logTest('System Status', success, 
            `Status: ${data.status}, Version: ${data.version}, Services: ${Object.keys(data.services || {}).length}`);
        return success;
    } catch (error) {
        logTest('System Status', false, `Error: ${error.message}`);
        return false;
    }
}

async function runAllTests() {
    console.log('🚀 Starting License System Tests...\n');
    
    const tests = [
        { name: 'Health Check', fn: testHealthCheck },
        { name: 'System Status', fn: testSystemStatus },
        { name: 'License Gate Blocking (No License)', fn: testLicenseGateBlocking },
        { name: 'License Activation', fn: testLicenseActivation },
        { name: 'License Status After Activation', fn: testLicenseStatus },
        { name: 'Mock Client Blocking', fn: testMockClientBlocking },
        { name: 'Auth Login with License Integration', fn: testAuthLoginWithLicense },
        { name: 'Auth Me with License Data', fn: testAuthMeWithLicense },
        { name: 'Licensed Endpoint Access', fn: testLicensedEndpoint },
        { name: 'License Deactivation', fn: testLicenseDeactivation },
        { name: 'Deactivated License Blocking', fn: testDeactivatedLicenseBlocking }
    ];
    
    for (const test of tests) {
        try {
            await test.fn();
        } catch (error) {
            logTest(test.name, false, `Unexpected error: ${error.message}`);
        }
        await sleep(500); // Small delay between tests
    }
    
    console.log('\n📊 TEST RESULTS');
    console.log('================');
    console.log(`✅ Passed: ${testResults.passed}`);
    console.log(`❌ Failed: ${testResults.failed}`);
    console.log(`📋 Total: ${testResults.tests.length}`);
    
    const successRate = ((testResults.passed / testResults.tests.length) * 100).toFixed(1);
    console.log(`🎯 Success Rate: ${successRate}%`);
    
    if (testResults.failed === 0) {
        console.log('\n🎉 ALL TESTS PASSED! License system is working correctly.');
    } else {
        console.log('\n⚠️ Some tests failed. Check the implementation and server configuration.');
        
        console.log('\n❌ FAILED TESTS:');
        testResults.tests
            .filter(test => !test.success)
            .forEach(test => {
                console.log(`   • ${test.name}: ${test.details}`);
            });
    }
    
    console.log('\n🔧 NEXT STEPS:');
    if (testResults.failed === 0) {
        console.log('   ✅ Deploy to production server');
        console.log('   ✅ Configure production environment variables');
        console.log('   ✅ Set up monitoring and alerts');
    } else {
        console.log('   🔍 Review failed tests above');
        console.log('   🛠️ Fix configuration issues');
        console.log('   🔄 Run tests again');
    }
    
    process.exit(testResults.failed > 0 ? 1 : 0);
}

// Handle uncaught errors
process.on('uncaughtException', (error) => {
    console.error('\n❌ FATAL ERROR:', error.message);
    process.exit(1);
});

process.on('unhandledRejection', (error) => {
    console.error('\n❌ UNHANDLED REJECTION:', error.message);
    process.exit(1);
});

// Run tests
runAllTests().catch(error => {
    console.error('\n❌ TEST SUITE ERROR:', error.message);
    process.exit(1);
});