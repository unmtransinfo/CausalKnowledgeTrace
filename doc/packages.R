add code to run R package using form packages.R file whith this code 
# Set CRAN mirror
options(repos = c(CRAN = "https://cran.rstudio.com/"))

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
    "SEMgraph",        # Structural equation modeling graphs
    "ggplot2",         # Enhanced plotting capabilities
    "testthat",        # Testing framework
    "knitr",           # Dynamic report generation
    "rmarkdown"        # R Markdown support
))