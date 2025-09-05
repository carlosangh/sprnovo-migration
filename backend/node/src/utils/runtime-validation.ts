/**
 * Runtime validation utilities with TypeScript-PRO patterns
 * Type-safe validation with compile-time and runtime checks
 */

import type { ValidationResult } from './errors';
import { createValidationResult, createValidationError } from './errors';

// Base validator interface
export interface Validator<T> {
  validate(value: unknown): ValidationResult<T>;
  and<U>(other: Validator<U>): Validator<T & U>;
  or<U>(other: Validator<U>): Validator<T | U>;
  optional(): Validator<T | undefined>;
  nullable(): Validator<T | null>;
}

// Base validator implementation
class BaseValidator<T> implements Validator<T> {
  constructor(private readonly validateFn: (value: unknown) => ValidationResult<T>) {}

  public validate(value: unknown): ValidationResult<T> {
    return this.validateFn(value);
  }

  public and<U>(other: Validator<U>): Validator<T & U> {
    return new BaseValidator<T & U>((value: unknown) => {
      const thisResult = this.validate(value);
      if (!thisResult.isValid) {
        return thisResult as ValidationResult<T & U>;
      }

      const otherResult = other.validate(value);
      if (!otherResult.isValid) {
        return otherResult as ValidationResult<T & U>;
      }

      return createValidationResult(true, thisResult.data as T & U, []);
    });
  }

  public or<U>(other: Validator<U>): Validator<T | U> {
    return new BaseValidator<T | U>((value: unknown) => {
      const thisResult = this.validate(value);
      if (thisResult.isValid) {
        return thisResult as ValidationResult<T | U>;
      }

      const otherResult = other.validate(value);
      if (otherResult.isValid) {
        return otherResult as ValidationResult<T | U>;
      }

      return createValidationResult(
        false,
        undefined,
        [...thisResult.errors, ...otherResult.errors]
      );
    });
  }

  public optional(): Validator<T | undefined> {
    return new BaseValidator<T | undefined>((value: unknown) => {
      if (value === undefined) {
        return createValidationResult(true, undefined, []);
      }
      const result = this.validate(value);
      if (result.isValid) {
        return createValidationResult(true, result.data, []);
      }
      return createValidationResult(false, undefined, result.errors);
    });
  }

  public nullable(): Validator<T | null> {
    return new BaseValidator<T | null>((value: unknown) => {
      if (value === null) {
        return createValidationResult(true, null, []);
      }
      return this.validate(value) as ValidationResult<T | null>;
    });
  }
}

// Primitive validators
export const string = (): Validator<string> =>
  new BaseValidator((value: unknown) => {
    if (typeof value === 'string') {
      return createValidationResult(true, value, []);
    }
    return createValidationResult(false, undefined, ['Expected string']);
  });

export const number = (): Validator<number> =>
  new BaseValidator((value: unknown) => {
    if (typeof value === 'number' && !isNaN(value)) {
      return createValidationResult(true, value, []);
    }
    return createValidationResult(false, undefined, ['Expected number']);
  });

export const boolean = (): Validator<boolean> =>
  new BaseValidator((value: unknown) => {
    if (typeof value === 'boolean') {
      return createValidationResult(true, value, []);
    }
    return createValidationResult(false, undefined, ['Expected boolean']);
  });

// String validators with constraints
export const minLength = (min: number): ((validator: Validator<string>) => Validator<string>) =>
  (validator: Validator<string>) => 
    new BaseValidator<string>((value: unknown) => {
      const result = validator.validate(value);
      if (!result.isValid || !result.data) {
        return createValidationResult(false, undefined, result.errors);
      }
      
      if (result.data.length < min) {
        return createValidationResult(
          false,
          undefined,
          [`String must be at least ${min} characters long`]
        );
      }
      
      return result;
    });

export const maxLength = (max: number): ((validator: Validator<string>) => Validator<string>) =>
  (validator: Validator<string>) => 
    new BaseValidator<string>((value: unknown) => {
      const result = validator.validate(value);
      if (!result.isValid || !result.data) {
        return createValidationResult(false, undefined, result.errors);
      }
      
      if (result.data.length > max) {
        return createValidationResult(
          false,
          undefined,
          [`String must be no more than ${max} characters long`]
        );
      }
      
      return result;
    });

export const pattern = (regex: RegExp): ((validator: Validator<string>) => Validator<string>) =>
  (validator: Validator<string>) => 
    new BaseValidator<string>((value: unknown) => {
      const result = validator.validate(value);
      if (!result.isValid || !result.data) {
        return createValidationResult(false, undefined, result.errors);
      }
      
      if (!regex.test(result.data)) {
        return createValidationResult(
          false,
          undefined,
          [`String does not match pattern ${regex.source}`]
        );
      }
      
      return result;
    });

// Number validators with constraints
export const min = (minValue: number): ((validator: Validator<number>) => Validator<number>) =>
  (validator: Validator<number>) => 
    new BaseValidator<number>((value: unknown) => {
      const result = validator.validate(value);
      if (!result.isValid || result.data === undefined) {
        return createValidationResult(false, undefined, result.errors);
      }
      
      if (result.data < minValue) {
        return createValidationResult(
          false,
          undefined,
          [`Number must be at least ${minValue}`]
        );
      }
      
      return result;
    });

export const max = (maxValue: number): ((validator: Validator<number>) => Validator<number>) =>
  (validator: Validator<number>) => 
    new BaseValidator<number>((value: unknown) => {
      const result = validator.validate(value);
      if (!result.isValid || result.data === undefined) {
        return createValidationResult(false, undefined, result.errors);
      }
      
      if (result.data > maxValue) {
        return createValidationResult(
          false,
          undefined,
          [`Number must be no more than ${maxValue}`]
        );
      }
      
      return result;
    });

// Array validator
export const array = <T>(itemValidator: Validator<T>): Validator<T[]> =>
  new BaseValidator<T[]>((value: unknown) => {
    if (!Array.isArray(value)) {
      return createValidationResult(false, undefined, ['Expected array']);
    }

    const results: T[] = [];
    const errors: string[] = [];

    for (let i = 0; i < value.length; i++) {
      const itemResult = itemValidator.validate(value[i]);
      if (itemResult.isValid && itemResult.data !== undefined) {
        results.push(itemResult.data);
      } else {
        errors.push(`Item at index ${i}: ${itemResult.errors.join(', ')}`);
      }
    }

    if (errors.length > 0) {
      return createValidationResult(false, undefined, errors);
    }

    return createValidationResult(true, results, []);
  });

// Object validator with strict typing
export const object = <T extends Record<string, unknown>>(
  schema: { [K in keyof T]: Validator<T[K]> }
): Validator<T> =>
  new BaseValidator<T>((value: unknown) => {
    if (typeof value !== 'object' || value === null) {
      return createValidationResult(false, undefined, ['Expected object']);
    }

    const obj = value as Record<string, unknown>;
    const result: Partial<T> = {};
    const errors: string[] = [];

    for (const key in schema) {
      if (Object.prototype.hasOwnProperty.call(schema, key)) {
        const validator = schema[key];
        const fieldResult = validator.validate(obj[key]);
        
        if (fieldResult.isValid && fieldResult.data !== undefined) {
          result[key] = fieldResult.data;
        } else {
          errors.push(`Field '${key}': ${fieldResult.errors.join(', ')}`);
        }
      }
    }

    if (errors.length > 0) {
      return createValidationResult(false, undefined, errors);
    }

    return createValidationResult(true, result as T, []);
  });

// Utility function to validate and throw on error
export const validateOrThrow = <T>(validator: Validator<T>, value: unknown): T => {
  const result = validator.validate(value);
  
  if (!result.isValid) {
    throw createValidationError('Validation failed', {
      errors: result.errors,
      value: value,
    });
  }
  
  if (result.data === undefined) {
    throw createValidationError('Validation succeeded but data is undefined');
  }
  
  return result.data;
};

// Type predicate function for runtime type checking
export const isType = <T>(validator: Validator<T>) => 
  (value: unknown): value is T => validator.validate(value).isValid;

// Example usage validators for common API patterns
export const portValidator = new BaseValidator<number>((value: unknown) => {
  const numResult = number().validate(value);
  if (!numResult.isValid || numResult.data === undefined) {
    return createValidationResult(false, undefined, numResult.errors);
  }
  
  if (numResult.data < 1 || numResult.data > 65535) {
    return createValidationResult(
      false,
      undefined,
      ['Port must be between 1 and 65535']
    );
  }
  
  return numResult;
});

export const emailValidator = new BaseValidator<string>((value: unknown) => {
  const strResult = string().validate(value);
  if (!strResult.isValid || !strResult.data) {
    return createValidationResult(false, undefined, strResult.errors);
  }
  
  const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailPattern.test(strResult.data)) {
    return createValidationResult(
      false,
      undefined,
      ['Invalid email format']
    );
  }
  
  return strResult;
});

export const urlValidator = new BaseValidator<string>((value: unknown) => {
  const strResult = string().validate(value);
  if (!strResult.isValid || !strResult.data) {
    return createValidationResult(false, undefined, strResult.errors);
  }
  
  try {
    new URL(strResult.data);
    return strResult;
  } catch {
    return createValidationResult(
      false,
      undefined,
      ['Invalid URL format']
    );
  }
});

// Environment configuration validator  
export const envConfigValidator = object({
  NODE_ENV: new BaseValidator<string>((value: unknown) => {
    const strResult = string().validate(value);
    if (!strResult.isValid || !strResult.data) {
      return createValidationResult(false, undefined, strResult.errors);
    }
    
    const validValues = ['development', 'production', 'test'];
    if (!validValues.includes(strResult.data)) {
      return createValidationResult(
        false,
        undefined,
        [`NODE_ENV must be one of: ${validValues.join(', ')}`]
      );
    }
    
    return strResult;
  }),
  PORT: portValidator,
  TRUST_PROXY: boolean(),
});