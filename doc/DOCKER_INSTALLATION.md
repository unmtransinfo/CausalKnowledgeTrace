# Docker Installation Guide

This guide provides step-by-step instructions for setting up CausalKnowledgeTrace using Docker and Docker Compose.

## Why Docker?

Docker provides a containerized environment with all dependencies pre-configured, making setup quick and consistent across different systems. This is the **recommended installation method** for most users.

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
docker-compose --version
```

You should see version information for both commands.

## Docker-Specific Installation Steps

### Step 1: Configure Environment Variables

Create a `.env` file with your database credentials:

```bash
# Copy the sample environment file
cp doc/sample.env .env

# Edit the .env file
nano .env  # or use your preferred editor (vim, code, etc.)
```

Update the `.env` file with your desired credentials:

```bash
# Database Configuration
DB_HOST=db  # Use 'db' for Docker (service name in docker-compose.yaml)
DB_PORT=5432
DB_USER=postgres  # Change to your preferred username
DB_PASSWORD=your_secure_password  # Change to a secure password
DB_NAME=causalehr
DB_SCHEMA=causalehr

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
```

**Important Notes:**

- For Docker setup, `DB_HOST` **must** be set to `db` (the PostgreSQL service name in docker-compose.yaml)
- Choose a strong password for `DB_PASSWORD`
- The `.env` file is ignored by git for security

### Step 2: Build and Start the Application

Build and start all services using Docker Compose:

```bash
# Build and start services in detached mode
docker-compose up -d

# View logs to monitor startup progress
docker-compose logs -f
```

**What happens during startup:**

1. PostgreSQL database container starts
2. Database is automatically restored from backup (first time only, takes ~10-15 minutes)
3. Application container builds (first time only, takes ~5-10 minutes)
4. Shiny application starts on port 3838

**First-time startup** may take 15-20 minutes due to database restoration and image building.

### Step 3: Access the Application

Once the services are running, access the application:

**URL**: [http://localhost:3838](http://localhost:3838)

The application should open in your web browser. If it doesn't open automatically, copy the URL above.

## Docker Commands Reference

### Managing the Application

```bash
# Start services
docker-compose up -d

# Stop services
docker-compose down

# View logs
docker-compose logs -f

# View logs for specific service
docker-compose logs -f cwt-app  # Application logs
docker-compose logs -f db       # Database logs

# Restart services
docker-compose restart

# Rebuild application (after code changes)
docker-compose up -d --build cwt-app
```

### Checking Service Status

```bash
# Check running containers
docker-compose ps

# Check container health
docker ps
```

### Database Management

```bash
# Access PostgreSQL database shell
docker-compose exec db psql -U postgres -d causalehr

# Backup database
docker-compose exec db pg_dump -U postgres causalehr > backup.sql

# View database logs
docker-compose logs -f db
```

## Troubleshooting

### Port Already in Use

If port 3838 or 5432 is already in use:

**Option 1**: Stop the conflicting service

```bash
# Find process using port 3838
lsof -i :3838  # macOS/Linux
netstat -ano | findstr :3838  # Windows

# Kill the process or stop the service
```

**Option 2**: Change ports in `docker-compose.yaml`

```yaml
services:
  db:
    ports:
      - "5433:5432"  # Change host port to 5433
  
  cwt-app:
    ports:
      - "3839:3838"  # Change host port to 3839
```

### Database Restoration Issues

If database restoration fails:

```bash
# Check database logs
docker-compose logs db

# Manually restore database
docker-compose exec db pg_restore -U postgres -d causalehr -Fd -j 4 /causalehr_backup
```

### Application Won't Start

```bash
# Check application logs
docker-compose logs cwt-app

# Rebuild application container
docker-compose down
docker-compose up -d --build

# Check if database is ready
docker-compose exec db pg_isready -U postgres
```

### Out of Disk Space

Docker images and containers can consume significant disk space:

```bash
# Check disk usage
docker system df

# Clean up unused resources
docker system prune -a

# Remove specific volumes (WARNING: deletes data)
docker-compose down -v
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
docker-compose down
docker-compose up -d --build
```
