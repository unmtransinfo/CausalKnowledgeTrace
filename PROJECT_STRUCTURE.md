# CausalKnowledgeTrace Project Structure Documentation

## Overview

This document provides detailed information about the reorganized project structure, component interactions, and configuration flow.

## Architecture

The CausalKnowledgeTrace project follows a modular architecture with two main components:

1. **Shiny Web Application**: Interactive visualization and configuration interface
2. **Graph Creation Engine**: Automated knowledge graph generation from biomedical literature

## Component Details

### Shiny Web Application (`shiny_app/`)

The Shiny application provides a user-friendly interface for DAG visualization and system configuration.

#### Core Files
- `app.R`: Main Shiny application with UI and server logic
- `dag_data.R`: DAG data configuration and initialization

#### Modules (`shiny_app/modules/`)
- `dag_visualization.R`: Network visualization using visNetwork
- `node_information.R`: Node details and information display
- `statistics.R`: Network statistics and analytics
- `data_upload.R`: File management and DAG loading
- `graph_config_module.R`: Configuration interface for graph generation
- `validate_modules.R`: Input validation functions
- `test_graph_config_module.R`: Testing utilities

#### Static Assets (`shiny_app/www/`)
- Directory for CSS, JavaScript, and image files

### Graph Creation Engine (`graph_creation/`)

The Python-based engine generates knowledge graphs from SemMedDB data.

#### Core Files
- `config.py`: Configuration management and database operations
- `pushkin.py`: Main graph generation script
- `consolidation.py`: Graph consolidation utilities
- `SemDAGconsolidator.py`: SemMedDB DAG consolidation

#### Supporting Directories
- `example/`: Example scripts and shell commands
- `result/`: Generated output files (R objects, JSON, metrics)

## Configuration Flow

### 1. User Configuration (Shiny App)
```
User Input (Shiny UI) → Validation → user_input.yaml
```

The Shiny app's "Graph Configuration" tab allows users to set:
- Exposure CUIs (Concept Unique Identifiers)
- Outcome CUIs
- Squelch Threshold (minimum unique pmids)
- Publication year cutoff

- K-hops parameter
- SemMedDB version

### 2. Configuration Storage
```
shiny_app/modules/graph_config_module.R → ../user_input.yaml
```

Configuration is saved as YAML in the project root directory, making it accessible to both components.

### 3. Graph Generation (Python Engine)
```
user_input.yaml → config.py → Database Queries → Generated Graphs
```

The Python engine reads the configuration and generates:
- R DAG objects (`MarkovBlanket_Union.R`, `degree_X.R` where X is the K-hops value)
- JSON assertion files (`causal_assertions.json`)
- Performance metrics (`performance_metrics.json`)
- Run configuration (`run_configuration.json`)

### 4. Visualization (Back to Shiny)
```
Generated R Files → Shiny Data Upload → Interactive Visualization
```

## File Path Management

### Relative Paths in Shiny App
- Module imports: `source("modules/module_name.R")`
- Configuration output: `../user_input.yaml` (project root)

### Absolute Paths in Launch Scripts
- `run_app.R`: Sets working directory to `shiny_app/`
- `run_graph_creation.py`: Uses project root for configuration file paths

## Launch Scripts

### `run_app.R`
- Sets working directory to `shiny_app/`
- Provides startup information
- Sources the main Shiny application

### `run_graph_creation.py`
- Validates project structure
- Checks for configuration file
- Launches appropriate Python script with configuration

## Benefits of This Structure

1. **Separation of Concerns**: Clear distinction between UI and processing logic
2. **Modularity**: Each component can be developed and maintained independently
3. **Reusability**: Modules can be easily reused or replaced
4. **Scalability**: Easy to add new features or components
5. **Configuration Management**: Centralized configuration system
6. **Documentation**: Clear structure makes the project easier to understand

## Development Workflow

1. **Configure**: Use Shiny app to set parameters
2. **Generate**: Run graph creation engine
3. **Visualize**: Load results back into Shiny app
4. **Iterate**: Refine parameters and regenerate as needed

## Maintenance Notes

- Configuration file (`user_input.yaml`) serves as the interface between components
- Module files in `shiny_app/modules/` can be updated independently
- Graph creation scripts can be modified without affecting the Shiny app
- Launch scripts provide consistent entry points for both components
