import { FastifyInstance } from 'fastify';
import { logger } from './utils/logger';

// Import plugins
import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import rateLimit from '@fastify/rate-limit';
import swagger from '@fastify/swagger';
import swaggerUi from '@fastify/swagger-ui';

// Import routes (will create these next)
import { healthRoutes } from './routes/health';
import { projectRoutes } from './routes/projects';
import { authRoutes } from './routes/auth';

export async function buildApp(fastify: FastifyInstance) {
  // Database plugin
  await fastify.register(import('./plugins/database'));

  // Security plugins
  await fastify.register(helmet, {
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'self'"],
        styleSrc: ["'self'", "'unsafe-inline'"],
        scriptSrc: ["'self'"],
        imgSrc: ["'self'", "data:", "https:"],
      },
    },
  });

  // CORS configuration
  await fastify.register(cors, {
    origin: process.env.CORS_ORIGIN?.split(',') || ['http://localhost:3000'],
    credentials: true,
  });

  // Rate limiting
  await fastify.register(rateLimit, {
    max: 100,
    timeWindow: '1 minute',
    skipOnError: true,
  });

  // API Documentation
  await fastify.register(swagger, {
    swagger: {
      info: {
        title: 'ThreadArt API',
        description: 'String art generation and project management API',
        version: '1.0.0',
      },
      host: 'localhost:3000',
      schemes: ['http', 'https'],
      consumes: ['application/json'],
      produces: ['application/json'],
      tags: [
        { name: 'Health', description: 'Health check endpoints' },
        { name: 'Authentication', description: 'User authentication endpoints' },
        { name: 'Projects', description: 'Project management endpoints' },
        { name: 'Images', description: 'Image upload and processing endpoints' },
      ],
      securityDefinitions: {
        Bearer: {
          type: 'apiKey',
          name: 'Authorization',
          in: 'header',
        },
      },
    },
  });

  await fastify.register(swaggerUi, {
    routePrefix: '/docs',
    uiConfig: {
      docExpansion: 'full',
      deepLinking: false,
    },
    staticCSP: true,
    transformStaticCSP: (header) => header,
  });

  // Register routes
  await fastify.register(healthRoutes, { prefix: '' });
  await fastify.register(authRoutes, { prefix: '/api/auth' });
  await fastify.register(projectRoutes, { prefix: '/api/projects' });

  // Global error handler
  fastify.setErrorHandler((error, request, reply) => {
    const { statusCode = 500, message } = error;
    
    logger.error({
      error: {
        message: error.message,
        stack: error.stack,
        statusCode,
      },
      request: {
        method: request.method,
        url: request.url,
        headers: request.headers,
      },
    }, 'Request error');

    reply.status(statusCode).send({
      error: {
        message: statusCode >= 500 ? 'Internal Server Error' : message,
        statusCode,
        timestamp: new Date().toISOString(),
      },
    });
  });

  // 404 handler
  fastify.setNotFoundHandler((request, reply) => {
    reply.status(404).send({
      error: {
        message: 'Route not found',
        statusCode: 404,
        timestamp: new Date().toISOString(),
      },
    });
  });

  return fastify;
}