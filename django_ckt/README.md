# Django CausalKnowledgeTrace

Django-based web application for CausalKnowledgeTrace, fully migrated from R/Shiny.

## Features

- **Django 5** with ASGI support (Daphne/Uvicorn)
- **Python-only architecture** - no R dependencies
- **PostgreSQL** database connectivity with existing schema
- **Bootstrap 5** frontend with modern, responsive design
- **Docker** deployment support
- **Interactive DAG visualization** with zoom, pan, and node interaction
- **Causal analysis tools** for graph refinement and evidence tracking

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
├── static/                   # Static files (CSS, JS, images)
├── templates/                # Django templates
└── media/                    # User uploads
```

## Installation

CausalKnowledgeTrace is deployed exclusively through Docker. See the main project README for installation instructions.

### Docker Deployment

The application runs in Docker containers with all dependencies pre-configured:

```bash
# From the project root directory
cd /home/rajesh/CausalKnowledgeTrace

# Build and start services
docker-compose -f docker-compose.dev.yaml up -d

# View logs
docker-compose -f docker-compose.dev.yaml logs -f
```

See `../docker-compose.dev.yaml` for Docker configuration details.



## Environment Variables

Environment variables are configured in the `.env.dev` file. Required variables:

- `ENVIRONMENT` - Environment type (development/production)
- `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME` - Database connection
- `DB_SENTENCE_SCHEMA`, `DB_SENTENCE_TABLE` - Sentence data location
- `DB_PREDICATION_SCHEMA`, `DB_PREDICATION_TABLE` - Predication data location
- `DB_SUBJECT_SEARCH_SCHEMA`, `DB_SUBJECT_SEARCH_TABLE` - Subject search table
- `DB_OBJECT_SEARCH_SCHEMA`, `DB_OBJECT_SEARCH_TABLE` - Object search table
- `DJANGO_PORT` - Application port (default: 3837)
- `DJANGO_SECRET_KEY` - Django secret key for security
- `DJANGO_ALLOWED_HOSTS` - Allowed hosts for Django

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
- [x] Phase 2: Core Django Apps
- [x] Phase 3: Views and Templates
- [x] Phase 4: Static Files and Assets
- [x] Phase 5: Docker Integration
- [x] Phase 6: Testing and Validation
- [x] Migration Complete: Fully migrated from R/Shiny to Django

## License

See main project LICENSE file.

