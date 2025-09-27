# Secure Configuration & Secrets Management

## Best Practices
- Use strong, randomly generated secrets for all services
- Store secrets in .env files, never hardcoded in code or docker-compose.yml
- Restrict .env file permissions (Windows: `icacls .env* /inheritance:r /grant:r "%USERNAME%:R"`; Linux: `chmod 600 .env*`)
- Add `.env*` to `.gitignore` to prevent accidental commits
- Rotate secrets regularly and document rotation procedures
- Validate secret injection by checking service logs and environment

## Secret Rotation Procedure
1. Generate new secrets using OpenSSL or PowerShell
2. Update .env files and restart affected services
3. Document changes and notify team
4. Test service connectivity and authentication

## Backup & Restore
- Backup .env files securely (encrypted storage)
- Restore only to trusted environments

## Onboarding Checklist
- Copy .env.example files and fill in secrets
- Verify permissions and environment variable usage
- Review documentation for troubleshooting
