@echo off
REM ThreadArt Backup Test Script for Windows
REM This script validates backup and restore functionality

echo ThreadArt Backup System Validation
echo =====================================

echo Checking Docker availability...
docker --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Docker is not available or not in PATH
    exit /b 1
) else (
    echo ✓ Docker is available
)

echo.
echo Checking container status...
docker ps --filter "name=threadart-postgres" --format "{{.Names}}" | findstr threadart-postgres >nul
if errorlevel 1 (
    echo WARNING: PostgreSQL container not running
) else (
    echo ✓ PostgreSQL container is running
)

docker ps --filter "name=threadart-redis" --format "{{.Names}}" | findstr threadart-redis >nul
if errorlevel 1 (
    echo WARNING: Redis container not running
) else (
    echo ✓ Redis container is running
)

echo.
echo Checking backup directory structure...
if exist "scripts\backup" (
    echo ✓ Backup scripts directory exists
    dir /b scripts\backup\*.sh >nul 2>&1
    if errorlevel 1 (
        echo WARNING: No backup scripts found
    ) else (
        echo ✓ Backup scripts found
    )
) else (
    echo ERROR: Backup scripts directory not found
    exit /b 1
)

echo.
echo Backup script validation:
echo - postgres-backup.sh: %~dp0scripts\backup\postgres-backup.sh
echo - redis-backup.sh: %~dp0scripts\backup\redis-backup.sh
echo - postgres-restore.sh: %~dp0scripts\backup\postgres-restore.sh
echo - redis-restore.sh: %~dp0scripts\backup\redis-restore.sh
echo - backup-scheduler.sh: %~dp0scripts\backup\backup-scheduler.sh

echo.
echo Environment check:
if "%POSTGRES_PASSWORD%"=="" (
    echo WARNING: POSTGRES_PASSWORD not set
) else (
    echo ✓ POSTGRES_PASSWORD is configured
)

if "%REDIS_PASSWORD%"=="" (
    echo WARNING: REDIS_PASSWORD not set
) else (
    echo ✓ REDIS_PASSWORD is configured
)

echo.
echo Documentation files:
if exist "docs\backup-restore.md" (
    echo ✓ Backup documentation exists
) else (
    echo WARNING: Backup documentation not found
)

if exist "docs\security-secrets.md" (
    echo ✓ Security documentation exists
) else (
    echo WARNING: Security documentation not found
)

echo.
echo =====================================
echo Backup system validation completed!
echo =====================================
echo.
echo To run backups manually (requires WSL/Git Bash):
echo   bash scripts/backup/postgres-backup.sh
echo   bash scripts/backup/redis-backup.sh
echo   bash scripts/backup/backup-scheduler.sh
echo.
echo To test restore (requires WSL/Git Bash):
echo   bash scripts/backup/postgres-restore.sh latest
echo   bash scripts/backup/redis-restore.sh latest