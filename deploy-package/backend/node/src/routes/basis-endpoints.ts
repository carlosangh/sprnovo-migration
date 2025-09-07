/**
 * Basis endpoints router with TypeScript-PRO optimization
 * Lightweight, high-performance endpoints with strict typing
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
  ServiceName,
  TimestampMs
} from '@/types/core';
import {
  ENDPOINTS,
  SERVICES
} from '@/types/core';
import { 
  sendSuccess 
} from '@/utils/response-helpers';
import { endpointIdentification } from '@/middleware/request-enhancement';
import { asyncHandler } from '@/middleware/error-handler';

// Optimized response type for basis service
export interface BasisStatusData {
  readonly ok: boolean;
  readonly svc: ServiceName;
  readonly ts: TimestampMs;
  readonly meta?: {
    readonly version: string;
    readonly environment: string;
    readonly uptime: number;
  };
}

// High-performance handler with minimal overhead
const basisIntelStatusHandler: ExpressRouteHandler = asyncHandler(async (
  req,
  res
) => {
  // Optimized response with minimal processing
  const responseData: BasisStatusData = {
    ok: true,
    svc: SERVICES.BASIS,
    ts: Date.now() as TimestampMs,
    meta: {
      version: process.env['npm_package_version'] || '1.0.0',
      environment: process.env['NODE_ENV'] || 'development',
      uptime: process.uptime(),
    },
  };

  // Direct response for maximum performance
  sendSuccess(
    res,
    responseData,
    200,
    req.endpointId,
    SERVICES.BASIS
  );
});

// Create router with minimal middleware overhead
export const basisEndpointsRouter = Router();

// Register route with endpoint identification
basisEndpointsRouter.get(
  '/intel/status',
  endpointIdentification(ENDPOINTS.INTEL_STATUS),
  basisIntelStatusHandler
);

// Export for consistency with other routers
export default basisEndpointsRouter;