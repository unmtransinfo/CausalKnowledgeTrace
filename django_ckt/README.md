# Django CausalKnowledgeTrace

Django-based web application for CausalKnowledgeTrace, migrated from Shiny.

## Features

- **Django 5** with ASGI support (Daphne/Uvicorn)
- **R Integration** via rpy2 for visualization (visNetwork, dagitty, igraph)
- **PostgreSQL** database connectivity with existing schema
- **Bootstrap 5** frontend matching Shiny Dashboard aesthetic
- **Docker** deployment support

## Project Structure

```
django_ckt/
├── manage.py                  # Django management script
├── requirements.txt           # Python dependencies
├── config/                    # Django project configuration
│   ├── settings.py           # Django settings
│   ├── urls.py               # Root URL configuration
│   ├── asgi.py               # ASGI configuration
│   └── wsgi.py               # WSGI configuration
├── apps/                      # Django applications
│   ├── core/                 # Core functionality
│   ├── visualization/        # DAG visualization
│   ├── analysis/             # Causal analysis
│   ├── upload/               # File upload
│   └── graph_config/         # Graph configuration
├── r_modules/                # R modules (from shiny_app/modules)
├── static/                   # Static files (CSS, JS, images)
├── templates/                # Django templates
└── media/                    # User uploads
```

## Installation

### Prerequisites

- Python 3.11+
- R 4.5.1+
- PostgreSQL 16+
- Conda (recommended)

### Setup

1. **Navigate to Django project:**
   ```bash
   cd /home/rajesh/CausalKnowledgeTrace/django_ckt
   ```

2. **Install Python dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

3. **Install R packages:**
   ```bash
   Rscript ../doc/packages.R
   ```

4. **Set environment variables:**
   Copy `.env.example` to `.env` and configure:
   ```
   DB_HOST=localhost
   DB_PORT=5433
   DB_USER=rajesh
   DB_PASSWORD=Software292$
   DB_NAME=causalehr
   APP_PORT=3838
   ```

5. **Run migrations:**
   ```bash
   python manage.py migrate
   ```

6. **Create superuser (optional):**
   ```bash
   python manage.py createsuperuser
   ```

7. **Collect static files:**
   ```bash
   python manage.py collectstatic --noinput
   ```

8. **Run development server:**
   ```bash
   # Using Django development server
   python manage.py runserver 0.0.0.0:3838
   
   # Or using Daphne (ASGI)
   daphne -b 0.0.0.0 -p 3838 config.asgi:application
   
   # Or using Uvicorn (ASGI)
   uvicorn config.asgi:application --host 0.0.0.0 --port 3838
   ```

## Docker Deployment

See `../docker-compose.dev.yaml` for Docker configuration.

```bash
cd ..
docker-compose -f docker-compose.dev.yaml up --build
```

## Environment Variables

All environment variables from the original Shiny app are supported:

- `APP_PORT` - Application port (default: 3838)
- `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`
- `DB_SENTENCE_SCHEMA`, `DB_SENTENCE_TABLE`
- `DB_PREDICATION_SCHEMA`, `DB_PREDICATION_TABLE`
- `DB_SUBJECT_SEARCH_SCHEMA`, `DB_SUBJECT_SEARCH_TABLE`
- `DB_OBJECT_SEARCH_SCHEMA`, `DB_OBJECT_SEARCH_TABLE`

## Development

### Running Tests

```bash
python manage.py test
```

### Code Style

```bash
# Format code
black .

# Lint code
flake8 .
```

## Migration Status

- [x] Phase 1: Django Project Setup
- [ ] Phase 2: R Integration Setup
- [ ] Phase 3: Core Django Apps
- [ ] Phase 4: Views and Templates
- [ ] Phase 5: Static Files and Assets
- [ ] Phase 6: Docker Integration
- [ ] Phase 7: Testing and Validation

## License

See main project LICENSE file.

