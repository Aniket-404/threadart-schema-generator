# SSL/TLS Configuration

This directory contains SSL certificates and configuration for the ThreadArt Generator application.

## Directory Structure

```
ssl/
├── README.md                 # This file
├── generate-self-signed.sh   # Self-signed certificate generator
└── certs/                    # Certificate storage (git-ignored)
    ├── fullchain.pem         # Full certificate chain
    ├── privkey.pem          # Private key
    └── chain.pem            # Intermediate certificates
```

## SSL Certificate Options

### Option 1: Self-Signed Certificates (Development)

For local development and testing:

```bash
chmod +x ssl/generate-self-signed.sh
./ssl/generate-self-signed.sh
```

This creates certificates for `localhost` and `threadart.local`.

### Option 2: Let's Encrypt (Production)

For production deployments with a real domain:

1. Ensure your domain points to your server
2. Update `SSL_DOMAIN` in your `.env` file
3. Use the certbot service in docker-compose:

```bash
# Initial certificate generation
docker-compose run --rm certbot certonly --webroot -w /var/www/certbot -d your-domain.com

# Auto-renewal (add to crontab)
0 12 * * * docker-compose run --rm certbot renew --quiet && docker-compose exec nginx nginx -s reload
```

### Option 3: Custom Certificates

If you have your own certificates:

1. Copy your certificates to `ssl/certs/`:
   - `fullchain.pem` - Full certificate chain
   - `privkey.pem` - Private key
   - `chain.pem` - Intermediate certificates

2. Ensure proper permissions:
   ```bash
   chmod 600 ssl/certs/privkey.pem
   chmod 644 ssl/certs/fullchain.pem ssl/certs/chain.pem
   ```

## Environment Variables

Set these in your `.env` file:

```env
# SSL Configuration
SSL_DOMAIN=your-domain.com
SSL_EMAIL=admin@your-domain.com  # For Let's Encrypt notifications
```

## Security Notes

- Private keys are git-ignored for security
- Self-signed certificates will show browser warnings
- Let's Encrypt certificates auto-renew every 90 days
- All certificates should use 2048-bit or stronger keys
- TLS 1.2+ only, no weak ciphers allowed

## Troubleshooting

### Certificate Not Found
If Nginx fails to start with certificate errors:
1. Check that certificate files exist in `ssl/certs/`
2. Verify file permissions
3. Check certificate validity: `openssl x509 -in ssl/certs/fullchain.pem -text -noout`

### Let's Encrypt Rate Limits
- 20 certificates per registered domain per week
- 5 duplicate certificates per week
- Use staging environment for testing: `--staging` flag

### Browser Security Warnings
For self-signed certificates:
1. Click "Advanced" in browser
2. Select "Proceed to localhost (unsafe)"
3. Or add certificate to browser's trusted store