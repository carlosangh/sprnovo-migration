/**
 * Express.js type extensions with strict typing
 * Enhanced Request/Response interfaces for TypeScript-PRO patterns
 */

import type { Request, Response, NextFunction, Router } from 'express';

// Module augmentation to extend Express's Request interface globally
declare global {
  namespace Express {
    interface Request {
      startTime?: TimestampMs;
      endpointId?: EndpointId;
    }

    interface Response {
      jsonSuccess?<T>(
        data: T,
        status?: HttpStatus
      ): Response;
      
      jsonError?(
        error: ApiError,
        status?: HttpStatus
      ): Response;
      
      jsonResult?<T>(
        result: ApiResult<T>
      ): Response;
    }
  }
}
import type { 
  ApiResult, 
  ApiError, 
  TimestampMs, 
  EndpointId,
  HttpStatus 
} from './core';

// Extended Request interface with strict typing
export interface TypedRequest<
  TParams = Record<string, string>,
  TQuery = Record<string, string | string[] | undefined>,
  TBody = unknown
> extends Request<TParams, unknown, TBody, TQuery> {
  startTime?: TimestampMs;
  endpointId?: EndpointId;
}

// Enhanced Response interface with typed methods
export interface TypedResponse<TData = unknown> extends Response {
  jsonSuccess<T extends TData>(
    data: T,
    status?: HttpStatus
  ): Response;
  
  jsonError(
    error: ApiError,
    status?: HttpStatus
  ): Response;
  
  jsonResult<T extends TData>(
    result: ApiResult<T>
  ): Response;
}

// Middleware function types with strict typing
export type TypedMiddleware<
  TRequest extends TypedRequest = TypedRequest,
  TResponse extends TypedResponse = TypedResponse
> = (
  req: TRequest,
  res: TResponse,
  next: NextFunction
) => void | Promise<void>;

// Standard Express-compatible route handler
export type ExpressRouteHandler<
  TParams = Record<string, string>,
  TQuery = Record<string, string | string[] | undefined>,
  TBody = unknown,
  TResponseData = unknown
> = (
  req: Request<TParams, unknown, TBody, TQuery>,
  res: Response,
  next: NextFunction
) => void | Promise<void>;

// Enhanced route handler with typed interfaces
export type RouteHandler<
  TParams = Record<string, string>,
  TQuery = Record<string, string | string[] | undefined>,
  TBody = unknown,
  TResponseData = unknown
> = (
  req: TypedRequest<TParams, TQuery, TBody>,
  res: TypedResponse<TResponseData>,
  next: NextFunction
) => void | Promise<void>;

// Standard Express-compatible error handler
export type ExpressErrorHandler = (
  error: Error | ApiError,
  req: Request,
  res: Response,
  next: NextFunction
) => void | Promise<void>;

// Enhanced error handler with typed interfaces
export type ErrorHandler = (
  error: Error | ApiError,
  req: TypedRequest,
  res: TypedResponse,
  next: NextFunction
) => void | Promise<void>;

// Router with typed methods
export interface TypedRouter extends Router {
  get<TParams = Record<string, string>, TQuery = Record<string, string>, TResponseData = unknown>(
    path: string,
    ...handlers: Array<RouteHandler<TParams, TQuery, never, TResponseData>>
  ): this;
  
  post<TParams = Record<string, string>, TQuery = Record<string, string>, TBody = unknown, TResponseData = unknown>(
    path: string,
    ...handlers: Array<RouteHandler<TParams, TQuery, TBody, TResponseData>>
  ): this;
  
  put<TParams = Record<string, string>, TQuery = Record<string, string>, TBody = unknown, TResponseData = unknown>(
    path: string,
    ...handlers: Array<RouteHandler<TParams, TQuery, TBody, TResponseData>>
  ): this;
  
  delete<TParams = Record<string, string>, TQuery = Record<string, string>, TResponseData = unknown>(
    path: string,
    ...handlers: Array<RouteHandler<TParams, TQuery, never, TResponseData>>
  ): this;
  
  patch<TParams = Record<string, string>, TQuery = Record<string, string>, TBody = unknown, TResponseData = unknown>(
    path: string,
    ...handlers: Array<RouteHandler<TParams, TQuery, TBody, TResponseData>>
  ): this;
}

// Application configuration interface
export interface AppConfig {
  readonly trustProxy: boolean;
  readonly jsonLimit: string;
  readonly urlencodedExtended: boolean;
  readonly cors?: {
    readonly origin: string | string[] | boolean;
    readonly credentials: boolean;
    readonly methods?: string[];
    readonly allowedHeaders?: string[];
  };
}

// Route configuration for type-safe route registration
export interface RouteConfig<TResponseData = unknown> {
  readonly method: 'GET' | 'POST' | 'PUT' | 'DELETE' | 'PATCH';
  readonly path: string;
  readonly handler: RouteHandler<any, any, any, TResponseData>;
  readonly middleware?: TypedMiddleware[];
  readonly description?: string;
}

// Type helper for extracting response data type from route handler
export type ExtractResponseData<T> = T extends RouteHandler<any, any, any, infer R> 
  ? R 
  : unknown;

// Utility type for route registry
export type RouteRegistry = ReadonlyArray<RouteConfig>;

// Type-safe route builder pattern
export interface RouteBuilder {
  get<TResponseData>(
    path: string,
    handler: RouteHandler<any, any, never, TResponseData>
  ): RouteBuilder;
  
  post<TBody, TResponseData>(
    path: string,
    handler: RouteHandler<any, any, TBody, TResponseData>
  ): RouteBuilder;
  
  middleware(middleware: TypedMiddleware): RouteBuilder;
  
  build(): RouteRegistry;
}