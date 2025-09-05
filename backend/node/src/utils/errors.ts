/**
 * Robust error handling system with typed exceptions
 * TypeScript-PRO pattern for comprehensive error management
 */

import type { 
  ApiError, 
  TimestampMs
} from '@/types/core';
import { ErrorCode, HttpStatus } from '@/types/core';

// Custom error class extending native Error
export class TypedError extends Error {
  public readonly code: ErrorCode;
  public readonly httpStatus: HttpStatus;
  public readonly details?: Record<string, unknown>;
  public readonly timestamp: TimestampMs;
  public readonly isOperational: boolean;

  constructor(
    code: ErrorCode,
    message: string,
    httpStatus: HttpStatus = HttpStatus.INTERNAL_SERVER_ERROR,
    details?: Record<string, unknown>,
    isOperational: boolean = true
  ) {
    super(message);
    
    this.name = 'TypedError';
    this.code = code;
    this.httpStatus = httpStatus;
    this.details = details;
    this.timestamp = Date.now() as TimestampMs;
    this.isOperational = isOperational;
    
    // Maintain proper stack trace in V8
    if (Error.captureStackTrace) {
      Error.captureStackTrace(this, TypedError);
    }
  }

  /**
   * Convert error to API error format
   */
  public toApiError(): ApiError {
    return {
      code: this.code,
      message: this.message,
      details: this.details,
      timestamp: this.timestamp,
    };
  }

  /**
   * Check if error is operational (expected) vs programming error
   */
  public static isOperational(error: Error): boolean {
    return error instanceof TypedError && error.isOperational;
  }
}

// Factory functions for common error types
export const createValidationError = (
  message: string,
  details?: Record<string, unknown>
): TypedError => new TypedError(
  ErrorCode.VALIDATION_ERROR,
  message,
  HttpStatus.BAD_REQUEST,
  details
);

export const createNotFoundError = (
  resource: string,
  details?: Record<string, unknown>
): TypedError => new TypedError(
  ErrorCode.NOT_FOUND,
  `Resource not found: ${resource}`,
  HttpStatus.NOT_FOUND,
  details
);

export const createUnauthorizedError = (
  message: string = 'Unauthorized access',
  details?: Record<string, unknown>
): TypedError => new TypedError(
  ErrorCode.UNAUTHORIZED,
  message,
  HttpStatus.UNAUTHORIZED,
  details
);

export const createForbiddenError = (
  message: string = 'Access forbidden',
  details?: Record<string, unknown>
): TypedError => new TypedError(
  ErrorCode.FORBIDDEN,
  message,
  HttpStatus.FORBIDDEN,
  details
);

export const createInternalServerError = (
  message: string = 'Internal server error',
  details?: Record<string, unknown>
): TypedError => new TypedError(
  ErrorCode.INTERNAL_SERVER_ERROR,
  message,
  HttpStatus.INTERNAL_SERVER_ERROR,
  details,
  false // Programming errors are not operational
);

// Error handler utilities
export const handleAsyncError = <T extends unknown[], R>(
  fn: (...args: T) => Promise<R>
) => {
  return (...args: T): Promise<R> => {
    return fn(...args).catch((error: unknown) => {
      throw normalizeError(error);
    });
  };
};

// Normalize unknown errors to TypedError
export const normalizeError = (error: unknown): TypedError => {
  if (error instanceof TypedError) {
    return error;
  }
  
  if (error instanceof Error) {
    return createInternalServerError(
      error.message,
      { originalStack: error.stack }
    );
  }
  
  return createInternalServerError(
    'Unknown error occurred',
    { originalError: String(error) }
  );
};

// Type-safe error result pattern
export type Result<T, E = TypedError> = 
  | { readonly success: true; readonly data: T }
  | { readonly success: false; readonly error: E };

export const success = <T>(data: T): Result<T, never> => ({
  success: true,
  data,
});

export const failure = <E = TypedError>(error: E): Result<never, E> => ({
  success: false,
  error,
});

// Result type guards
export const isSuccess = <T, E>(result: Result<T, E>): result is Result<T, never> =>
  result.success === true;

export const isFailure = <T, E>(result: Result<T, E>): result is Result<never, E> =>
  result.success === false;

// Safe async operation wrapper
export const safeAsync = async <T>(
  operation: () => Promise<T>
): Promise<Result<T, TypedError>> => {
  try {
    const data = await operation();
    return success(data);
  } catch (error) {
    return failure(normalizeError(error));
  }
};

// Validation result type
export interface ValidationResult<T> {
  readonly isValid: boolean;
  readonly data?: T;
  readonly errors: ReadonlyArray<string>;
}

export const createValidationResult = <T>(
  isValid: boolean,
  data?: T,
  errors: ReadonlyArray<string> = []
): ValidationResult<T> => ({
  isValid,
  data,
  errors,
});

// Error aggregator for multiple validations
export class ErrorAggregator {
  private readonly errors: string[] = [];

  public add(error: string): this {
    this.errors.push(error);
    return this;
  }

  public addIf(condition: boolean, error: string): this {
    if (condition) {
      this.errors.push(error);
    }
    return this;
  }

  public hasErrors(): boolean {
    return this.errors.length > 0;
  }

  public getErrors(): ReadonlyArray<string> {
    return [...this.errors];
  }

  public throwIfHasErrors(): void {
    if (this.hasErrors()) {
      throw createValidationError(
        'Validation failed',
        { errors: this.getErrors() }
      );
    }
  }
}