# CausalKnowledgeTrace R Package Installation Script

# Configure compiler
makevars <- "CC=gcc
CXX=g++
CXX17=g++
CC17=gcc
FC=gfortran
CFLAGS=-O2 -fPIC
CXXFLAGS=-O2 -fPIC
"
dir.create("~/.R", showWarnings = FALSE, recursive = TRUE)
cat(makevars, file = "~/.R/Makevars")

# Set CRAN mirror
options(repos = c(CRAN = "https://cran.rstudio.com/"))

# Install BiocManager and Bioconductor dependencies for ggm
if (!require("BiocManager", quietly = TRUE))
    install.packages("BiocManager")

# Install graph dependencies from Bioconductor (required for ggm and SEMgraph)
BiocManager::install(c("graph", "RBGL", "Rgraphviz", "SEMgraph"), dependencies = TRUE, update = FALSE, ask = FALSE)

# Verify SEMgraph installed
if (!require("SEMgraph", quietly = TRUE)) quit(status = 1)

# Install all required packages for CausalKnowledgeTrace application
install.packages(c(
    # Core required packages
    "shiny",           # Core Shiny framework
    "shinydashboard",  # Dashboard UI components
    "visNetwork",      # Interactive network visualization
    "dplyr",           # Data manipulation
    "DT",              # Interactive data tables
    "dagitty",         # DAG analysis and causal inference
    "igraph",          # Graph analysis and manipulation
    "yaml",            # YAML configuration file support
    "shinyjs",         # Enhanced UI interactions
    "ggplot2",         # Enhanced plotting capabilities
    "testthat",        # Testing framework
    "knitr",           # Dynamic report generation
    "rmarkdown",       # R Markdown support

    # Database connectivity packages (required for CUI search functionality)
    "DBI",             # Database interface
    "pool",            # Database connection pooling
    "RPostgres",       # Modern PostgreSQL driver (preferred)
    "RPostgreSQL",     # Alternative PostgreSQL driver (fallback)
    "htmltools",       # HTML generation utilities
    "jsonlite"         # JSON parsing and generation
))