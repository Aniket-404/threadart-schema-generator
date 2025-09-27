import { FastifyInstance, FastifyPluginAsync, FastifyRequest, FastifyReply } from 'fastify';

const healthRoutes: FastifyPluginAsync = async (fastify: FastifyInstance) => {
  // Health check endpoint
  fastify.get('/health', {
    schema: {
      description: 'Health check endpoint',
      tags: ['Health'],
      response: {
        200: {
          type: 'object',
          properties: {
            status: { type: 'string' },
            timestamp: { type: 'string' },
            uptime: { type: 'number' },
            version: { type: 'string' },
            services: {
              type: 'object',
              properties: {
                database: { type: 'string' },
                redis: { type: 'string' },
                cloudinary: { type: 'string' },
              },
            },
          },
        },
      },
    },
  }, async (request: FastifyRequest, reply: FastifyReply) => {
    const uptime = process.uptime();
    
    // TODO: Add actual service health checks
    const services = {
      database: 'connected', // Will implement with Prisma
      redis: 'connected',     // Will implement with Redis client
      cloudinary: 'connected' // Will implement with Cloudinary
    };

    return reply.send({
      status: 'healthy',
      timestamp: new Date().toISOString(),
      uptime,
      version: process.env.npm_package_version || '1.0.0',
      services,
    });
  });

  // Ready check endpoint (for Kubernetes/Docker health checks)
  fastify.get('/ready', {
    schema: {
      description: 'Readiness check endpoint',
      tags: ['Health'],
      response: {
        200: {
          type: 'object',
          properties: {
            status: { type: 'string' },
            timestamp: { type: 'string' },
          },
        },
      },
    },
  }, async (request: FastifyRequest, reply: FastifyReply) => {
    return reply.send({
      status: 'ready',
      timestamp: new Date().toISOString(),
    });
  });

  // Live check endpoint
  fastify.get('/live', {
    schema: {
      description: 'Liveness check endpoint',
      tags: ['Health'],
      response: {
        200: {
          type: 'object',
          properties: {
            status: { type: 'string' },
            timestamp: { type: 'string' },
          },
        },
      },
    },
  }, async (request: FastifyRequest, reply: FastifyReply) => {
    return reply.send({
      status: 'alive',
      timestamp: new Date().toISOString(),
    });
  });
};

export { healthRoutes };