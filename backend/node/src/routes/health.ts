/**
 * Health check router with comprehensive system monitoring
 * TypeScript-PRO patterns for enterprise health monitoring
 */

import { Router } from 'express';
import type { 
  RouteHandler,
  TypedRequest,
  TypedResponse,
  ExpressRouteHandler 
} from '@/types/express';
import type {
  EndpointId,
  TimestampMs
} from '@/types/core';
import {
  ENDPOINTS
} from '@/types/core';
import { 
  createHealthCheckResponse,
  sendSuccess 
} from '@/utils/response-helpers';
import { endpointIdentification } from '@/middleware/request-enhancement';
import { asyncHandler } from '@/middleware/error-handler';

// Extended health check data with system metrics
export interface HealthCheckData {
  readonly status: 'ok' | 'degraded' | 'error';
  readonly timestamp: TimestampMs;
  readonly uptime: number;
  readonly version: string;
  readonly environment: string;
  readonly system: {
    readonly memory: {
      readonly used: number;
      readonly free: number;
      readonly total: number;
    };
    readonly cpu: {
      readonly usage: number;
      readonly loadAverage: ReadonlyArray<number>;
    };
    readonly process: {
      readonly pid: number;
      readonly nodeVersion: string;
      readonly platform: string;
    };
  };
  readonly services: ReadonlyArray<{
    readonly name: string;
    readonly status: 'healthy' | 'degraded' | 'unhealthy';
    readonly lastCheck: TimestampMs;
    readonly responseTime?: number;
  }>;
}

// System metrics collection utilities
const getMemoryUsage = () => {
  const usage = process.memoryUsage();
  return {
    used: usage.heapUsed,
    free: usage.heapTotal - usage.heapUsed,
    total: usage.heapTotal,
  };
};

const getCpuUsage = (): { usage: number; loadAverage: ReadonlyArray<number> } => {
  const cpus = require('os').cpus();
  const loadAvg = require('os').loadavg();
  
  // Simple CPU usage calculation (for demo purposes)
  let totalIdle = 0;
  let totalTick = 0;
  
  cpus.forEach((cpu: any) => {
    for (const type in cpu.times) {
      totalTick += cpu.times[type];
    }
    totalIdle += cpu.times.idle;
  });
  
  const usage = Math.round(100 - (totalIdle / totalTick * 100));
  
  return {
    usage: isNaN(usage) ? 0 : usage,
    loadAverage: loadAvg as ReadonlyArray<number>,
  };
};

const getProcessInfo = () => ({
  pid: process.pid,
  nodeVersion: process.version,
  platform: process.platform,
});

// Service health checks (placeholder for real service checks)
const checkServices = async (): Promise<ReadonlyArray<{
  readonly name: string;
  readonly status: 'healthy' | 'degraded' | 'unhealthy';
  readonly lastCheck: TimestampMs;
  readonly responseTime?: number;
}>> => {
  const timestamp = Date.now() as TimestampMs;
  
  // In a real implementation, these would be actual service health checks
  return [
    {
      name: 'database',
      status: 'healthy' as const,
      lastCheck: timestamp,
      responseTime: 15,
    },
    {
      name: 'external-apis',
      status: 'healthy' as const,
      lastCheck: timestamp,
      responseTime: 120,
    },
    {
      name: 'cache',
      status: 'healthy' as const,
      lastCheck: timestamp,
      responseTime: 5,
    },
  ];
};

// Comprehensive health check handler
const healthCheckHandler: ExpressRouteHandler = asyncHandler(async (
  req,
  res
) => {
  const timestamp = Date.now() as TimestampMs;
  const services = await checkServices();
  
  // Determine overall status based on service health
  const unhealthyServices = services.filter(s => s.status === 'unhealthy');
  const degradedServices = services.filter(s => s.status === 'degraded');
  
  let overallStatus: 'ok' | 'degraded' | 'error' = 'ok';
  
  if (unhealthyServices.length > 0) {
    overallStatus = 'error';
  } else if (degradedServices.length > 0) {
    overallStatus = 'degraded';
  }

  const responseData: HealthCheckData = {
    status: overallStatus,
    timestamp,
    uptime: Math.floor(process.uptime()),
    version: process.env['npm_package_version'] || '1.0.0',
    environment: process.env['NODE_ENV'] || 'development',
    system: {
      memory: getMemoryUsage(),
      cpu: getCpuUsage(),
      process: getProcessInfo(),
    },
    services,
  };

  // Set appropriate HTTP status based on health
  const httpStatus = overallStatus === 'ok' ? 200 : 
                    overallStatus === 'degraded' ? 200 : 503;

  sendSuccess(
    res,
    responseData,
    httpStatus,
    req.endpointId
  );
});

// Simple health check for load balancers (minimal response)
const simpleHealthHandler: ExpressRouteHandler = asyncHandler(async (
  req,
  res
) => {
  const responseData = {
    status: 'ok',
    timestamp: Date.now() as TimestampMs,
  };

  sendSuccess(
    res,
    responseData,
    200,
    req.endpointId
  );
});

// Create router
export const healthRouter = Router();

// Register health check routes
healthRouter.get(
  '/health',
  endpointIdentification(ENDPOINTS.HEALTH),
  healthCheckHandler
);

// Simple health check for load balancers
healthRouter.get(
  '/health/simple',
  endpointIdentification(ENDPOINTS.HEALTH),
  simpleHealthHandler
);

// Readiness probe for Kubernetes
healthRouter.get(
  '/ready',
  endpointIdentification(ENDPOINTS.HEALTH),
  simpleHealthHandler
);

// Liveness probe for Kubernetes
healthRouter.get(
  '/live',
  endpointIdentification(ENDPOINTS.HEALTH),
  simpleHealthHandler
);

export default healthRouter;