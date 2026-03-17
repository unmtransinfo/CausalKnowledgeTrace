# Django CausalKnowledgeTrace - Quick Start Guide

## Prerequisites

Before you begin, ensure you have:

- **Python 3.11+** installed
- **R 4.5.1+** installed with required packages
- **PostgreSQL 16+** running with the causalehr database
- **Conda** (recommended) or virtualenv

## Quick Setup (5 minutes)

### Option 1: Automated Setup (Recommended)

```bash
cd django_ckt
./setup_django.sh
```

This script will:
1. Create .env file from template
2. Create Python virtual environment
3. Install all dependencies
4. Copy R modules from shiny_app
5. Run database migrations
6. Collect static files
7. Optionally create superuser

### Option 2: Manual Setup

```bash
# 1. Navigate to Django project
cd /home/rajesh/CausalKnowledgeTrace/django_ckt

# 2. Install dependencies
pip install --upgrade pip
pip install -r requirements.txt

# 3. Create .env file
cp .env.example .env
# Edit .env with your database credentials

# 4. Copy R modules
python manage.py copy_r_modules

# 5. Run migrations
python manage.py migrate

# 6. Collect static files
python manage.py collectstatic --noinput

# 7. Create superuser (optional)
python manage.py createsuperuser
```

## Configuration

Edit `.env` file with your settings:

```bash
# Database Configuration
DB_HOST=localhost          # or db-dev for Docker
DB_PORT=5433
DB_USER=rajesh
DB_PASSWORD=Software292$
DB_NAME=causalehr

# Application Port
APP_PORT=3838
```

## Running the Application

### Development Server

```bash
cd django_ckt
./run_django.sh
```

Or manually:

```bash
# Using Django development server
python manage.py runserver 0.0.0.0:3838

# Using Daphne (ASGI - recommended)
daphne -b 0.0.0.0 -p 3838 config.asgi:application

# Using Uvicorn (ASGI - alternative)
uvicorn config.asgi:application --host 0.0.0.0 --port 3838
```

### Access the Application

Open your browser and navigate to:
- **Main App**: http://localhost:3838
- **Admin Panel**: http://localhost:3838/admin

## Docker Deployment

### Using Docker Compose

```bash
# From project root
cd ..
docker-compose -f docker-compose.dev.yaml up --build
```

## Verifying Installation

### 1. Check Database Connection

```bash
cd /home/rajesh/CausalKnowledgeTrace/django_ckt
python manage.py shell
```

```python
from apps.core.models import Sentence, Predication
print(f"Sentences: {Sentence.objects.count()}")
print(f"Predications: {Predication.objects.count()}")
```

### 2. Test R Integration

```bash
cd /home/rajesh/CausalKnowledgeTrace/django_ckt
python test_r_integration.py
```

Or in Django shell:
```bash
python manage.py shell
```

```python
from apps.core.r_interface import get_r_interface

try:
    r = get_r_interface()
    print("✅ R interface initialized successfully")
except Exception as e:
    print(f"❌ R interface error: {e}")
```

### 3. Check Available URLs

```bash
python manage.py show_urls  # If django-extensions installed
```

Or visit:
- http://localhost:3838/ - Home/About page
- http://localhost:3838/visualization/ - Graph visualization
- http://localhost:3838/analysis/ - Causal analysis
- http://localhost:3838/upload/ - Data upload
- http://localhost:3838/config/ - Graph configuration

## Troubleshooting

### Issue: rpy2 not found

```bash
pip install rpy2
```

### Issue: R packages not found

```bash
Rscript ../doc/packages.R
```

### Issue: Database connection error

1. Check PostgreSQL is running:
   ```bash
   pg_isready -h localhost -p 5433
   ```

2. Verify credentials in `.env` file

3. Test connection:
   ```bash
   psql -h localhost -p 5433 -U rajesh -d causalehr
   ```

### Issue: Port already in use

Change `APP_PORT` in `.env` file:
```bash
APP_PORT=8000  # or any available port
```

### Issue: Static files not loading

```bash
python manage.py collectstatic --noinput
```

## Development Workflow

### Making Changes

1. **Edit code** in `apps/` or `templates/`
2. **Restart server** (Django auto-reloads in development)
3. **Test changes** in browser

### Adding New Features

1. Create new views in appropriate app
2. Add URL patterns
3. Create templates
4. Add static files (CSS/JS) if needed

### Database Changes

```bash
# Create migrations
python manage.py makemigrations

# Apply migrations
python manage.py migrate
```

## Next Steps

1. **Explore the Application**:
   - Visit http://localhost:3838
   - Read the About page for user guide
   - Try uploading a graph file

2. **Review Documentation**:
   - `README.md` - Full documentation
   - `DJANGO_MIGRATION_PLAN.md` - Migration strategy
   - `DJANGO_MIGRATION_STATUS.md` - Current status

3. **Contribute**:
   - Check `DJANGO_MIGRATION_STATUS.md` for pending tasks
   - See Phase 2-7 for areas needing work

## Support

For issues or questions:
- Check `DJANGO_MIGRATION_STATUS.md` for known issues
- Review Django logs in `../logs/django_app.log`
- Create an issue on GitHub

## Useful Commands

```bash
# Run tests
python manage.py test

# Create superuser
python manage.py createsuperuser

# Shell with Django context
python manage.py shell

# Check for issues
python manage.py check

# Show all URLs
python manage.py show_urls  # requires django-extensions

# Copy R modules
python manage.py copy_r_modules
```

## Performance Tips

1. **Use ASGI server** (Daphne or Uvicorn) instead of Django dev server
2. **Enable caching** in production
3. **Use connection pooling** for database
4. **Optimize R calls** - cache results when possible

## Security Notes

⚠️ **Important for Production**:

1. Change `DJANGO_SECRET_KEY` in `.env`
2. Set `ENVIRONMENT=production` in `.env`
3. Configure `ALLOWED_HOSTS` in `config/settings.py`
4. Use HTTPS
5. Enable CSRF protection
6. Review security checklist: `python manage.py check --deploy`

---

**Happy coding! 🚀**

