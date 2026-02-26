# Setup Notes - Django CKT

## Virtual Environment

This project uses the **top-level virtual environment** located at `/home/rajesh/CausalKnowledgeTrace/venv/`.

### Why?

- Shared environment with the existing Shiny app and graph_creation scripts
- Avoids duplicate package installations
- Easier to manage dependencies across the entire project

### Important Note

**The scripts assume you have already activated the virtual environment.** They do not automatically activate it for you. Make sure to activate the environment before running any Django commands:

```bash
# From project root
cd /home/rajesh/CausalKnowledgeTrace
source venv/bin/activate

# Then navigate to Django project
cd django_ckt
```

## Requirements

The `requirements.txt` file has been simplified to remove version pinning for easier maintenance.

### Key Dependencies

- **Django** - Web framework
- **psycopg2-binary** - PostgreSQL adapter
- **rpy2** - R integration
- **daphne/uvicorn** - ASGI servers
- **pandas, numpy, networkx, scipy** - Data processing
- **pytest, pytest-django** - Testing

### Installing Dependencies

```bash
# Navigate to Django project
cd /home/rajesh/CausalKnowledgeTrace/django_ckt

# Install all dependencies
pip install -r requirements.txt
```

## Quick Start

### First Time Setup

```bash
cd /home/rajesh/CausalKnowledgeTrace/django_ckt
./setup_django.sh
```

This will:
1. Install dependencies
2. Copy R modules
3. Run migrations
4. Collect static files

### Running the Application

```bash
cd /home/rajesh/CausalKnowledgeTrace/django_ckt
./run_django.sh
```

The script will:
1. Load environment variables from `.env`
2. Start the server (Daphne, Uvicorn, or Django dev server)

## Environment Variables

Create a `.env` file in `django_ckt/` directory:

```bash
cp .env.example .env
```

Edit with your configuration:

```bash
# Django
DJANGO_SECRET_KEY=your-secret-key
ENVIRONMENT=development

# Application
APP_PORT=3838

# Database
DB_HOST=localhost
DB_PORT=5433
DB_USER=rajesh
DB_PASSWORD=Software292$
DB_NAME=causalehr
```

## Testing R Integration

```bash
cd /home/rajesh/CausalKnowledgeTrace/django_ckt

# Run R integration test
python test_r_integration.py
```

This will verify:
- rpy2 is installed
- R libraries are available (dagitty, igraph, visNetwork, dplyr)
- R interface initializes correctly
- Simple DAG operations work

## Common Issues

### Issue: "rpy2 not found"

**Solution**: Install rpy2:
```bash
pip install rpy2
```

### Issue: "R packages not found"

**Solution**: Install R packages:
```bash
Rscript ../doc/packages.R
```

### Issue: "Database connection error"

**Solution**: 
1. Check PostgreSQL is running
2. Verify credentials in `.env` file
3. Test connection: `psql -h localhost -p 5433 -U rajesh -d causalehr`

## Directory Structure

```
/home/rajesh/CausalKnowledgeTrace/
├── venv/                    # Shared virtual environment
├── shiny_app/              # Original Shiny application
├── graph_creation/         # Graph generation scripts
├── django_ckt/             # Django application (this directory)
│   ├── .env               # Environment variables (create from .env.example)
│   ├── manage.py          # Django management script
│   ├── requirements.txt   # Python dependencies
│   ├── setup_django.sh    # Setup script
│   ├── run_django.sh      # Run script
│   └── ...
└── ...
```

## Next Steps

1. **Install dependencies**: `pip install -r requirements.txt`
2. **Configure .env**: Edit database credentials
3. **Test R integration**: `python test_r_integration.py`
4. **Run migrations**: `python manage.py migrate`
5. **Start server**: `./run_django.sh`

---

**Note**: All scripts assume you're working from the `django_ckt/` directory unless otherwise specified.

