@echo off
REM ThreadArt Infrastructure Validation Script (Windows)
REM Comprehensive service orchestration and connectivity testing

echo ==========================================
echo ThreadArt Infrastructure Validation
echo ==========================================
echo Started at: %date% %time%
echo.

REM Configuration
set TIMEOUT=30
set failed_tests=0

REM Check Docker availability
echo [INFO] Checking Docker daemon...
docker info >nul 2>&1
if errorlevel 1 (
    echo [FAIL] Docker is not running or not accessible
    exit /b 1
) else (
    echo [PASS] Docker daemon is accessible
)

REM Validate docker-compose configuration
echo [INFO] Validating Docker Compose configuration...
docker-compose config --quiet >nul 2>&1
if errorlevel 1 (
    echo [FAIL] Docker Compose configuration has errors
    exit /b 1
) else (
    echo [PASS] Docker Compose configuration is valid
)

echo.
echo [INFO] Checking container status...

REM Check required containers
set containers=threadart-postgres threadart-redis threadart-nginx threadart-prometheus threadart-grafana threadart-loki

for %%c in (%containers%) do (
    docker ps --filter "name=%%c" --format "{{.Names}}" | findstr %%c >nul
    if errorlevel 1 (
        echo [WARN] %%c is not running
        set /a failed_tests+=1
    ) else (
        echo [PASS] %%c is running
    )
)

echo.
echo [INFO] Testing service connectivity...

REM Test PostgreSQL
echo [INFO] Testing PostgreSQL connectivity...
docker exec threadart-postgres pg_isready -U threadart_user -d threadart_db >nul 2>&1
if errorlevel 1 (
    echo [FAIL] PostgreSQL is not accepting connections
    set /a failed_tests+=1
) else (
    echo [PASS] PostgreSQL is accepting connections
    
    REM Test database operations
    docker exec threadart-postgres psql -U threadart_user -d threadart_db -c "SELECT 1;" >nul 2>&1
    if errorlevel 1 (
        echo [FAIL] PostgreSQL database operations failed
        set /a failed_tests+=1
    ) else (
        echo [PASS] PostgreSQL database operations working
    )
)

REM Test Redis
echo [INFO] Testing Redis connectivity...
docker exec threadart-redis redis-cli -a "%REDIS_PASSWORD%" ping 2>nul | findstr PONG >nul
if errorlevel 1 (
    echo [FAIL] Redis is not responding
    set /a failed_tests+=1
) else (
    echo [PASS] Redis is responding to ping
    
    REM Test Redis operations
    docker exec threadart-redis redis-cli -a "%REDIS_PASSWORD%" set test_key "test_value" >nul 2>&1
    docker exec threadart-redis redis-cli -a "%REDIS_PASSWORD%" get test_key 2>nul | findstr test_value >nul
    if errorlevel 1 (
        echo [FAIL] Redis operations failed
        set /a failed_tests+=1
    ) else (
        echo [PASS] Redis operations working
        docker exec threadart-redis redis-cli -a "%REDIS_PASSWORD%" del test_key >nul 2>&1
    )
)

REM Test Prometheus
echo [INFO] Testing Prometheus...
curl -s -o nul -w "%%{http_code}" --connect-timeout 10 --max-time 30 "http://localhost:9090/-/healthy" | findstr 200 >nul
if errorlevel 1 (
    echo [WARN] Prometheus health check failed
    set /a failed_tests+=1
) else (
    echo [PASS] Prometheus is healthy
)

REM Test Grafana
echo [INFO] Testing Grafana...
curl -s -o nul -w "%%{http_code}" --connect-timeout 10 --max-time 30 "http://localhost:3001/api/health" | findstr 200 >nul
if errorlevel 1 (
    echo [WARN] Grafana may not be ready (this is often normal during startup)
) else (
    echo [PASS] Grafana is operational
)

REM Test Loki
echo [INFO] Testing Loki...
curl -s -o nul -w "%%{http_code}" --connect-timeout 10 --max-time 30 "http://localhost:3100/ready" | findstr 200 >nul
if errorlevel 1 (
    echo [WARN] Loki may not be ready
) else (
    echo [PASS] Loki is ready for log ingestion
)

REM Test Nginx
echo [INFO] Testing Nginx reverse proxy...
curl -s -o nul -w "%%{http_code}" --connect-timeout 10 --max-time 30 "http://localhost/health" | findstr 200 >nul
if errorlevel 1 (
    echo [WARN] Nginx health endpoint not available (may need app running)
) else (
    echo [PASS] Nginx is serving requests
)

REM Test inter-service connectivity (simplified)
echo [INFO] Testing inter-service connectivity...
docker exec threadart-app ping -c 1 postgres >nul 2>&1
if errorlevel 1 (
    echo [WARN] App may not be able to reach PostgreSQL
) else (
    echo [PASS] App can reach PostgreSQL
)

docker exec threadart-app ping -c 1 redis >nul 2>&1
if errorlevel 1 (
    echo [WARN] App may not be able to reach Redis
) else (
    echo [PASS] App can reach Redis
)

REM Test backup system
echo [INFO] Testing backup system integration...
if exist "scripts\backup\validate-backup-system.bat" (
    echo [PASS] Backup validation script exists
) else (
    echo [WARN] Backup validation script not found
)

REM Summary
echo.
echo ==========================================
echo Validation Summary
echo ==========================================
echo Failed tests: %failed_tests%

if %failed_tests% equ 0 (
    echo [PASS] All critical infrastructure tests passed!
    echo Infrastructure is ready for application deployment.
) else if %failed_tests% leq 3 (
    echo [WARN] Some non-critical tests failed, but infrastructure is mostly operational
    echo Review warnings and fix non-critical issues when possible.
) else (
    echo [FAIL] Multiple critical tests failed
    echo Infrastructure needs attention before application deployment.
    exit /b 1
)

echo ==========================================
echo.
echo To start all services: docker-compose up -d
echo To view logs: docker-compose logs -f
echo To stop services: docker-compose down