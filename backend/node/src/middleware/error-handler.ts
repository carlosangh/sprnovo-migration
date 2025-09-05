/**
 * Comprehensive error handling middleware
 * TypeScript-PRO patterns for robust error management
 */

import type { Request, Response, NextFunction } from 'express';
import type { ExpressErrorHandler, ExpressRouteHandler } from '@/types/express';
import { TypedError, normalizeError } from '@/utils/errors';
import { sendError } from '@/utils/response-helpers';
import { HttpStatus, ErrorCode } from '@/types/core';

// Global error handler middleware
export const errorHandler: ExpressErrorHandler = (
  error: unknown,
  req: Request,
  res: Response,
  _next: NextFunction
): void => {
  const normalizedError = normalizeError(error);
  
  // Log error for monitoring (in production, use structured logging)
  console.error({
    message: normalizedError.message,
    code: normalizedError.code,
    stack: normalizedError.stack,
    url: req.url,
    method: req.method,
    timestamp: normalizedError.timestamp,
    isOperational: normalizedError.isOperational,
  });

  // Send appropriate error response
  sendError(res, normalizedError);
};

// Async error wrapper for route handlers
export const asyncHandler = (
  fn: (req: Request, res: Response, next: NextFunction) => Promise<any>
) => {
  return (req: Request, res: Response, next: NextFunction): void => {
    Promise.resolve(fn(req, res, next)).catch((error: unknown) => {
      next(normalizeError(error));
    });
  };
};

// 404 Not Found handler
export const notFoundHandler: ExpressRouteHandler = (
  req: Request,
  res: Response,
  _next: NextFunction
): void => {
  const error = new TypedError(
    'NOT_FOUND' as ErrorCode,
    `Route not found: ${req.method} ${req.path}`,
    HttpStatus.NOT_FOUND,
    { 
      method: req.method, 
      path: req.path,
      originalUrl: req.originalUrl 
    }
  );

  sendError(res, error);
};

// Validation error handler
export const validationErrorHandler: ExpressErrorHandler = (
  error: unknown,
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  if (error instanceof TypedError && error.code === 'VALIDATION_ERROR') {
    sendError(res, error);
    return;
  }
  
  next(error);
};

// Operational vs Programming error handler
export const operationalErrorHandler: ExpressErrorHandler = (
  error: unknown,
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  if (error instanceof TypedError && error.isOperational) {
    sendError(res, error);
    return;
  }
  
  // For programming errors, log more details but don't expose them
  if (error instanceof TypedError && !error.isOperational) {
    console.error('Programming Error:', {
      error: error.message,
      stack: error.stack,
      details: error.details,
      url: req.url,
      method: req.method,
    });
    
    const safeError = new TypedError(
      ErrorCode.INTERNAL_SERVER_ERROR,
      'An unexpected error occurred',
      HttpStatus.INTERNAL_SERVER_ERROR
    );
    
    sendError(res, safeError);
    return;
  }
  
  next(error);
};