import { FastifyInstance, FastifyPluginAsync } from 'fastify';

const projectRoutes: FastifyPluginAsync = async (fastify: FastifyInstance) => {
  // Placeholder for project CRUD routes
  // Will be implemented in Task 12.5
  
  fastify.get('/status', async () => {
    return { message: 'Project routes ready for implementation' };
  });
};

export { projectRoutes };