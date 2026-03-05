"""
Django settings for CausalKnowledgeTrace project.

Environment-aware configuration:
  - ENVIRONMENT=development  → DEBUG=True,  relaxed security
  - ENVIRONMENT=production   → DEBUG=False, hardened security
"""

import os
from pathlib import Path
from dotenv import load_dotenv

# Build paths inside the project like this: BASE_DIR / 'subdir'.
BASE_DIR = Path(__file__).resolve().parent.parent

# Load .env file from the django_ckt directory, overriding any existing shell env vars.
# In Docker the env vars come from env_file / environment in docker-compose,
# so this is mainly useful for local (non-Docker) development.
load_dotenv(BASE_DIR / '.env', override=True)

# Detect environment once — used throughout this file
ENVIRONMENT = os.environ.get('ENVIRONMENT', 'development')
IS_PRODUCTION = ENVIRONMENT == 'production'

# ---------------------------------------------------------------------------
# Security — SECRET_KEY
# ---------------------------------------------------------------------------
# In production the key MUST be set via DJANGO_SECRET_KEY env var.
# The insecure fallback only works when ENVIRONMENT != production.
SECRET_KEY = os.environ.get('DJANGO_SECRET_KEY', '')
if not SECRET_KEY:
    if IS_PRODUCTION:
        raise ValueError(
            "DJANGO_SECRET_KEY environment variable is required in production. "
            "Generate one with: python -c \"from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())\""
        )
    SECRET_KEY = 'django-insecure-dev-key-change-in-production'

# ---------------------------------------------------------------------------
# Debug
# ---------------------------------------------------------------------------
DEBUG = not IS_PRODUCTION

# ---------------------------------------------------------------------------
# Allowed Hosts
# ---------------------------------------------------------------------------
# Parsed from a comma-separated env var.  Falls back to permissive defaults
# only in development; production MUST supply an explicit list.
_allowed = os.environ.get('DJANGO_ALLOWED_HOSTS', '')
if _allowed:
    ALLOWED_HOSTS = [h.strip() for h in _allowed.split(',') if h.strip()]
elif IS_PRODUCTION:
    ALLOWED_HOSTS = ['localhost', '127.0.0.1']
else:
    ALLOWED_HOSTS = ['*']  # permissive in dev only

# Application definition
INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    
    # Your apps (with apps. prefix)
    'apps.core',
    'apps.visualization',
    'apps.analysis',
    'apps.upload',
    'apps.graph_config',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'config.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [BASE_DIR / 'templates'],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'config.wsgi.application'
ASGI_APPLICATION = 'config.asgi.application'

# Database - PostgreSQL (Docker dev container)
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': os.environ.get('DB_NAME', 'causalehr'),
        'USER': os.environ.get('DB_USER', 'rajesh'),
        'PASSWORD': os.environ.get('DB_PASSWORD', 'Software292'),
        'HOST': os.environ.get('DB_HOST', 'localhost'),
        'PORT': os.environ.get('DB_PORT', '5433'),
    }
}

# Database table configuration (for existing schema)
DB_CONFIG = {
    'SENTENCE_SCHEMA': os.environ.get('DB_SENTENCE_SCHEMA', 'public'),
    'SENTENCE_TABLE': os.environ.get('DB_SENTENCE_TABLE', 'sentence'),
    'PREDICATION_SCHEMA': os.environ.get('DB_PREDICATION_SCHEMA', 'public'),
    'PREDICATION_TABLE': os.environ.get('DB_PREDICATION_TABLE', 'predication'),
    'SUBJECT_SEARCH_SCHEMA': os.environ.get('DB_SUBJECT_SEARCH_SCHEMA', 'filtered'),
    'SUBJECT_SEARCH_TABLE': os.environ.get('DB_SUBJECT_SEARCH_TABLE', 'subject_search'),
    'OBJECT_SEARCH_SCHEMA': os.environ.get('DB_OBJECT_SEARCH_SCHEMA', 'filtered'),
    'OBJECT_SEARCH_TABLE': os.environ.get('DB_OBJECT_SEARCH_TABLE', 'object_search'),
}

# Password validation
AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]

# Internationalization
LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_TZ = True

# Static files (CSS, JavaScript, Images)
STATIC_URL = '/static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'
STATICFILES_DIRS = [BASE_DIR / 'static']

# Media files (user uploads)
MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'media'

# Default primary key field type
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# Application port configuration (used by Gunicorn via DJANGO_PORT env var)
DJANGO_PORT = int(os.environ.get('DJANGO_PORT', '3838'))

# R modules path
R_MODULES_PATH = BASE_DIR / 'r_modules'

# File upload settings
FILE_UPLOAD_MAX_MEMORY_SIZE = 104857600  # 100 MB
DATA_UPLOAD_MAX_MEMORY_SIZE = 104857600  # 100 MB

# Session configuration
SESSION_ENGINE = 'django.contrib.sessions.backends.db'
SESSION_COOKIE_AGE = 86400  # 24 hours

# Logging configuration
# In Docker, logs go to stdout/stderr (captured by Docker logging driver).
# The file handler is kept for local/non-Docker runs.
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'verbose': {
            'format': '{levelname} {asctime} {module} {message}',
            'style': '{',
        },
    },
    'handlers': {
        'console': {
            'level': 'INFO',
            'class': 'logging.StreamHandler',
            'formatter': 'verbose',
        },
    },
    'root': {
        'handlers': ['console'],
        'level': 'INFO',
    },
}

# Try to add file handler — may fail in Docker if logs dir doesn't exist
_log_dir = BASE_DIR.parent / 'logs'
if _log_dir.exists():
    LOGGING['handlers']['file'] = {
        'level': 'INFO',
        'class': 'logging.FileHandler',
        'filename': _log_dir / 'django_app.log',
        'formatter': 'verbose',
    }
    LOGGING['root']['handlers'].append('file')

# ---------------------------------------------------------------------------
# Production Security Hardening
# ---------------------------------------------------------------------------
# These settings are only enabled when ENVIRONMENT=production.
# They protect against common web vulnerabilities (XSS, clickjacking,
# session hijacking, CSRF, etc.)
# ---------------------------------------------------------------------------
if IS_PRODUCTION:
    # CSRF — trusted origins for cross-site POST requests
    _csrf_origins = os.environ.get('CSRF_TRUSTED_ORIGINS', '')
    if _csrf_origins:
        CSRF_TRUSTED_ORIGINS = [o.strip() for o in _csrf_origins.split(',') if o.strip()]

    # Cookie security — mark cookies Secure so they're only sent over HTTPS.
    # Set to False if running behind a TLS-terminating proxy on plain HTTP internally.
    SESSION_COOKIE_SECURE = os.environ.get('SESSION_COOKIE_SECURE', 'True') == 'True'
    CSRF_COOKIE_SECURE = os.environ.get('CSRF_COOKIE_SECURE', 'True') == 'True'

    # HTTP Strict Transport Security — tell browsers to always use HTTPS
    # Only enable if the entire site is served over HTTPS
    SECURE_HSTS_SECONDS = int(os.environ.get('SECURE_HSTS_SECONDS', '0'))
    SECURE_HSTS_INCLUDE_SUBDOMAINS = SECURE_HSTS_SECONDS > 0
    SECURE_HSTS_PRELOAD = SECURE_HSTS_SECONDS > 0

    # Redirect HTTP → HTTPS (disable if TLS is terminated at load balancer)
    SECURE_SSL_REDIRECT = os.environ.get('SECURE_SSL_REDIRECT', 'False') == 'True'

    # Prevent the browser from MIME-sniffing the content type
    SECURE_CONTENT_TYPE_NOSNIFF = True

    # X-Frame-Options — prevent clickjacking
    X_FRAME_OPTIONS = 'DENY'

