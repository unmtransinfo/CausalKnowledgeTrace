"""
Django settings for CausalKnowledgeTrace project.
"""

import os
from pathlib import Path

# Build paths inside the project like this: BASE_DIR / 'subdir'.
BASE_DIR = Path(__file__).resolve().parent.parent

# SECURITY WARNING: keep the secret key used in production secret!
SECRET_KEY = os.environ.get('DJANGO_SECRET_KEY', 'django-insecure-dev-key-change-in-production')

# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = os.environ.get('ENVIRONMENT', 'development') == 'development'

ALLOWED_HOSTS = ['*']  # Configure appropriately for production

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

# Database - SQLite for development (no PostgreSQL needed)
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': BASE_DIR / 'db.sqlite3',
    }
}

# Uncomment below to use PostgreSQL when ready
# DATABASES = {
#     'default': {
#         'ENGINE': 'django.db.backends.postgresql',
#         'NAME': os.environ.get('DB_NAME', 'causalehr'),
#         'USER': os.environ.get('DB_USER', 'rajesh'),
#         'PASSWORD': os.environ.get('DB_PASSWORD', 'Software292'),
#         'HOST': os.environ.get('DB_HOST', 'localhost'),
#         'PORT': os.environ.get('DB_PORT', '5433'),
#     }
# }

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

# Application port configuration
APP_PORT = int(os.environ.get('APP_PORT', '3838'))

# R modules path
R_MODULES_PATH = BASE_DIR / 'r_modules'

# File upload settings
FILE_UPLOAD_MAX_MEMORY_SIZE = 104857600  # 100 MB
DATA_UPLOAD_MAX_MEMORY_SIZE = 104857600  # 100 MB

# Session configuration
SESSION_ENGINE = 'django.contrib.sessions.backends.db'
SESSION_COOKIE_AGE = 86400  # 24 hours

# Logging configuration
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
        'file': {
            'level': 'INFO',
            'class': 'logging.FileHandler',
            'filename': BASE_DIR.parent / 'logs' / 'django_app.log',
            'formatter': 'verbose',
        },
        'console': {
            'level': 'INFO',
            'class': 'logging.StreamHandler',
            'formatter': 'verbose',
        },
    },
    'root': {
        'handlers': ['console', 'file'],
        'level': 'INFO',
    },
}

