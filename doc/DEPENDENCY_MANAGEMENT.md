# CausalKnowledgeTrace Dependency Management

This document explains the comprehensive dependency management system for the CausalKnowledgeTrace project, which includes both Python and R components.

## Overview

The project now includes multiple dependency management approaches to accommodate different workflows and preferences:

### Python Dependencies
- **requirements.txt** - Standard pip requirements file
- **check_python_dependencies.py** - Verification script for Python packages

### R Dependencies
- **DESCRIPTION** - Standard R package dependency specification
- **renv.lock** - Modern R dependency management with renv
- **requirements_r.txt** - Simple text list of R packages
- **install_r_dependencies.R** - Automated R package installer
- **check_dependencies.R** - Verification script for R packages

### Cross-Platform
- **setup_dependencies.sh** - Master setup script for both Python and R
- **DEPENDENCY_MANAGEMENT.md** - This documentation file

## File Descriptions

### Python Files

#### `requirements.txt`
Updated comprehensive Python requirements file including:
- **Core dependencies**: psycopg2-binary, PyYAML, pandas, numpy
- **Graph processing**: networkx, scipy
- **LangChain integration**: langchain, langchain-community (for DAG consolidation)
- **Development tools**: pytest, pytest-cov

#### `check_python_dependencies.py`
Python script that:
- Verifies Python version (3.8+ required)
- Checks all required and optional packages
- Tests core functionality (database, data processing, graph processing, config handling)
- Provides detailed status report

### R Files

#### `DESCRIPTION`
Standard R package dependency file that:
- Lists all required packages in `Imports` field
- Lists optional packages in `Suggests` field
- Provides project metadata
- Compatible with `devtools::install_deps()`

#### `renv.lock`
Modern R dependency management file for reproducible environments:
- Locks specific package versions
- Includes dependency tree information
- Use with `renv::restore()` for exact reproduction

#### `requirements_r.txt`
Simple text list of R packages for alternative package managers:
- One package per line
- Compatible with `pak::pkg_install(readLines("requirements_r.txt"))`
- Easy to read and modify

#### `install_r_dependencies.R`
Automated R package installer that:
- Installs required packages with error handling
- Installs optional packages separately
- Provides detailed feedback during installation
- Verifies core functionality after installation

#### `check_dependencies.R`
R dependency verification script that:
- Checks R version compatibility
- Verifies all required and optional packages
- Tests core functionality (Shiny apps, DAG processing, network visualization)
- Provides comprehensive status report

### Cross-Platform Files

#### `setup_dependencies.sh`
Master setup script that:
- Checks system prerequisites (Python 3, pip, R, Rscript)
- Installs Python dependencies via pip
- Installs R dependencies via automated script
- Runs verification checks for both environments
- Provides colored output and error handling

## Usage Instructions

### Quick Setup (Recommended)
```bash
# Run the master setup script
./setup_dependencies.sh
```

### Python Only
```bash
# Install Python dependencies
pip install -r requirements.txt

# Verify installation
python check_python_dependencies.py
```

### R Only
```r
# Automated installation
source("install_r_dependencies.R")

# Verify installation
source("check_dependencies.R")
```

### Alternative R Methods

#### Using renv (Reproducible Environments)
```r
# First time setup
install.packages("renv")
renv::init()

# Restore from lock file
renv::restore()
```

#### Using DESCRIPTION file
```r
# Install devtools if needed
install.packages("devtools")

# Install all dependencies
devtools::install_deps()
```

#### Using pak (Modern Package Manager)
```r
# Install pak if needed
install.packages("pak")

# Install from requirements file
pak::pkg_install(readLines("requirements_r.txt"))
```

## Package Lists

### Python Required Packages
- `psycopg2-binary` - PostgreSQL database connectivity
- `PyYAML` - YAML configuration file support
- `pandas` - Data manipulation and analysis
- `numpy` - Numerical computing
- `networkx` - Graph analysis and manipulation
- `scipy` - Scientific computing

### Python Optional Packages
- `langchain` - LLM integration framework
- `langchain-community` - Community LangChain integrations
- `pytest` - Testing framework
- `pytest-cov` - Test coverage reporting

### R Required Packages
- `shiny` - Web application framework
- `shinydashboard` - Dashboard UI components
- `visNetwork` - Interactive network visualization
- `dplyr` - Data manipulation
- `DT` - Interactive data tables
- `dagitty` - DAG analysis and causal inference
- `igraph` - Graph analysis and manipulation
- `yaml` - YAML configuration file support

### R Optional Packages
- `shinyjs` - Enhanced UI interactions
- `SEMgraph` - Structural equation modeling graphs
- `ggplot2` - Enhanced plotting capabilities
- `testthat` - Testing framework
- `knitr` - Dynamic report generation
- `rmarkdown` - R Markdown support

## Troubleshooting

### Common Issues

1. **Python version conflicts**: Ensure Python 3.8+ is installed
2. **R package compilation errors**: Install system dependencies for R packages
3. **Network issues**: Check internet connection for package downloads
4. **Permission errors**: Use appropriate user permissions or virtual environments

### Getting Help

1. Run the verification scripts to identify specific issues
2. Check the detailed error messages in the installation scripts
3. Refer to individual package documentation for specific installation issues
4. Consider using virtual environments (Python) or renv (R) for isolation

## Maintenance

### Updating Dependencies

#### Python
```bash
# Update requirements.txt with new versions
pip freeze > requirements.txt

# Or manually edit requirements.txt and reinstall
pip install -r requirements.txt --upgrade
```

#### R
```r
# Update all packages
update.packages()

# Update renv.lock file
renv::snapshot()
```

### Adding New Dependencies

1. Add to appropriate requirements file
2. Update installation scripts if needed
3. Update verification scripts to test new packages
4. Update this documentation

This comprehensive dependency management system ensures that the CausalKnowledgeTrace project can be easily set up and maintained across different environments and workflows.
