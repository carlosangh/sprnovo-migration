/**
 * Main server application with TypeScript-PRO patterns
 * Enterprise-grade Express.js server with strict typing
 */

import express, { type Application } from 'express';
import cors from 'cors';
import path from 'path';
import type { 
  Port, 
  EnvironmentConfig, 
  ReadonlyConfig,
  TimestampMs,
} from '@/types/core';
import type { AppConfig } from '@/types/express';
import { createBrand } from '@/types/core';
import { 
  errorHandler, 
  notFoundHandler, 
  validationErrorHandler,
  operationalErrorHandler 
} from '@/middleware/error-handler';
import { 
  createRequestEnhancementStack,
  validateContentType,
  requestSizeLimit 
} from '@/middleware/request-enhancement';
import { newEndpointsRouter } from '@/routes/new-endpoints';
import { basisEndpointsRouter } from '@/routes/basis-endpoints';
import { healthRouter } from '@/routes/health';
import { whatsappRouter } from '@/routes/whatsapp';
import { createHealthCheckResponse } from '@/utils/response-helpers';

// Environment configuration with strict typing
const createEnvironmentConfig = (): ReadonlyConfig<EnvironmentConfig> => {
  const port = parseInt(process.env['PORT'] || '3002', 10);
  
  if (isNaN(port) || port < 1 || port > 65535) {
    throw new Error(`Invalid PORT: ${process.env['PORT']}. Must be a number between 1-65535`);
  }

  return {
    NODE_ENV: (process.env['NODE_ENV'] as EnvironmentConfig['NODE_ENV']) || 'development',
    PORT: createBrand<number, 'Port'>(port),
    TRUST_PROXY: process.env['TRUST_PROXY'] === 'true' || process.env['TRUST_PROXY'] === '1',
  } as const;
};

// Application configuration
const createAppConfig = (): ReadonlyConfig<AppConfig> => ({
  trustProxy: true,
  jsonLimit: '10mb',
  urlencodedExtended: true,
  cors: {
    origin: [
      'https://www.royalnegociosagricolas.com.br',
      'http://localhost:3000',
      'http://localhost:8080',
      'http://127.0.0.1:8080'
    ],
    credentials: false,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
  },
} as const);

// Server class with dependency injection pattern
export class Server {
  private readonly app: Application;
  private readonly config: ReadonlyConfig<EnvironmentConfig>;
  private readonly appConfig: ReadonlyConfig<AppConfig>;
  private readonly startTime: TimestampMs;

  constructor(
    config?: Partial<EnvironmentConfig>,
    appConfig?: Partial<AppConfig>
  ) {
    this.app = express();
    this.config = { ...createEnvironmentConfig(), ...config };
    this.appConfig = { ...createAppConfig(), ...appConfig };
    this.startTime = Date.now() as TimestampMs;

    this.setupMiddleware();
    this.setupRoutes();
    this.setupErrorHandling();
  }

  /**
   * Configure application middleware with type safety
   */
  private setupMiddleware(): void {
    // CORS configuration - MUST be first
    this.app.use(cors({
      origin: this.appConfig.cors?.origin || true,
      credentials: this.appConfig.cors?.credentials || false,
      methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
      allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
      optionsSuccessStatus: 200
    }));

    // Trust proxy configuration
    if (this.appConfig.trustProxy) {
      this.app.set('trust proxy', 1);
    }

    // Request parsing middleware
    this.app.use(express.json({ 
      limit: this.appConfig.jsonLimit,
      strict: true,
      type: 'application/json',
    }));
    
    this.app.use(express.urlencoded({ 
      extended: this.appConfig.urlencodedExtended,
      limit: this.appConfig.jsonLimit,
    }));

    // Request enhancement stack
    const enhancementMiddleware = createRequestEnhancementStack();
    enhancementMiddleware.forEach(middleware => {
      this.app.use(middleware);
    });

    // Content type validation for API routes
    this.app.use('/api', validateContentType('application/json'));
    
    // Request size limit
    this.app.use(requestSizeLimit(10 * 1024 * 1024)); // 10MB

    // Static files serving - Frontend build
    const frontendBuildPath = path.join(__dirname, '../frontend/build');
    this.app.use(express.static(frontendBuildPath));
  }

  /**
   * Setup application routes with type safety
   */
  private setupRoutes(): void {
    // API routes
    this.app.use('/api', newEndpointsRouter);
    this.app.use('/api', basisEndpointsRouter);
    
    // WhatsApp integration routes
    this.app.use('/', whatsappRouter);
    
    // Health check route
    this.app.use(healthRouter);

    // API root endpoint for basic connectivity test
    this.app.get('/api', (_req, res) => {
      const response = createHealthCheckResponse(
        this.getUptime(),
        process.env['npm_package_version'],
        this.config.NODE_ENV
      );
      res.json(response);
    });

    // Catch-all handler: send back React's index.html file for SPA routing
    this.app.get('*', (_req, res) => {
      const frontendBuildPath = path.join(__dirname, '../frontend/build');
      res.sendFile(path.join(frontendBuildPath, 'index.html'));
    });
  }

  /**
   * Setup error handling middleware chain
   */
  private setupErrorHandling(): void {
    // 404 handler for unmatched routes
    this.app.use(notFoundHandler);
    
    // Specific error handlers (order matters)
    this.app.use(validationErrorHandler);
    this.app.use(operationalErrorHandler);
    
    // Global error handler (must be last)
    this.app.use(errorHandler);
  }

  /**
   * Get server uptime in seconds
   */
  private getUptime(): number {
    return Math.floor((Date.now() - this.startTime) / 1000);
  }

  /**
   * Start the server
   */
  public listen(): Promise<void> {
    return new Promise((resolve, reject) => {
      try {
        const server = this.app.listen(this.config.PORT, () => {
          console.log({
            message: `[spr] Server listening on port ${this.config.PORT}`,
            port: this.config.PORT,
            environment: this.config.NODE_ENV,
            timestamp: Date.now(),
            uptime: this.getUptime(),
          });
          resolve();
        });

        server.on('error', (error: Error) => {
          console.error({
            message: 'Server failed to start',
            error: error.message,
            port: this.config.PORT,
            timestamp: Date.now(),
          });
          reject(error);
        });

        // Graceful shutdown handlers
        process.on('SIGTERM', () => this.gracefulShutdown(server));
        process.on('SIGINT', () => this.gracefulShutdown(server));
        
      } catch (error) {
        console.error({
          message: 'Failed to initialize server',
          error: error instanceof Error ? error.message : String(error),
          timestamp: Date.now(),
        });
        reject(error);
      }
    });
  }

  /**
   * Graceful server shutdown
   */
  private gracefulShutdown(server: any): void {
    console.log({
      message: 'Shutting down server gracefully',
      timestamp: Date.now(),
      uptime: this.getUptime(),
    });

    server.close(() => {
      console.log({
        message: 'Server shut down complete',
        timestamp: Date.now(),
      });
      process.exit(0);
    });

    // Force close after 30 seconds
    setTimeout(() => {
      console.error({
        message: 'Forced server shutdown after timeout',
        timestamp: Date.now(),
      });
      process.exit(1);
    }, 30000);
  }

  /**
   * Get Express application instance (for testing)
   */
  public getApp(): Application {
    return this.app;
  }

  /**
   * Get server configuration
   */
  public getConfig(): ReadonlyConfig<EnvironmentConfig> {
    return this.config;
  }
}

// Factory function for server creation
export const createServer = (
  config?: Partial<EnvironmentConfig>,
  appConfig?: Partial<AppConfig>
): Server => {
  return new Server(config, appConfig);
};

// Main execution if run directly
if (require.main === module) {
  const server = createServer();
  
  server.listen().catch((error: unknown) => {
    console.error({
      message: 'Failed to start server',
      error: error instanceof Error ? error.message : String(error),
      timestamp: Date.now(),
    });
    process.exit(1);
  });
}

export default Server;