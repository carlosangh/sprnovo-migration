/**
 * Response helper utilities for consistent API responses
 * TypeScript-PRO patterns for type-safe response handling
 */

import type { Response } from 'express';
import type { 
  ApiResult, 
  SuccessResponse, 
  ErrorResponse,
  ApiError,
  TimestampMs,
  EndpointId,
  ServiceName
} from '@/types/core';
import { HttpStatus } from '@/types/core';
import type { TypedResponse } from '@/types/express';
import { TypedError } from './errors';

// Response builder with fluent API
export class ResponseBuilder<TData = unknown> {
  private data?: TData;
  private error?: ApiError;
  private endpointId?: EndpointId;
  private serviceName?: ServiceName;
  private httpStatus: HttpStatus = HttpStatus.OK;

  public setData(data: TData): ResponseBuilder<TData> {
    this.data = data;
    return this;
  }

  public setError(error: ApiError): ResponseBuilder<TData> {
    this.error = error;
    return this;
  }

  public setEndpointId(endpointId: EndpointId): ResponseBuilder<TData> {
    this.endpointId = endpointId;
    return this;
  }

  public setServiceName(serviceName: ServiceName): ResponseBuilder<TData> {
    this.serviceName = serviceName;
    return this;
  }

  public setHttpStatus(status: HttpStatus): ResponseBuilder<TData> {
    this.httpStatus = status;
    return this;
  }

  public buildSuccess(): SuccessResponse<TData> {
    if (this.data === undefined) {
      throw new TypedError(
        'VALIDATION_ERROR' as const,
        'Cannot build success response without data'
      );
    }

    return {
      ok: true,
      data: this.data,
      meta: {
        timestamp: Date.now() as TimestampMs,
        endpoint: this.endpointId,
        service: this.serviceName,
      },
    };
  }

  public buildError(): ErrorResponse {
    if (!this.error) {
      throw new TypedError(
        'VALIDATION_ERROR' as const,
        'Cannot build error response without error'
      );
    }

    return {
      ok: false,
      error: this.error,
      meta: {
        timestamp: Date.now() as TimestampMs,
        endpoint: this.endpointId,
        service: this.serviceName,
      },
    };
  }

  public build(): ApiResult<TData> {
    return this.error ? this.buildError() : this.buildSuccess();
  }

  public send(res: Response): void {
    const result = this.build();
    res.status(this.httpStatus).json(result);
  }
}

// Factory functions for common responses
export const createSuccessResponse = <TData>(
  data: TData,
  endpointId?: EndpointId,
  serviceName?: ServiceName
): SuccessResponse<TData> => {
  return new ResponseBuilder<TData>()
    .setData(data)
    .setEndpointId(endpointId!)
    .setServiceName(serviceName!)
    .buildSuccess();
};

export const createErrorResponse = (
  error: ApiError,
  endpointId?: EndpointId,
  serviceName?: ServiceName
): ErrorResponse => {
  return new ResponseBuilder()
    .setError(error)
    .setEndpointId(endpointId!)
    .setServiceName(serviceName!)
    .buildError();
};

// Response helpers for Express Response object
export const sendSuccess = <TData>(
  res: Response,
  data: TData,
  status: HttpStatus = HttpStatus.OK,
  endpointId?: EndpointId,
  serviceName?: ServiceName
): void => {
  const response = createSuccessResponse(data, endpointId, serviceName);
  res.status(status).json(response);
};

export const sendError = (
  res: Response,
  error: ApiError | TypedError,
  status?: HttpStatus,
  endpointId?: EndpointId,
  serviceName?: ServiceName
): void => {
  const apiError = error instanceof TypedError ? error.toApiError() : error;
  const httpStatus = status || (error instanceof TypedError ? error.httpStatus : HttpStatus.INTERNAL_SERVER_ERROR);
  
  const response = createErrorResponse(apiError, endpointId, serviceName);
  res.status(httpStatus).json(response);
};

// Enhanced response methods for TypedResponse
export const enhanceResponse = (res: Response): any => {
  const typedRes = res as any;

  typedRes.jsonSuccess = function<T>(
    data: T,
    status: HttpStatus = HttpStatus.OK
  ): Response {
    sendSuccess(this, data, status);
    return this;
  };

  typedRes.jsonError = function(
    error: ApiError,
    status: HttpStatus = HttpStatus.INTERNAL_SERVER_ERROR
  ): Response {
    sendError(this, error, status);
    return this;
  };

  typedRes.jsonResult = function<T>(
    result: ApiResult<T>
  ): Response {
    this.json(result);
    return this;
  };

  return typedRes;
};

// Utility functions for common response patterns
export const okResponse = <TData>(
  data: TData,
  endpointId?: EndpointId,
  serviceName?: ServiceName
): SuccessResponse<TData> => 
  createSuccessResponse(data, endpointId, serviceName);

export const createdResponse = <TData>(
  data: TData,
  endpointId?: EndpointId,
  serviceName?: ServiceName
): SuccessResponse<TData> => 
  createSuccessResponse(data, endpointId, serviceName);

export const noContentResponse = (): SuccessResponse<null> =>
  createSuccessResponse(null);

// Type-safe endpoint status response
export interface EndpointStatusData {
  readonly ok: boolean;
  readonly endpoint: string;
  readonly service?: string;
  readonly timestamp?: number;
}

export const createEndpointStatusResponse = (
  endpoint: string,
  service?: string
): SuccessResponse<EndpointStatusData> => {
  return createSuccessResponse({
    ok: true,
    endpoint,
    service,
    timestamp: Date.now(),
  });
};

// Health check response
export interface HealthCheckData {
  readonly status: 'ok' | 'error';
  readonly timestamp: number;
  readonly uptime?: number;
  readonly version?: string;
  readonly environment?: string;
}

export const createHealthCheckResponse = (
  uptime?: number,
  version?: string,
  environment?: string
): SuccessResponse<HealthCheckData> => {
  return createSuccessResponse({
    status: 'ok' as const,
    timestamp: Date.now(),
    uptime,
    version,
    environment,
  });
};