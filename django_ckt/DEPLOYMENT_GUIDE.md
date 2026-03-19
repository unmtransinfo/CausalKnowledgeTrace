# Django CKT Production Deployment Guide

## Problem Summary

The Django CKT application works correctly when accessed via direct IP (`http://206.192.180.170:3838`) but fails when accessed via the DNS URL (`https://habanero.health.unm.edu/CKT/`) due to:

1. **Static files not loading** - CSS/JS files return 404 errors
2. **URL routing issues** - Internal navigation links fail
3. **Missing reverse proxy configuration** - Django not configured for subpath deployment

## Solution Overview

The application has been updated to support subpath deployment under `/CKT/` with proper reverse proxy configuration.

## Required Changes

### 1. Django Application Configuration (COMPLETED)

The following changes have been made to the Django application:

- ✅ Added `FORCE_SCRIPT_NAME` support for subpath deployment
- ✅ Updated `STATIC_URL` and `MEDIA_URL` to include subpath
- ✅ Added reverse proxy headers support (`USE_X_FORWARDED_HOST`, `USE_X_FORWARDED_PORT`)
- ✅ Updated `ALLOWED_HOSTS` and `CSRF_TRUSTED_ORIGINS` for production
- ✅ Created production environment configuration

### 2. System Administrator Tasks (REQUIRED)

#### A. Web Server/Reverse Proxy Configuration

The web server (Apache/Nginx) needs to be configured to:

1. **Proxy requests** from `https://habanero.health.unm.edu/CKT/` to `http://206.192.180.170:3838/CKT/`
2. **Set proper headers** for Django to understand the original request
3. **Handle static files** correctly

#### B. Apache Configuration Example

```apache
<VirtualHost *:443>
    ServerName habanero.health.unm.edu
    
    # SSL Configuration
    SSLEngine on
    SSLCertificateFile /path/to/certificate.crt
    SSLCertificateKeyFile /path/to/private.key
    
    # Proxy configuration for CKT application
    ProxyPreserveHost On
    ProxyPass /CKT/ http://206.192.180.170:3838/CKT/
    ProxyPassReverse /CKT/ http://206.192.180.170:3838/CKT/
    
    # Set headers for Django
    ProxyPassReverse /CKT/ http://206.192.180.170:3838/CKT/
    ProxyPassReverseRewrite /CKT/ http://206.192.180.170:3838/CKT/
    
    # Forward original protocol and host
    RequestHeader set X-Forwarded-Proto "https"
    RequestHeader set X-Forwarded-Host "habanero.health.unm.edu"
    RequestHeader set X-Forwarded-Port "443"
</VirtualHost>
```

#### C. Nginx Configuration Example

```nginx
server {
    listen 443 ssl;
    server_name habanero.health.unm.edu;
    
    # SSL Configuration
    ssl_certificate /path/to/certificate.crt;
    ssl_certificate_key /path/to/private.key;
    
    location /CKT/ {
        proxy_pass http://206.192.180.170:3838/CKT/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port $server_port;
        
        # Handle WebSocket connections if needed
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

### 3. DNS Configuration

Ensure that `habanero.health.unm.edu` resolves to the correct IP address where the reverse proxy is running.

## Deployment Steps

### For the Application Owner (Non-root user)

1. **Update environment configuration:**
   ```bash
   cd /home/rajeshupadhayaya/CausalKnowledgeTrace/django_ckt
   cp .env.production .env
   # Edit .env and set DJANGO_SECRET_KEY
   ```

2. **Deploy the application:**
   ```bash
   ./deploy_production.sh
   ```

### For the System Administrator (Root access required)

1. **Configure the reverse proxy** (Apache/Nginx) using the examples above
2. **Ensure SSL certificates** are properly configured
3. **Restart the web server** after configuration changes
4. **Verify DNS resolution** for habanero.health.unm.edu

## Testing the Deployment

After deployment, test the following URLs:

- ✅ `https://habanero.health.unm.edu/CKT/` - Home page should load with CSS
- ✅ `https://habanero.health.unm.edu/CKT/visualization/` - Visualization page
- ✅ `https://habanero.health.unm.edu/CKT/analysis/` - Analysis page
- ✅ `https://habanero.health.unm.edu/CKT/static/css/main.css` - Static files should load

## Troubleshooting

### Static Files Not Loading
- Check that `FORCE_SCRIPT_NAME=/CKT` is set in `.env`
- Verify reverse proxy is forwarding `/CKT/static/` requests correctly
- Run `python manage.py collectstatic --noinput` to ensure static files are collected

### URL Routing Issues
- Verify `USE_X_FORWARDED_HOST=True` is set in `.env`
- Check that reverse proxy is setting `X-Forwarded-Host` header correctly

### CSRF Errors
- Ensure `CSRF_TRUSTED_ORIGINS` includes `https://habanero.health.unm.edu`
- Verify reverse proxy is setting `X-Forwarded-Proto` header to `https`

## Environment Variables Reference

Key environment variables for production deployment:

```bash
ENVIRONMENT=production
FORCE_SCRIPT_NAME=/CKT
USE_X_FORWARDED_HOST=True
USE_X_FORWARDED_PORT=True
DJANGO_ALLOWED_HOSTS=habanero.health.unm.edu,206.192.180.170
CSRF_TRUSTED_ORIGINS=https://habanero.health.unm.edu
```

## Quick Fix Commands

If you need to quickly test the fixes:

1. **Set environment variables and restart:**
   ```bash
   cd /home/rajeshupadhayaya/CausalKnowledgeTrace/django_ckt
   export ENVIRONMENT=production
   export FORCE_SCRIPT_NAME=/CKT
   export USE_X_FORWARDED_HOST=True
   export DJANGO_ALLOWED_HOSTS=habanero.health.unm.edu,206.192.180.170
   export CSRF_TRUSTED_ORIGINS=https://habanero.health.unm.edu
   python manage.py collectstatic --noinput
   ./run_django.sh
   ```

2. **Or use the production deployment script:**
   ```bash
   ./deploy_production.sh
   ```

## What the System Administrator Needs to Do

**CRITICAL**: The main issue is that the reverse proxy is not configured correctly. The system administrator needs to:

1. **Configure Apache/Nginx** to proxy `https://habanero.health.unm.edu/CKT/` to `http://206.192.180.170:3838/CKT/`
2. **Set proper headers** (`X-Forwarded-Host`, `X-Forwarded-Proto`, etc.)
3. **Ensure SSL termination** is handled correctly
4. **Restart the web server** after configuration changes

Without these changes, the application will continue to have issues with static files and URL routing when accessed via the DNS URL.
