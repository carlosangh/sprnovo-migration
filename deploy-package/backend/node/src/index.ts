/**
 * Main entry point for TypeScript-PRO SPR Backend
 * Centralized exports with proper module organization
 */

// Core types and interfaces
export type * from '@/types/core';
export type * from '@/types/express';

// Server and application
export { Server, createServer } from './server';
export { default as ServerClass } from './server';

// Routers and routes
export { newEndpointsRouter } from '@/routes/new-endpoints';
export { basisEndpointsRouter } from '@/routes/basis-endpoints';
export { healthRouter } from '@/routes/health';

// Utilities
export * from '@/utils/errors';
export * from '@/utils/response-helpers';
export * from '@/utils/runtime-validation';

// Middleware
export * from '@/middleware/error-handler';
export * from '@/middleware/request-enhancement';

// Re-export commonly used types from dependencies
export type { Request, Response, NextFunction, Application, Router } from 'express';