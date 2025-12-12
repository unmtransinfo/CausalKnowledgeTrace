# Manual Installation Guide

This guide provides step-by-step instructions for manually setting up CausalKnowledgeTrace without Docker.

## Prerequisites

### Before You Begin

⚠️ **Important**: Complete the [Common Setup Steps](../README.md#common-setup-steps-required-for-both-methods) in the main README first:

1. Get the repository (clone or download)
2. Download database backup from OneDrive
3. Extract database backup to project directory

### System Requirements

- **Operating System**: Linux, macOS, or Windows (with WSL2 recommended)
- **Disk Space**: At least 50GB free (for database and dependencies)
- **RAM**: 8GB minimum, 16GB recommended

### Required Software

1. **PostgreSQL** - Database server (version 12 or higher)
2. **Conda/Miniconda** - Environment management
3. **Python** - Version 3.11 or higher (installed via Conda)
4. **R** - Version 4.0 or higher

## Manual Installation Steps

### Step 1: Install PostgreSQL

PostgreSQL is required for storing and querying the SemMedDB data.

#### Linux (Ubuntu/Debian)

```bash
sudo apt-get update
sudo apt-get install postgresql postgresql-contrib
sudo systemctl start postgresql
sudo systemctl enable postgresql
```

#### macOS

```bash
# Using Homebrew
brew install postgresql@16
brew services start postgresql@16
```

#### Windows

Download and install from [https://www.postgresql.org/download/windows/](https://www.postgresql.org/download/windows/)

#### Verify Installation

```bash
psql --version
```

**Installation Guide**: For detailed instructions, see [PostgreSQL Installation Guide](https://www.postgresql.org/download/)

### Step 2: Install R

R is required for the Shiny web application and statistical analysis.

#### Linux (Ubuntu/Debian)

```bash
# Add CRAN repository for latest R version
sudo apt-get update
sudo apt-get install r-base r-base-dev

# Install system dependencies for R packages
sudo apt-get install \
    libxml2-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    libfontconfig1-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libfreetype6-dev \
    libpng-dev \
    libtiff5-dev \
    libjpeg-dev
```

#### macOS

```bash
# Download and install from CRAN
# Or use Homebrew
brew install r
```

#### Windows

Download and install from [https://cran.r-project.org/bin/windows/base/](https://cran.r-project.org/bin/windows/base/)

#### Verify Installation

```bash
R --version
```

**Download**: [https://cran.r-project.org/](https://cran.r-project.org/)

### Step 3: Install Miniconda

Miniconda provides Python and environment management.

#### Linux

```bash
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash Miniconda3-latest-Linux-x86_64.sh
```

#### macOS

```bash
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-x86_64.sh
bash Miniconda3-latest-MacOSX-x86_64.sh
```

#### Windows

Download and install from [https://docs.conda.io/en/latest/miniconda.html](https://docs.conda.io/en/latest/miniconda.html)

#### Verify Installation

```bash
conda --version
conda info
```

**Installation Guide**: [https://www.anaconda.com/docs/getting-started/miniconda/install](https://www.anaconda.com/docs/getting-started/miniconda/install)

### Step 4: Setup PostgreSQL Database

Create and restore the database from the backup you downloaded in the common setup steps:

```bash
# Create the database (replace <username> with your PostgreSQL username)
createdb -U <username> -h localhost causalehr

# Restore the database from the extracted backup
pg_restore -d causalehr -U <username> -h localhost -Fd -j 4 causalehr_backup/
```

**Note**: Database restoration may take 10-15 minutes depending on your system.

#### Verify Database

```bash
# Connect to database
psql -U <username> -h localhost -d causalehr

# Check tables (in psql shell)
\dt

# Exit psql
\q
```

### Step 5: Configure Environment Variables

Create a `.env` file with your database credentials:

```bash
# Copy the sample environment file
cp doc/sample.env .env

# Edit the .env file
nano .env  # or use your preferred editor
```

Update the `.env` file with your database credentials:

```bash
# Database Configuration
DB_HOST=localhost
DB_PORT=5432
DB_USER=your_username  # Your PostgreSQL username
DB_PASSWORD=your_password  # Your PostgreSQL password
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

**Important**:

- Replace `your_username` and `your_password` with your actual PostgreSQL credentials
- For manual installation, `DB_HOST` should be `localhost`
- The `.env` file is ignored by git for security

### Step 6: Setup Conda Environment

Create and activate the Conda environment:

```bash
# Create conda environment from YAML file
conda env create -f doc/environment.yaml

# Activate the environment
conda activate causalknowledgetrace

# Install Python dependencies
pip install -r doc/requirements.txt
```

**Note**: Environment creation may take 5-10 minutes.

### Step 7: Install R Packages

Install required R packages:

```bash
# Make sure conda environment is activated
conda activate causalknowledgetrace

# Install R packages
Rscript doc/packages.R
```

**Note**: R package installation may take 10-15 minutes depending on your system and internet connection.

### Step 8: Run the Application

Launch the Shiny web application:

```bash
# Make sure you're in the project directory
cd CausalKnowledgeTrace

# Activate conda environment
conda activate causalknowledgetrace

# Run the application
Rscript run_app.R
```

The application will start and open in your default web browser. If it doesn't open automatically, look for the URL in the terminal output (typically `http://127.0.0.1:3838`).

**Note**: The first time you run the application, it may take a few moments to initialize database connections and create necessary index tables.

## Troubleshooting

### PostgreSQL Connection Issues

**Problem**: Cannot connect to database

**Solutions**:

```bash
# Check if PostgreSQL is running
sudo systemctl status postgresql  # Linux
brew services list  # macOS

# Start PostgreSQL if not running
sudo systemctl start postgresql  # Linux
brew services start postgresql@16  # macOS

# Check PostgreSQL logs
sudo tail -f /var/log/postgresql/postgresql-*.log  # Linux
tail -f /usr/local/var/log/postgres.log  # macOS
```

### Conda Environment Issues

**Problem**: Environment creation fails

**Solutions**:

```bash
# Update conda
conda update conda

# Clean conda cache
conda clean --all

```

### R Package Installation Failures

**Problem**: R packages fail to install

**Solutions**:

```bash
# Install system dependencies (Linux)
sudo apt-get install build-essential gfortran

# Update R packages
R
> update.packages(ask = FALSE)
> quit()

# Try installing packages again
Rscript doc/packages.R
```

### Port Already in Use

**Problem**: Port 3838 is already in use

**Solutions**:

```bash
# Find process using port 3838
lsof -i :3838  # macOS/Linux
netstat -ano | findstr :3838  # Windows

# Kill the process
kill -9 <PID>  # Replace <PID> with process ID
```

### Database Restoration Errors

**Problem**: pg_restore fails

**Solutions**:

```bash
# Check PostgreSQL version compatibility
psql --version

# Try restoring with verbose output
pg_restore -d causalehr -U <username> -v -Fd -j 4 causalehr_backup/

# Check disk space
df -h  # Linux/macOS
```

## Updating the Application

To update to the latest version:

```bash
# Pull latest code
git pull origin main

# Update conda environment
conda env update -f doc/environment.yaml

# Update Python dependencies
pip install -r doc/requirements.txt --upgrade

# Update R packages
Rscript doc/packages.R
```
