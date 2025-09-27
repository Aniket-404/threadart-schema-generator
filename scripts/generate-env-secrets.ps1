# ThreadArt Environment Variable Generator
# Run this script in PowerShell to generate all required secrets

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "ThreadArt Environment Variable Generator" -ForegroundColor Cyan  
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Add required assembly for password generation
Add-Type -AssemblyName System.Web

# Generate all required secrets
Write-Host "🔐 Generating secure secrets..." -ForegroundColor Yellow
Write-Host ""

$postgresPassword = [System.Web.Security.Membership]::GeneratePassword(32, 8)
$redisPassword = [System.Web.Security.Membership]::GeneratePassword(32, 8)  
$jwtSecret = [System.Web.Security.Membership]::GeneratePassword(64, 16)
$grafanaPassword = [System.Web.Security.Membership]::GeneratePassword(16, 4)

# Display generated values
Write-Host "📋 Copy these values to your .env.production file:" -ForegroundColor Green
Write-Host ""
Write-Host "# Database Passwords" -ForegroundColor Gray
Write-Host "POSTGRES_PASSWORD=$postgresPassword" -ForegroundColor White
Write-Host "REDIS_PASSWORD=$redisPassword" -ForegroundColor White
Write-Host ""
Write-Host "# Application Security" -ForegroundColor Gray  
Write-Host "JWT_SECRET=$jwtSecret" -ForegroundColor White
Write-Host ""
Write-Host "# Monitoring" -ForegroundColor Gray
Write-Host "GRAFANA_ADMIN_PASSWORD=$grafanaPassword" -ForegroundColor White
Write-Host ""
Write-Host "☁️  Cloudinary Configuration (Manual Setup Required):" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Go to: https://cloudinary.com" -ForegroundColor Cyan
Write-Host "2. Sign up for a free account" -ForegroundColor Cyan
Write-Host "3. Copy values from your dashboard:" -ForegroundColor Cyan
Write-Host ""
Write-Host "CLOUDINARY_CLOUD_NAME=your_cloud_name_here" -ForegroundColor Magenta
Write-Host "CLOUDINARY_API_KEY=your_15_digit_api_key" -ForegroundColor Magenta  
Write-Host "CLOUDINARY_API_SECRET=your_27_char_api_secret" -ForegroundColor Magenta
Write-Host ""
Write-Host "✅ Next Steps:" -ForegroundColor Green
Write-Host "1. Copy the generated values above to .env.production" -ForegroundColor White
Write-Host "2. Set up Cloudinary account and add those credentials" -ForegroundColor White
Write-Host "3. Run: docker-compose up -d" -ForegroundColor White
Write-Host "4. Verify: .\scripts\validate-infrastructure.bat" -ForegroundColor White
Write-Host ""
Write-Host "🔒 Security Note: Keep these secrets private and never commit them to git!" -ForegroundColor Red