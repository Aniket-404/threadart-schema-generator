import fp from 'fastify-plugin';
import { prisma } from '../utils/database';

declare module 'fastify' {
  interface FastifyInstance {
    prisma: typeof prisma;
  }
}

export default fp(async function (fastify) {
  // Add Prisma to Fastify instance
  fastify.decorate('prisma', prisma);

  // Test database connection on startup (non-blocking for development)
  try {
    await prisma.$connect();
    console.log('✅ Database connected successfully');
  } catch (error) {
    console.warn('⚠️ Database connection failed (development mode):', error);
    // Don't throw in development - allow server to start for testing
    if (process.env.NODE_ENV === 'production') {
      throw error;
    }
  }

  // Add database health check
  fastify.addHook('onReady', async function () {
    try {
      await prisma.$queryRaw`SELECT 1`;
      console.log('✅ Database health check passed');
    } catch (error) {
      console.error('❌ Database health check failed:', error);
    }
  });

  // Graceful shutdown
  fastify.addHook('onClose', async function () {
    await prisma.$disconnect();
    console.log('📊 Database disconnected');
  });
});