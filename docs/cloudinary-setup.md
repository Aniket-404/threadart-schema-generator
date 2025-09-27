# Cloudinary Integration Guide

This document provides setup instructions for integrating Cloudinary image management with the ThreadArt Generator application.

## Overview

Cloudinary provides cloud-based image and video management services including:
- Image upload and storage
- On-the-fly image transformations
- Global CDN delivery
- API-based management

## Setup Instructions

### 1. Create Cloudinary Account

1. Visit [https://cloudinary.com](https://cloudinary.com)
2. Sign up for a free account (includes generous free tier)
3. Navigate to your Dashboard to find your credentials

### 2. Configure Environment Variables

Add these variables to your `.env` file:

```bash
# Cloudinary Configuration
CLOUDINARY_CLOUD_NAME=your_cloud_name_here
CLOUDINARY_API_KEY=your_api_key_here
CLOUDINARY_API_SECRET=your_api_secret_here
```

**Where to find these values:**
- **Cloud Name**: Found in your Cloudinary dashboard URL and account details
- **API Key**: Available in your Cloudinary console under "Account Details"
- **API Secret**: Found next to the API Key (keep this secure!)

### 3. Environment Configuration

The docker-compose.yml already includes Cloudinary environment variables in the app service:

```yaml
app:
  environment:
    CLOUDINARY_CLOUD_NAME: ${CLOUDINARY_CLOUD_NAME}
    CLOUDINARY_API_KEY: ${CLOUDINARY_API_KEY}
    CLOUDINARY_API_SECRET: ${CLOUDINARY_API_SECRET}
```

### 4. Cloudinary Features for ThreadArt

**Image Upload Workflow:**
1. User uploads image via web interface
2. Frontend sends image to ThreadArt API
3. API uploads to Cloudinary with transformations
4. Cloudinary returns optimized URLs
5. URLs stored in PostgreSQL database

**Transformations Used:**
- **Auto-optimize**: `f_auto,q_auto`
- **Size constraints**: `w_512,h_512,c_limit`
- **Format conversion**: Automatic WebP/AVIF for modern browsers
- **Progressive loading**: `fl_progressive`

**Folder Structure:**
```
threadart/
├── uploads/           # Original user uploads
├── processed/         # String art results
├── thumbnails/        # Preview images
└── temp/             # Temporary processing files
```

## Integration Examples

### Upload Configuration
```javascript
// Cloudinary upload preset configuration
{
  folder: "threadart/uploads",
  transformation: [
    { width: 512, height: 512, crop: "limit" },
    { quality: "auto:good" },
    { format: "auto" }
  ],
  allowed_formats: ["jpg", "jpeg", "png", "webp"]
}
```

### API Integration
```javascript
// Example Node.js integration
const cloudinary = require('cloudinary').v2;

cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET
});
```

## Security Best Practices

1. **Never expose API Secret**: Only use in server-side code
2. **Use signed uploads**: For production file uploads
3. **Implement upload policies**: Size limits, format restrictions
4. **Enable webhook notifications**: For upload status tracking
5. **Use folder permissions**: Restrict access to specific folders

## Testing Integration

### Health Check Endpoint
Create a health check to verify Cloudinary connectivity:

```bash
# Test Cloudinary connection
curl -X GET "https://api.cloudinary.com/v1_1/{cloud_name}/ping"
```

### Upload Test
```bash
# Test upload via API (replace with your credentials)
curl -X POST "https://api.cloudinary.com/v1_1/{cloud_name}/image/upload" \
  -F "file=@test-image.jpg" \
  -F "api_key={api_key}" \
  -F "signature={signature}" \
  -F "timestamp={timestamp}"
```

## Monitoring & Analytics

Cloudinary provides built-in analytics for:
- Upload volume and storage usage
- Transformation requests
- CDN performance metrics
- API usage and limits

Access these through your Cloudinary dashboard under "Reports & Analytics".

## Troubleshooting

### Common Issues

1. **"Invalid API credentials"**
   - Verify API key and secret in .env file
   - Check for extra spaces or quotes

2. **"Upload failed"**
   - Check file size limits (10MB default in nginx)
   - Verify allowed file formats
   - Check network connectivity

3. **"Transformation failed"**
   - Verify transformation syntax
   - Check if account has transformation limits

### Debug Mode
Enable Cloudinary debug logging:
```javascript
cloudinary.config({ 
  secure: true,
  api_debug: true  // Enable for troubleshooting
});
```

## Free Tier Limits

Cloudinary free tier includes:
- **25 GB** managed storage
- **25 GB** monthly bandwidth
- **25,000** transformations per month
- **1,000** images per month

Perfect for development and small-scale deployments.

## Production Considerations

1. **CDN Configuration**: Ensure global CDN is enabled
2. **Backup Strategy**: Implement periodic backup of critical images
3. **Monitoring**: Set up alerts for quota usage
4. **Performance**: Use lazy loading and responsive images
5. **SEO**: Implement proper image optimization and alt tags