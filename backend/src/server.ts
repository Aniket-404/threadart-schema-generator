import Fastify from 'fastify';
import { config } from 'dotenv';
import path from 'path';

// Load environment variables
config({ path: path.join(__dirname, '../../.env') });

import { buildApp } from './app';
import { logger } from './utils/logger';

const start = async () => {
  const fastify = Fastify({
    logger: {
      level: process.env.LOG_LEVEL || 'info',
      transport: process.env.NODE_ENV !== 'production' ? {
        target: 'pino-pretty',
        options: {
          colorize: true,
          translateTime: 'HH:MM:ss Z',
          ignore: 'pid,hostname'
        }
      } : undefined
    },
    trustProxy: true,
  });

  try {
    // Build the application with all plugins and routes
    await buildApp(fastify);

    // Get configuration from environment
    const host = process.env.HOST || '0.0.0.0';
    const port = parseInt(process.env.PORT || '3000', 10);

    // Start the server
    await fastify.listen({ port, host });
    
    fastify.log.info(`🚀 ThreadArt API Server ready at http://${host}:${port}`);
    fastify.log.info(`📖 API Documentation available at http://${host}:${port}/docs`);
    fastify.log.info(`🏥 Health check endpoint at http://${host}:${port}/health`);

  } catch (err) {
    fastify.log.error(err);
    process.exit(1);
  }
};

// Handle graceful shutdown
const signals = ['SIGINT', 'SIGTERM'];
signals.forEach((signal) => {
  process.on(signal, async () => {
    logger.info(`Received ${signal}, shutting down gracefully...`);
    process.exit(0);
  });
});

// Handle uncaught exceptions and rejections
process.on('uncaughtException', (err) => {
  logger.error({ err }, 'Uncaught exception');
  process.exit(1);
});

process.on('unhandledRejection', (err) => {
  logger.error({ err }, 'Unhandled rejection');
  process.exit(1);
});

// Start the server
start().catch((err) => {
  logger.error({ err }, 'Failed to start server');
  process.exit(1);
});