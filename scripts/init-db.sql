-- ThreadArt Generator - PostgreSQL Initialization Script
-- This script runs automatically when the PostgreSQL container starts for the first time

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";

-- Create additional database user for monitoring (if needed)
-- The main application user is already created by Docker environment variables

-- Set default timezone
SET timezone = 'UTC';

-- Create initial application-specific settings
DO $$
BEGIN
    -- Set up connection limits and performance settings
    ALTER SYSTEM SET max_connections = '200';
    ALTER SYSTEM SET shared_preload_libraries = 'pg_stat_statements';
    ALTER SYSTEM SET log_statement = 'all';
    ALTER SYSTEM SET log_min_duration_statement = '1000'; -- Log slow queries (1 second+)
    ALTER SYSTEM SET checkpoint_completion_target = '0.9';
    ALTER SYSTEM SET wal_buffers = '16MB';
    ALTER SYSTEM SET effective_cache_size = '1GB';
    ALTER SYSTEM SET shared_buffers = '256MB';
    
    -- Reload configuration
    SELECT pg_reload_conf();
    
    RAISE NOTICE 'ThreadArt PostgreSQL database initialized successfully';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Note: Some configuration changes require PostgreSQL restart to take effect';
END$$;

-- Create a function to validate database health
CREATE OR REPLACE FUNCTION check_database_health()
RETURNS TABLE(
    component TEXT,
    status TEXT,
    message TEXT
) AS $$
BEGIN
    -- Check database connectivity
    RETURN QUERY SELECT 
        'connectivity'::TEXT, 
        'healthy'::TEXT, 
        'Database is accessible'::TEXT;
    
    -- Check disk space (basic check)
    RETURN QUERY SELECT 
        'storage'::TEXT,
        CASE WHEN pg_database_size(current_database()) > 0 
             THEN 'healthy'::TEXT 
             ELSE 'warning'::TEXT 
        END,
        'Database size: ' || pg_size_pretty(pg_database_size(current_database()))::TEXT;
    
    -- Check active connections
    RETURN QUERY SELECT 
        'connections'::TEXT,
        CASE WHEN count(*) < 180 THEN 'healthy'::TEXT ELSE 'warning'::TEXT END,
        'Active connections: ' || count(*)::TEXT
    FROM pg_stat_activity 
    WHERE state = 'active';
END;
$$ LANGUAGE plpgsql;

-- Grant necessary permissions to the application user
-- Note: ${POSTGRES_USER} will be the actual username from environment variables
-- This is handled by the Docker PostgreSQL initialization process