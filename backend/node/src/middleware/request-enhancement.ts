/**
 * Request enhancement middleware for TypeScript-PRO patterns
 * Adds timing, tracing, and type safety to requests
 */

import type { Request, Response, NextFunction } from 'express';
import type { TypedRequest, TypedResponse, TypedMiddleware, ExpressRouteHandler } from '@/types/express';
import type { TimestampMs, EndpointId } from '@/types/core';
import { enhanceResponse } from '@/utils/response-helpers';

// Request timing middleware - Express compatible
export const requestTiming: ExpressRouteHandler = (
  req: Request,
  _res: Response,
  next: NextFunction
): void => {
  // Add start time to request using module augmentation
  req.startTime = Date.now() as TimestampMs;
  next();
};

// Response enhancement middleware - Express compatible
export const responseEnhancement: ExpressRouteHandler = (
  _req: Request,
  res: Response,
  next: NextFunction
): void => {
  enhanceResponse(res as TypedResponse);
  next();
};

// Endpoint identification middleware - Express compatible
export const endpointIdentification = (endpointId: EndpointId): ExpressRouteHandler => {
  return (req: Request, _res: Response, next: NextFunction): void => {
    req.endpointId = endpointId;
    next();
  };
};

// Request logging middleware (structured logging for production) - Express compatible
export const requestLogging: ExpressRouteHandler = (
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  const startTime = req.startTime || (Date.now() as TimestampMs);
  
  // Log request start
  console.log({
    type: 'request_start',
    method: req.method,
    url: req.url,
    userAgent: req.get('user-agent'),
    ip: req.ip,
    timestamp: startTime,
    endpointId: req.endpointId,
  });

  // Log response when finished
  res.on('finish', () => {
    const duration = Date.now() - startTime;
    
    console.log({
      type: 'request_complete',
      method: req.method,
      url: req.url,
      statusCode: res.statusCode,
      duration,
      timestamp: Date.now(),
      endpointId: req.endpointId,
    });
  });

  next();
};

// Security headers middleware - Express compatible
export const securityHeaders: ExpressRouteHandler = (
  _req: Request,
  res: Response,
  next: NextFunction
): void => {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('X-XSS-Protection', '1; mode=block');
  res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
  
  next();
};

// Content type validation middleware - Express compatible
export const validateContentType = (expectedType: string): ExpressRouteHandler => {
  return (req: Request, _res: Response, next: NextFunction): void => {
    if (req.method === 'POST' || req.method === 'PUT' || req.method === 'PATCH') {
      const contentType = req.get('content-type');
      
      if (!contentType || !contentType.includes(expectedType)) {
        const error = new Error(`Expected content-type: ${expectedType}`);
        next(error);
        return;
      }
    }
    
    next();
  };
};

// Request size limitation middleware - Express compatible
export const requestSizeLimit = (maxSize: number): ExpressRouteHandler => {
  return (req: Request, _res: Response, next: NextFunction): void => {
    const contentLength = req.get('content-length');
    
    if (contentLength && parseInt(contentLength) > maxSize) {
      const error = new Error(`Request size exceeds limit: ${maxSize} bytes`);
      next(error);
      return;
    }
    
    next();
  };
};

// Rate limiting placeholder (would integrate with Redis in production) - Express compatible
export const rateLimit = (
  maxRequests: number, 
  windowMs: number
): ExpressRouteHandler => {
  const requests = new Map<string, { count: number; resetTime: number }>();
  
  return (req: Request, res: Response, next: NextFunction): void => {
    const ip = req.ip || 'unknown';
    const now = Date.now();
    const current = requests.get(ip);
    
    if (!current || now > current.resetTime) {
      requests.set(ip, { count: 1, resetTime: now + windowMs });
      next();
      return;
    }
    
    if (current.count >= maxRequests) {
      res.status(429).json({
        ok: false,
        error: {
          code: 'RATE_LIMIT_EXCEEDED',
          message: 'Too many requests',
          timestamp: now,
        },
      });
      return;
    }
    
    current.count++;
    next();
  };
};

// Combine all request enhancement middleware - Express compatible
export const createRequestEnhancementStack = (): ExpressRouteHandler[] => [
  requestTiming,
  responseEnhancement,
  requestLogging,
  securityHeaders,
];