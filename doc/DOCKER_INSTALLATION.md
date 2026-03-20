# Docker Installation Guide

This guide provides step-by-step instructions for setting up CausalKnowledgeTrace using Docker and Docker Compose.

## Why Docker?

Docker provides a containerized environment with all dependencies pre-configured, making setup quick and consistent across different systems. This is the **only supported installation method** for CausalKnowledgeTrace.

**Included Software Versions:**
- PostgreSQL 16 (database server)
- Python 3.11 (Django web application and graph creation engine)
- Django 5 (web framework)

## Prerequisites

### Before You Begin

⚠️ **Important**: Complete the [Common Setup Steps](../README.md#common-setup-steps-required-for-both-methods) in the main README first:

1. Get the repository (clone or download)
2. Download database backup from OneDrive
3. Extract database backup to project directory

### Required Software

**Docker Desktop** (includes Docker and Docker Compose)

- **Windows/Mac**: Download from [https://www.docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop)
- **Linux**: Follow instructions at [https://docs.docker.com/engine/install/](https://docs.docker.com/engine/install/)

### System Requirements

- **Disk Space**: At least 50GB free (for database and Docker images)
- **RAM**: 8GB minimum, 16GB recommended
- **OS**: Windows 10/11, macOS 10.15+, or Linux (Ubuntu 20.04+, Debian 10+, etc.)

### Verify Docker Installation

After installing Docker, verify it's working correctly:

```bash
docker --version
docker compose version
```

You should see version information for both commands.

## Docker-Specific Installation Steps

### Step 1: Configure Environment Variables

Create a `.env.dev` file with your database credentials:

```bash
# Copy the sample environment file
cp doc/sample.env .env.dev

# Edit the .env.dev file with your preferred editor
nano .env.dev  # or use: vim .env.dev, code .env.dev, etc.
```

Update the `.env.dev` file with your desired credentials:

```bash
# Development Environment
ENVIRONMENT=development
DB_HOST=db-dev
DB_PORT=5433
DB_USER=<username>  # Change to your preferred username
DB_PASSWORD=<password>  # Change to a secure password
DB_NAME=causalehr

# Database Schema and Table Configuration
DB_SENTENCE_SCHEMA=public
DB_SENTENCE_TABLE=sentence

DB_PREDICATION_SCHEMA=public
DB_PREDICATION_TABLE=predication

# CUI Search Tables - Split by exposure/outcome
DB_SUBJECT_SEARCH_SCHEMA=filtered
DB_SUBJECT_SEARCH_TABLE=subject_search

DB_OBJECT_SEARCH_SCHEMA=filtered
DB_OBJECT_SEARCH_TABLE=object_search

# Django Configuration
DJANGO_PORT=3837
DJANGO_SECRET_KEY=django-insecure-dev-key-change-in-production
DJANGO_ALLOWED_HOSTS=*
```

**Important Notes:**

- For Docker setup, `DB_HOST` should be set to `db-dev` (the PostgreSQL service name in docker-compose.dev.yaml)
- `DB_PORT` should be `5433` for the development environment
- Choose a strong password for `DB_PASSWORD`
- The `.env.dev` file is ignored by git for security
- Keep this file secure and never commit it to version control
- Docker Compose automatically loads environment variables from the `.env.dev` file

### Step 2: Build and Start the Application

Build and start all services using Docker Compose:

```bash
# Build and start services in detached mode
docker compose -f docker-compose.dev.yaml up -d

# View logs to monitor startup progress
docker compose -f docker-compose.dev.yaml logs -f
```

**What happens during startup:**

1. PostgreSQL database container starts
2. Database is automatically restored from backup (first time only, takes ~10-15 minutes)
3. Application container builds (first time only, takes ~5-10 minutes)
4. Django application starts on port 3837

**First-time startup** may take 15-20 minutes due to database restoration and image building.

### Step 3: Access the Application

Once the services are running, access the application:

**URL**: [http://localhost:3837](http://localhost:3837)

The application should open in your web browser. If it doesn't open automatically, copy the URL above.

## Docker Commands Reference

### Managing the Application

```bash
# Start services
docker compose -f docker-compose.dev.yaml up -d

# Stop services
docker compose -f docker-compose.dev.yaml down

# View logs
docker compose -f docker-compose.dev.yaml logs -f

# View logs for specific service
docker compose -f docker-compose.dev.yaml logs -f cwt-app  # Application logs
docker compose -f docker-compose.dev.yaml logs -f db       # Database logs

# Restart services
docker compose -f docker-compose.dev.yaml restart

# Rebuild application (after code changes)
docker compose -f docker-compose.dev.yaml up -d --build cwt-app

# Run start the container without building
docker compose -f docker-compose.dev.yaml up --no-build
```

### Checking Service Status

```bash
# Check running containers
docker compose -f docker-compose.dev.yaml ps

# Check container health
docker ps
```

### Database Management

```bash
# Access PostgreSQL database shell
docker compose -f docker-compose.dev.yaml exec db psql -U postgres -d causalehr

# Backup database
docker compose -f docker-compose.dev.yaml exec db pg_dump -U postgres causalehr > backup.sql

# View database logs
docker compose -f docker-compose.dev.yaml logs -f db
```

## Troubleshooting

### Port Already in Use

If port 3837 or 5433 is already in use:

**Option 1**: Stop the conflicting service

```bash
# Find process using port 3837
lsof -i :3837  # macOS/Linux
netstat -ano | findstr :3837  # Windows

# Kill the process or stop the service
```

**Option 2**: Change ports in `docker-compose.dev.yaml`

```yaml
services:
  db:
    ports:
      - "5434:5433"  # Change host port to 5434

  cwt-app:
    ports:
      - "3838:3837"  # Change host port to 3838
```

### Database Restoration Issues

If database restoration fails:

```bash
# Check database logs
docker compose -f docker-compose.dev.yaml logs db

# Manually restore database
docker compose -f docker-compose.dev.yaml exec db pg_restore -U postgres -d causalehr -Fd -j 4 /causalehr_backup
```

### Application Won't Start

```bash
# Check application logs
docker compose -f docker-compose.dev.yaml logs cwt-app

# Rebuild application container
docker compose -f docker-compose.dev.yaml down
docker compose -f docker-compose.dev.yaml up -d --build

# Check if database is ready
docker compose -f docker-compose.dev.yaml exec db pg_isready -U postgres
```

### Out of Disk Space

Docker images and containers can consume significant disk space:

```bash
# Check disk usage
docker system df

# Clean up unused resources
docker system prune -a

# Remove specific volumes (WARNING: deletes data)
docker compose -f docker-compose.dev.yaml down -v
```

### Permission Issues (Linux)

If you encounter permission errors:

```bash
# Add your user to docker group
sudo usermod -aG docker $USER

# Log out and log back in for changes to take effect
```

## Updating the Application

To update to the latest version:

```bash
# Pull latest code
git pull origin main

# Rebuild and restart services
docker compose -f docker-compose.dev.yaml down
docker compose -f docker-compose.dev.yaml up -d --build
```
