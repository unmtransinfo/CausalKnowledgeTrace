# CausalKnowledgeTrace: Interactive Literature-Based Causal Structure Mapping, Graph Generation, Visualization, and Refinement

## Overview

CausalKnowledgeTrace (CKT) helps researchers build causal knowledge graphs from published biomedical literature. The system automatically extracts and organizes causal relationships between biological concepts (genes, proteins, diseases, drugs, etc.) to support hypothesis generation and study design in observational research.

Users specify an exposure and outcome of interest. They can constrain the search by publication year, causal predicate type, and minimum number of supporting articles per relationship. CKT constructs initial partially directed acyclic graphs (PDAGs) representing causal structures between biomedical concepts. Users then edit these graphs interactively to remove unnecessary nodes and edges. CKT can export graphs and evidence from the literature for downstream analysis.
## Data Source

CKT queries SemMedDB, a database containing subject-predicate-object triples (e.g., "Smoking CAUSES Lung Cancer") extracted from 37+ million PubMed titles and abstracts using the SemRep natural language processing system. Each relationship is linked to its supporting literature, allowing users to trace claims back to primary evidence.

## System Architecture

CKT consists of two integrated components:

- **Python engine**: Implements graph construction, causal structure learning algorithms, and exports results for statistical analysis
- **Shiny web application**: Provides interactive visualization, parameter configuration, and iterative graph refinement

## Workflow

1. **Query Configuration**: Users specify an exposure and outcome of interest using UMLS (Unified Medical Language System) identifiers or free text search. Configurable parameters include publication year range, causal predicate types (CAUSES, INHIBITS, STIMULATES, PREVENTS, DISRUPTS), minimum article support thresholds, and degrees of separation (currently limited to 3 degrees between exposure and outcome).

2. **Graph Construction**: CKT builds initial partially directed acyclic graphs (PDAGs) representing potential causal pathways connecting the exposure to the outcome. Edge directions are inferred from temporal precedence, biological plausibility, and semantic predicate types extracted from the literature.

3. **Interactive Refinement**: Users iteratively remove spurious associations, biologically implausible relationships, or irrelevant variables through the web interface. This step incorporates domain expertise to improve graph quality.

4. **Export and Documentation**: Refined graphs and supporting evidence (PubMed IDs, semantic predicates, citation counts) are exported for downstream causal analysis and documentation.

## Advanced Causal Analysis Module

*In development*

The furtherAnalysis module performs systematic causal variable classification to support rigorous epidemiological analysis. Tools in this module:

- Classify variables as confounders, mediators, or colliders relative to the exposure-outcome relationship
- Apply graph traversal algorithms to retain variables within the causal vicinity while removing extraneous nodes
- Compute minimal sufficient adjustment sets satisfying the back-door criterion for unbiased causal effect estimation
- Identify adjustment strategies that block confounding paths while avoiding collider bias, M-bias, and butterfly bias
- Providing suggestions, given user input of measured variables, of best-match, minimally sufficient adjustment sets that may include proxy confounders

## Current Limitations and Development Roadmap

The advanced analysis tools currently function on small example graphs but encounter computational challenges on literature-derived graphs due to:

1. **Cyclic relationships**: Extracted literature relationships may contain feedback loops that violate the acyclic assumption required for standard causal inference algorithms. Biological systems often exhibit genuine bidirectional causation (e.g., inflammation causes oxidative stress, which further exacerbates inflammation).

2. **Markov equivalence classes**: Many edge orientations in literature-derived graphs are ambiguous, resulting in equivalence classes of graphs that encode identical conditional independence relationships but different causal interpretations. The number of possible orientations grows exponentially (2^k for k ambiguous edges), making computation intractable for large graphs.

Planned solutions include:

- **Cycle detection and resolution**: Implementing algorithms to identify feedback loops and apply domain-guided strategies for cycle breaking or collapsing cyclic components into latent variables
- **Constraint-based orientation**: Using temporal information, intervention evidence, and biological knowledge to reduce the equivalence class search space
- **Approximate inference methods**: Developing heuristic algorithms that identify near-optimal adjustment sets without exhaustive enumeration of all possible graph orientations
- **User-guided disambiguation**: Enabling interactive edge orientation based on expert knowledge to progressively reduce uncertainty

## Applications

This framework supports rigorous causal inference from observational biomedical data by enabling:

- Systematic exploration of alternative causal hypotheses represented in published literature
- Identification of potential confounders requiring measurement and adjustment in epidemiological studies
- Sensitivity analyses examining how conclusions change under different assumptions about causal directionality
- Hypothesis generation for experimental validation of putative causal relationships
- Literature-based justification for variable selection in statistical models

## 📋 What This Project Does

- **🌐 Interactive Visualization**: Web-based DAG exploration with zoom, pan, and node interaction
- **🔍 Graphical Causal Modeling**: Automated assembly of causal relationships from biomedical literature given Concept Unique Identifiers in the Unified Medical Language System, or [UMLS](https://www.nlm.nih.gov/research/umls/index.html), for the Exposure and Outcome of interest
- **📊 Evidence Analysis**: PMID-based evidence tracking and strength assessment
- **⚡ Performance Optimized**: Binary formats, caching, and vectorized operations for large graphs
- **🎯 Configurable Analysis**: Enter multiple CUIs for the exposure and/or outcome; Examine 1st, 2nd, or 3rd degree relationships
- **📁 Multiple Formats**: R DAG files, JSON assertions, optimized binary formats

## Key Features

### 🌐 Shiny Web Application

- **Interactive Network Visualization**: Explore DAGs with zoom, pan, and node selection capabilities
- **Dynamic Node Information**: Click on nodes to see detailed information and evidence
- **Physics Controls**: Adjust network layout parameters in real-time
- **Statistics Dashboard**: View network statistics and node distributions
- **Color-coded Categories**: Three-category system (Exposure/Outcome/Other) with optimized performance
- **Flexible Data Loading**: Load DAG structures from generated files or upload custom R files
- **Graph Configuration Interface**: Configure parameters for knowledge graph generation
- **Enhanced CUI Search**: Searchable interface for medical concept selection with semantic type information
- **Efficient Loading**: Fast loading for large graphs

### 🐍 Graph Creation Engine

- **Automated Knowledge Graph Generation**: Create causal graphs from SemMedDB biomedical literature
- **Multiple CUI Support**: Handle multiple Concept Unique Identifiers for exposures and outcomes
- **K-hop Analysis**: Configurable relationship depth (1-3 hops) for comprehensive graph traversal
- **Markov Blanket Analysis**: Advanced causal inference with Markov blanket computation
- **Blacklist Filtering**: Filter out generic or unwanted concepts during graph creation
- **Multiple Output Formats**: Generate R DAG objects, JSON assertion files, and optimized binary formats
- **Performance Monitoring**: Detailed timing analysis and execution metrics

## Project Structure

The project is organized into two main components with clear separation of concerns:

```
CausalKnowledgeTrace/
├── README.md                    # This documentation file
├── docker-compose.yaml          # Docker Compose configuration
├── restore.sh                   # Database restoration script (for Docker)
├── run_app.R                    # Enhanced launch script for Shiny application
├── user_input.yaml              # Configuration file (generated by Shiny app)
├── .env                         # Database credentials (create from doc/sample.env)
│
├── docker/                      # Docker configuration
│   └── Dockerfile               # Application container definition
│
├── doc/                         # Setup and configuration files
│   ├── DOCKER_INSTALLATION.md   # Docker installation guide
│   ├── MANUAL_INSTALLATION.md   # Manual installation guide
│   ├── environment.yaml         # Conda environment specification
│   ├── requirements.txt         # Python dependencies
│   ├── packages.R               # R package installation script
│   ├── sample.env               # Sample environment variables template
│   ├── filter.sql               # Database filtering queries for generic CUIs
│   └── create_cui_search_table.sql # CUI search index table creation script
│
├── shiny_app/                   # Shiny Web Application Component
│   ├── app.R                    # Main Shiny application file
│   ├── dag_data.R               # DAG data configuration file
│   ├── modules/                 # Modular Shiny components
│   │   ├── dag_visualization.R  # Network visualization module
│   │   ├── node_information.R   # Node information display module
│   │   ├── statistics.R         # Statistics and analytics module
│   │   ├── data_upload.R        # Data loading and file management
│   │   ├── causal_analysis.R    # Causal analysis functionality
│   │   └── graph_cache.R        # Graph caching system
│   ├── server/                  # Server-side logic modules
│   ├── ui/                      # UI component modules
│   └── utils/                   # Utility functions
│
├── furtherAnalysis/             # Analytic code and features that haven't been worked into the main body of code
│   ├── classifyVariables.R      # Classifies each variable by its causal role, e.g., confounder, collider, mediator, IV, and the like.
│   ├── cleanButterflyReport-CausalGraph.R    # (work-in-progress) code for identifying minimally sufficient adjustment sets in the context of butterfly bias 
│   ├── cleanButterflyReport-CausalGraph_compiled.R # (work-in-progress) compiled version of above
│   ├── mBiasReport-CausalGraph.R # (work-in-progress) identifying variables implicated in M-bias from causal graph
│   └── utils/                   # Utility functions
│
└── graph_creation/              # Graph Creation Engine Component
    ├── pushkin.py               # Main entry point (delegates to cli_interface.py)
    ├── cli_interface.py         # Command line interface and argument parsing
    ├── analysis_core.py         # Core analysis classes (GraphAnalyzer, MarkovBlanketAnalyzer)
    ├── config_models.py         # Configuration models and validation
    ├── database_operations.py   # Database connection and query operations
    ├── graph_operations.py      # Graph construction and manipulation
    ├── markov_blanket.py        # Markov blanket computation algorithms
    ├── post_process_optimization.py # File optimization (disabled)
    ├── config.py                # Backward compatibility wrapper
    ├── consolidation.py         # Graph consolidation utilities
    ├── SemDAGconsolidator.py    # SemMedDB DAG consolidation
    ├── example/                 # Example scripts and configurations
    │   ├── run_pushkin.sh       # Complete pipeline execution script
    │   └── run_consolidation.sh # Consolidation-only script
    ├── result/                  # Generated output files
    │   ├── MarkovBlanket_Union.R
    │   ├── degree_X.R           # X = K-hops value (1, 2, or 3)
    │   ├── causal_assertions_X.json
    │   └── performance_metrics.json
    └── output/                  # Alternative output directory
```

## Prerequisites

### UMLS Metathesaurus License (Required)

CausalKnowledgeTrace uses SemMedDB, a database derived from the UMLS Metathesaurus. A free UMLS license is required before installation.

**Why is this required?**
CausalKnowledgeTrace extracts causal relationships from SemMedDB, which is derived from the UMLS (Unified Medical Language System) Metathesaurus maintained by the National Library of Medicine. The NLM requires users to obtain a free license to access UMLS-derived resources.

**How to obtain your license:**
1. Visit the [UMLS Metathesaurus License Agreement](https://www.nlm.nih.gov/research/umls/knowledge_sources/metathesaurus/release/license_agreement.html)
2. Create an account or sign in with existing credentials
3. Complete the license application (takes ~5 minutes)
4. Wait for approval (typically 1-2 business days)
5. You'll receive confirmation via email

**Installation note:** You can complete software installation steps while waiting for license approval. However, you'll need your approved license before downloading the database.

### System Requirements

- **Disk Space**: At least 50GB free (for database and dependencies)
- **RAM**: 8GB minimum, 16GB recommended
- **Operating System**: Linux, macOS, or Windows

## Installation

### Common Setup Steps (Required for All Installation Methods)

Before proceeding with either installation method, complete these common steps:

#### Step 1: Get the Repository

**Option A: Clone with Git (Recommended)**

Git allows you to easily pull future updates to the project.

```bash
# Install Git if needed
# Linux: sudo apt-get install git
# macOS: brew install git
# Windows: https://git-scm.com/download/win

# Verify Git installation
git --version
# Should display: git version 2.x.x or higher

# Clone the repository
git clone git@github.com:unmtransinfo/CausalKnowledgeTrace.git
cd CausalKnowledgeTrace

# To get future updates later:
# git pull origin main
```

**Option B: Download as ZIP**

If you don't want to install Git:

1. Download: [Download ZIP from GitHub](https://github.com/unmtransinfo/CausalKnowledgeTrace/archive/refs/heads/main.zip)
2. Extract the ZIP file
3. Open terminal/command prompt and navigate to the extracted directory

#### Step 2: Download Database Backup

Download the SemMedDB database backup file from OneDrive (requires UMLS license):

**Download Link**: [causalehr_backup.tar.gz from OneDrive](https://unmm-my.sharepoint.com/:u:/g/personal/rajeshupadhayaya_unm_edu/ESO2UPECVk5Ku3JRSClPytMBngCV_0QN8-cA-zQRjaYogg?e=YolDZH)

**Note**: The file is approximately 25GB. Download may take several minutes depending on your internet connection. The file will typically download to your `Downloads` folder.

#### Step 3: Move and Extract Database Backup

Move the downloaded file to the project directory and extract it:

```bash
# Navigate to the project directory
cd CausalKnowledgeTrace

# Move the downloaded file from Downloads folder to current directory
# On Linux/macOS:
mv ~/Downloads/causalehr_backup.tar.gz .

# On Windows (in Git Bash or PowerShell):
# mv ~/Downloads/causalehr_backup.tar.gz .
# Or simply drag and drop the file from Downloads to the CausalKnowledgeTrace folder

# Extract the backup file
tar -xzf causalehr_backup.tar.gz

# Verify the backup directory exists
ls -la causalehr_backup/
```

You should see multiple `.dat.gz` files and a `toc.dat` file in the `causalehr_backup/` directory.

---

### Choose Your Installation Method

Now that you have completed the common setup steps, choose your installation method:

### 🐳 Docker Installation (Recommended)

**Best for:** Quick setup, testing, and most users
**Time:** ~20 minutes (including database restoration)
**Prerequisites:** Docker and Docker Compose only

Docker provides a containerized environment with all dependencies pre-configured. This is the fastest and easiest way to get started.

**📖 [Complete Docker Installation Guide →](doc/DOCKER_INSTALLATION.md)**

---

### 🔧 Manual Installation

**Best for:** Development, customization, and advanced users
**Time:** ~45 minutes
**Prerequisites:** PostgreSQL 16, Conda, Python 3.11, R 4.5.1

Manual installation gives you full control over the environment and is recommended for development and production deployments.

**📖 [Complete Manual Installation Guide →](doc/MANUAL_INSTALLATION.md)**

---
## Usage

For detailed usage instructions, see: [CKT Usage Instructions](https://docs.google.com/document/d/1SOr5PCclzzkw6_R13Swf0NEyNDwJL9FUW2pQY6wafSs/edit?usp=sharing)

## Troubleshooting

For troubleshooting help, please refer to the installation guide you used:

- **Docker Installation**: See [Docker Troubleshooting](doc/DOCKER_INSTALLATION.md#troubleshooting)
- **Manual Installation**: See [Manual Troubleshooting](doc/MANUAL_INSTALLATION.md#troubleshooting)

### Getting Help

If you encounter issues not covered in the installation guides:

1. **Check the logs:** The application outputs detailed error messages to the console
2. **GitHub Issues:** [Open an issue](https://github.com/unmtransinfo/CausalKnowledgeTrace/issues) with:
   - Your operating system and version
   - Installation method (Docker or Manual)
   - Error messages (copy the full text)
   - Steps you've already tried
3. **Email support:** Contact Scott Malec (SMalec@salud.unm.edu) or Rajesh Upadhayaya (RAJESHUPADHAYAYA@salud.unm.edu) to schedule a walk-through session


