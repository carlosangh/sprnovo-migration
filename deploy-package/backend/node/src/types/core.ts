/**
 * Core TypeScript-PRO types with branded typing and strict definitions
 * Zero `any` policy - all types must be explicitly defined
 */

// Branded Types for Domain Safety
export type Brand<T, B extends string> = T & { readonly __brand: B };

// ID Types with Brand Safety
export type EndpointId = Brand<string, 'EndpointId'>;
export type ServiceId = Brand<string, 'ServiceId'>;
export type TimestampMs = Brand<number, 'TimestampMs'>;
export type Port = Brand<number, 'Port'>;

// Utility to create branded values
export const createBrand = <T, B extends string>(value: T): Brand<T, B> => 
  value as Brand<T, B>;

// Type-safe constants
export const SERVICES = {
  BASIS: createBrand<string, 'ServiceId'>('basis'),
  NEWS: createBrand<string, 'ServiceId'>('news'),
  INTEL: createBrand<string, 'ServiceId'>('intel'),
} as const;

export type ServiceName = typeof SERVICES[keyof typeof SERVICES];

// Environment Configuration Types
export interface EnvironmentConfig {
  readonly NODE_ENV: 'development' | 'production' | 'test';
  readonly PORT: Port;
  readonly TRUST_PROXY: boolean;
}

// Error Types with Exhaustive Checking
export const enum ErrorCode {
  VALIDATION_ERROR = 'VALIDATION_ERROR',
  NOT_FOUND = 'NOT_FOUND',
  INTERNAL_SERVER_ERROR = 'INTERNAL_SERVER_ERROR',
  UNAUTHORIZED = 'UNAUTHORIZED',
  FORBIDDEN = 'FORBIDDEN',
  BAD_REQUEST = 'BAD_REQUEST',
}

export interface ApiError {
  readonly code: ErrorCode;
  readonly message: string;
  readonly details?: Record<string, unknown>;
  readonly timestamp: TimestampMs;
}

// HTTP Status Codes with Type Safety
export const enum HttpStatus {
  OK = 200,
  CREATED = 201,
  NO_CONTENT = 204,
  BAD_REQUEST = 400,
  UNAUTHORIZED = 401,
  FORBIDDEN = 403,
  NOT_FOUND = 404,
  INTERNAL_SERVER_ERROR = 500,
  SERVICE_UNAVAILABLE = 503,
}

// Generic API Response Structure
export interface ApiResponse<TData = unknown> {
  readonly ok: boolean;
  readonly data?: TData;
  readonly error?: ApiError;
  readonly meta?: {
    readonly timestamp: TimestampMs;
    readonly endpoint?: EndpointId;
    readonly service?: ServiceName;
  };
}

// Success Response Type
export interface SuccessResponse<TData = unknown> extends ApiResponse<TData> {
  readonly ok: true;
  readonly data: TData;
  readonly error?: never;
}

// Error Response Type
export interface ErrorResponse extends ApiResponse<never> {
  readonly ok: false;
  readonly data?: never;
  readonly error: ApiError;
}

// Union type for all possible responses
export type ApiResult<TData = unknown> = SuccessResponse<TData> | ErrorResponse;

// Type Guards for Response Types
export const isSuccessResponse = <TData>(
  response: ApiResult<TData>
): response is SuccessResponse<TData> => response.ok === true;

export const isErrorResponse = (
  response: ApiResult<unknown>
): response is ErrorResponse => response.ok === false;

// Endpoint Data Types
export interface EndpointStatus {
  readonly ok: boolean;
  readonly endpoint: EndpointId;
  readonly service?: ServiceName;
  readonly timestamp?: TimestampMs;
}

export interface HealthStatus {
  readonly status: 'ok' | 'error';
  readonly timestamp: TimestampMs;
  readonly uptime?: number;
  readonly version?: string;
}

// Type-safe endpoint definitions
export const ENDPOINTS = {
  NEWS_LATEST: createBrand<string, 'EndpointId'>('/news/latest'),
  REPORTS_WASDE_LATEST: createBrand<string, 'EndpointId'>('/reports/wasde/latest'),
  US_CROP_PROGRESS: createBrand<string, 'EndpointId'>('/us/crop-progress'),
  CFTC_COT: createBrand<string, 'EndpointId'>('/cftc/cot'),
  US_DROUGHT_LATEST: createBrand<string, 'EndpointId'>('/us/drought/latest'),
  EIA_ETHANOL_LATEST: createBrand<string, 'EndpointId'>('/eia/ethanol/latest'),
  INTEL_STATUS: createBrand<string, 'EndpointId'>('/intel/status'),
  HEALTH: createBrand<string, 'EndpointId'>('/health'),
} as const;

export type EndpointPath = typeof ENDPOINTS[keyof typeof ENDPOINTS];

// Readonly configuration to prevent mutations
export type ReadonlyConfig<T> = {
  readonly [K in keyof T]: T[K] extends object 
    ? ReadonlyConfig<T[K]> 
    : T[K];
};