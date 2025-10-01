#!/usr/bin/env node

/**
 * Health Check Script
 * Verifies all backend services are running correctly
 */

const http = require('http');

// ANSI color codes
const colors = {
    reset: '\x1b[0m',
    green: '\x1b[32m',
    red: '\x1b[31m',
    yellow: '\x1b[33m',
    blue: '\x1b[34m',
    cyan: '\x1b[36m'
};

// Service endpoints to check
const services = [
    {
        name: 'OAuth Proxy',
        host: 'localhost',
        port: process.env.OAUTH_PORT || 3000,
        path: '/health',
        timeout: 5000
    },
    {
        name: 'Auth Service',
        host: 'localhost',
        port: process.env.AUTH_PORT || 3001,
        path: '/health',
        timeout: 5000
    },
    {
        name: 'Nginx Proxy',
        host: 'localhost',
        port: 80,
        path: '/health',
        timeout: 5000,
        optional: true
    }
];

/**
 * Check a single service
 */
function checkService(service) {
    return new Promise((resolve) => {
        const options = {
            hostname: service.host,
            port: service.port,
            path: service.path,
            method: 'GET',
            timeout: service.timeout
        };

        const startTime = Date.now();
        const req = http.request(options, (res) => {
            let data = '';

            res.on('data', (chunk) => {
                data += chunk;
            });

            res.on('end', () => {
                const responseTime = Date.now() - startTime;
                const isHealthy = res.statusCode === 200;

                resolve({
                    service: service.name,
                    healthy: isHealthy,
                    statusCode: res.statusCode,
                    responseTime: responseTime,
                    data: data,
                    optional: service.optional || false
                });
            });
        });

        req.on('timeout', () => {
            req.destroy();
            resolve({
                service: service.name,
                healthy: false,
                error: 'Timeout',
                optional: service.optional || false
            });
        });

        req.on('error', (error) => {
            resolve({
                service: service.name,
                healthy: false,
                error: error.message,
                optional: service.optional || false
            });
        });

        req.end();
    });
}

/**
 * Format check result
 */
function formatResult(result) {
    const status = result.healthy
        ? `${colors.green}✅ HEALTHY${colors.reset}`
        : result.optional
        ? `${colors.yellow}⚠️  OPTIONAL${colors.reset}`
        : `${colors.red}❌ UNHEALTHY${colors.reset}`;

    let output = `${status} ${colors.cyan}${result.service}${colors.reset}`;

    if (result.healthy) {
        output += ` (${result.responseTime}ms)`;
        if (result.data) {
            try {
                const json = JSON.parse(result.data);
                if (json.users !== undefined) {
                    output += ` - ${json.users} users`;
                }
            } catch (e) {
                // Not JSON, that's fine
            }
        }
    } else {
        output += ` - ${colors.red}${result.error || 'HTTP ' + result.statusCode}${colors.reset}`;
        if (result.optional) {
            output += ` ${colors.yellow}(optional service)${colors.reset}`;
        }
    }

    return output;
}

/**
 * Main health check
 */
async function runHealthCheck() {
    console.log(`${colors.blue}🏥 Nintendo Emulator Backend - Health Check${colors.reset}`);
    console.log('='.repeat(50));
    console.log('');

    const results = await Promise.all(services.map(checkService));

    results.forEach(result => {
        console.log(formatResult(result));
    });

    console.log('');
    console.log('='.repeat(50));

    // Calculate overall health
    const criticalServices = results.filter(r => !r.optional);
    const healthyServices = criticalServices.filter(r => r.healthy);
    const unhealthyServices = criticalServices.filter(r => !r.healthy);

    const allHealthy = unhealthyServices.length === 0;

    if (allHealthy) {
        console.log(`${colors.green}✅ All critical services are healthy${colors.reset}`);
        console.log(`${colors.green}${healthyServices.length}/${criticalServices.length} services operational${colors.reset}`);
        process.exit(0);
    } else {
        console.log(`${colors.red}❌ Some services are unhealthy${colors.reset}`);
        console.log(`${colors.red}${healthyServices.length}/${criticalServices.length} services operational${colors.reset}`);
        console.log('');
        console.log('Unhealthy services:');
        unhealthyServices.forEach(result => {
            console.log(`  - ${result.service}: ${result.error || 'HTTP ' + result.statusCode}`);
        });
        process.exit(1);
    }
}

// Run health check
if (require.main === module) {
    runHealthCheck().catch(error => {
        console.error(`${colors.red}Error running health check:${colors.reset}`, error);
        process.exit(1);
    });
}

module.exports = { checkService, runHealthCheck };