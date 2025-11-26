# CausalKnowledgeTrace R Package Installation Script
# This script installs all required R packages with automatic dependency resolution

# Set CRAN mirror
options(repos = c(CRAN = "https://cran.rstudio.com/"))

# Increase download timeout for large packages
options(timeout = 600)

# Function to check if package is installed
is_installed <- function(pkg) {
  require(pkg, character.only = TRUE, quietly = TRUE)
}

# Function to install packages with dependencies and error handling
install_with_deps <- function(packages, skip_if_present = TRUE) {
  for (pkg in packages) {
    if (skip_if_present && is_installed(pkg)) {
      message(paste("✓", pkg, "already installed"))
      next
    }
    
    message(paste("Installing", pkg, "with all dependencies..."))
    tryCatch({
      install.packages(pkg, dependencies = TRUE, Ncpus = parallel::detectCores())
      message(paste("✓", pkg, "installed successfully"))
    }, error = function(e) {
      message(paste("✗ ERROR installing", pkg, ":", e$message))
      message("Attempting binary installation...")
      tryCatch({
        install.packages(pkg, dependencies = TRUE, type = "binary")
        message(paste("✓", pkg, "installed successfully (binary)"))
      }, error = function(e2) {
        message(paste("✗ FAILED to install", pkg))
        message("  This package may need to be installed via conda or manually")
      })
    })
  }
}

# Install BiocManager first (needed for Bioconductor packages)
if (!is_installed("BiocManager")) {
  message("Installing BiocManager...")
  install.packages("BiocManager", dependencies = TRUE)
}

# Install Bioconductor packages (required for ggm and SEMgraph)
message("\n=== Installing Bioconductor packages ===")
bioc_packages <- c("graph", "RBGL", "Rgraphviz", "SEMgraph")
for (pkg in bioc_packages) {
  if (!is_installed(pkg)) {
    message(paste("Installing Bioconductor package:", pkg))
    tryCatch({
      BiocManager::install(pkg, update = FALSE, ask = FALSE)
      message(paste("✓", pkg, "installed successfully"))
    }, error = function(e) {
      message(paste("✗ WARNING: Could not install", pkg))
      message("  Some features may not work without this package")
    })
  } else {
    message(paste("✓ Bioconductor package", pkg, "already installed"))
  }
}

# Packages that should already be installed via conda (skip these)
conda_packages <- c(
  "shiny", "shinydashboard", "httpuv", "igraph", "dplyr", 
  "ggplot2", "DT", "yaml", "shinyjs", "testthat", "knitr", 
  "rmarkdown", "DBI", "htmltools", "visNetwork", "curl"
)

# Core CRAN packages that need to be installed via R
cran_packages <- c(
  # Causal inference packages (not in conda)
  "dagitty",         # DAG analysis and causal inference (requires V8)
  
  # Database connectivity
  "pool",            # Database connection pooling
  "RPostgres",       # Modern PostgreSQL driver
  "RPostgreSQL",     # Alternative PostgreSQL driver (fallback)
  
  # JSON support
  "jsonlite"         # JSON parsing and generation
)

message("\n=== Checking conda-installed packages ===")
for (pkg in conda_packages) {
  if (is_installed(pkg)) {
    message(paste("✓", pkg, "available (from conda)"))
  } else {
    message(paste("✗", pkg, "not found - will attempt to install from CRAN"))
    cran_packages <- c(cran_packages, pkg)
  }
}

# Try to install V8 (required for dagitty)
message("\n=== Installing V8 (required for dagitty) ===")
if (!is_installed("V8")) {
  message("Attempting to install V8...")
  tryCatch({
    install.packages("V8", dependencies = TRUE)
    message("✓ V8 installed successfully")
  }, error = function(e) {
    message("✗ V8 installation failed")
    message("  Note: V8 requires nodejs and libv8-dev")
    message("  dagitty will not be available without V8")
    message("  You may need to install system dependencies:")
    message("    - Ubuntu/Debian: sudo apt-get install libnode-dev")
    message("    - Or use: conda install -c conda-forge r-v8")
    # Remove dagitty from installation list if V8 fails
    cran_packages <- cran_packages[cran_packages != "dagitty"]
  })
}

# Install all CRAN packages with dependencies
message("\n=== Installing CRAN packages ===")
install_with_deps(cran_packages, skip_if_present = TRUE)

message("\n=== Installation Summary ===")

# Verify critical packages
critical_packages <- c(
  "shiny", "shinydashboard", "visNetwork", "dplyr", 
  "ggplot2", "DT", "yaml", "igraph", "jsonlite"
)

installed <- c()
missing <- c()

for (pkg in critical_packages) {
  if (is_installed(pkg)) {
    installed <- c(installed, pkg)
  } else {
    missing <- c(missing, pkg)
  }
}

message(paste("\n✓ Successfully installed:", length(installed), "critical packages"))
if (length(installed) > 0) {
  message(paste("  ", paste(installed, collapse = ", ")))
}

if (length(missing) > 0) {
  message(paste("\n✗ WARNING: Missing", length(missing), "critical packages:"))
  message(paste("  ", paste(missing, collapse = ", ")))
  message("\nTo install missing packages:")
  message(paste("  conda install -c conda-forge", paste0("r-", tolower(missing), collapse = " ")))
} else {
  message("\n✓ All critical packages installed successfully!")
}

# Optional packages status
optional_packages <- c("dagitty", "RPostgres", "V8")
message("\n=== Optional packages status ===")
for (pkg in optional_packages) {
  if (is_installed(pkg)) {
    message(paste("✓", pkg, "available"))
  } else {
    message(paste("○", pkg, "not available (optional)"))
  }
}

