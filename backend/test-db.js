const { PrismaClient } = require('@prisma/client');

async function testConnection() {
  const prisma = new PrismaClient({
    log: ['query', 'info', 'warn', 'error'],
  });

  try {
    console.log('Testing database connection...');
    console.log('DATABASE_URL:', process.env.DATABASE_URL);
    
    await prisma.$connect();
    console.log('✅ Database connected successfully');
    
    // Test a simple query
    const result = await prisma.$queryRaw`SELECT version()`;
    console.log('✅ Query successful:', result);
    
  } catch (error) {
    console.error('❌ Database connection failed:', error);
  } finally {
    await prisma.$disconnect();
  }
}

testConnection();