# Interactive DAG Visualization with Shiny

This Shiny application provides a flexible, interactive visualization of Directed Acyclic Graphs (DAGs) that can load data from external R files. The application is designed to be adaptable to any DAG structure while providing comprehensive visualization and analysis tools.

## Features

- **Flexible Data Loading**: Load any DAG structure from external R files
- **Interactive Network Visualization**: Explore the DAG with zoom, pan, and node selection capabilities
- **Dynamic Node Information**: Click on nodes to see detailed information
- **Physics Controls**: Adjust network layout parameters in real-time
- **Statistics Dashboard**: View network statistics and node distributions
- **Color-coded Categories**: Automatically categorize and color nodes
- **Data Reload**: Refresh data without restarting the application

## File Structure

```
project-folder/
├── app.R              # Main Shiny application file
├── dag_data.R         # DAG data configuration file
├── README.md          # This file
└── example_data/      # (Optional) Example DAG data files
```

## Prerequisites

Make sure you have R installed on your system. You can download it from [https://cran.r-project.org/](https://cran.r-project.org/).

## Required R Packages

Install the required packages by running the following commands in your R console:

```r
# Install required packages
install.packages(c(
    "shiny",
    "shinydashboard",
    "visNetwork",
    "dplyr",
    "DT"
))

# Optional packages for advanced DAG processing
install.packages(c(
    "SEMgraph",
    "dagitty",
    "igraph"
))
```

**Note**: The application will work with basic functionality even if `SEMgraph`, `dagitty`, and `igraph` are not installed, but these packages provide enhanced DAG processing capabilities.

## Data Configuration

### Using Your Own DAG Files

The application now provides a flexible file loading system through the user interface:

#### Method 1: Place Files in App Directory (Recommended)

1. **Create your DAG file** (e.g., `graph.R`, `my_dag.R`, etc.)
2. **Place it in the same directory** as the app files
3. **Go to the "Data Upload" tab** in the app
4. **Click "Refresh File List"** to scan for available files
5. **Select your file** from the dropdown
6. **Click "Load Selected DAG"**

#### Method 2: Upload Through the Interface

1. **Go to the "Data Upload" tab** in the app
2. **Use the file upload interface** to select your R file
3. **Click "Upload & Load"** to upload and immediately load the DAG

#### DAG File Format

Your R file should contain a dagitty graph definition with the variable name `g`:

```r
# Your DAG file (e.g., graph.R)
g <- dagitty('dag {
    Variable1 [exposure]
    Variable2 [outcome]
    Variable3
    Variable4
    # ... as many variables as needed
    
    Variable1 -> Variable2
    Variable2 -> Variable3
    Variable3 -> Variable4
    # ... as many relationships as needed
}')
```

#### Auto-Detection Features

The application automatically:
- **Scans for DAG files** in the app directory
- **Validates file contents** for dagitty syntax
- **Loads default files** (graph.R, my_dag.R, dag.R) if available
- **Provides status updates** on the Data Upload tab

### Using the Large Graph Example

To use the large graph you provided:

1. **Replace the DAG definition** in `dag_data.R`:
   ```r
   g <- dagitty('dag {
   Hypertension [exposure]
   Alzheimers_Disease [outcome]
   Surgical_margins
   PeptidylDipeptidase_A
   # ... paste all your nodes here
   
   Triglycerides -> Hypertensive_disease
   Mutation -> Neurodegenerative_Disorders
   # ... paste all your edges here
   }')
   ```

2. **The application will automatically**:
   - Process all nodes and edges
   - Categorize nodes into medical/biological categories:
     - **Exposure/Outcome**: Primary variables
     - **Cancer**: Cancer-related terms
     - **Cardiovascular**: Heart and vascular diseases
     - **Neurological**: Brain and nervous system
     - **Renal**: Kidney-related
     - **Metabolic**: Diabetes, obesity, metabolism
     - **Immune/Inflammatory**: Immune system and inflammation
     - **Treatment**: Drugs and therapies
     - **Molecular**: Genes, proteins, enzymes
     - **Surgical**: Surgical procedures
     - **Oxidative Stress**: Oxidative stress markers
     - **Other**: Everything else

3. **Performance optimizations for large graphs**:
   - Smaller font sizes for better visibility
   - Thinner edge lines
   - Efficient color assignment
   - Progress indicators during processing

### Node Categories and Colors

The application automatically categorizes nodes based on naming patterns:

- **Exposure** (Bright Red): Variables marked as [exposure]
- **Outcome** (Red): Variables marked as [outcome]  
- **Cancer** (Dark Red): Cancer and tumor-related terms
- **Cardiovascular** (Crimson): Heart and vascular diseases
- **Neurological** (Royal Blue): Brain and nervous system
- **Renal** (Light Sea Green): Kidney-related terms
- **Metabolic** (Dark Orange): Diabetes, obesity, metabolism
- **Immune/Inflammatory** (Lime Green): Immune system and inflammation
- **Treatment** (Medium Purple): Drugs and therapies
- **Molecular** (Dark Turquoise): Genes, proteins, enzymes
- **Surgical** (Deep Pink): Surgical procedures
- **Oxidative Stress** (Gold): Oxidative stress markers
- **Other** (Gray): Everything else

You can customize these categories by modifying the `categorize_node` function in `dag_data.R`.

## Installation and Running

1. **Download the files** to your local machine:
   - `app.R` (main application)
   - `dag_data.R` (data configuration)

2. **Set working directory** to the folder containing both files

3. **Run the application** using one of these methods:

   **Method 1: Using RStudio**
   ```r
   # Open app.R in RStudio
   # Click the "Run App" button
   ```

   **Method 2: Using R Console**
   ```r
   # Set working directory to the app folder
   setwd("path/to/your/app/folder")
   
   # Run the app
   shiny::runApp("app.R")
   ```

   **Method 3: Direct execution**
   ```r
   # If you're in the correct directory
   source("app.R")
   ```

4. **Access the application** - The app will open in your browser at `http://127.0.0.1:XXXX`

## Usage Instructions

### Main Features

1. **DAG Visualization Tab**
   - Interactive network diagram with your DAG structure
   - Drag nodes to reposition them
   - Zoom with mouse wheel
   - Click nodes to select and view details
   - Adjust physics parameters with sliders
   - **Reload DAG Data** button to refresh from dag_data.R

2. **Node Information Tab**
   - Detailed information about selected nodes
   - Searchable table of all nodes
   - Node metadata and properties

3. **Statistics Tab**
   - Network statistics (nodes, edges, groups)
   - Node distribution charts
   - DAG structure information

4. **Data Upload Tab**
   - Instructions for modifying DAG data
   - Example data structure
   - Guidelines for creating custom DAGs

### Controls

- **Physics Strength**: Adjust gravitational force between nodes (-500 to -50)
- **Spring Length**: Control preferred distance between connected nodes (100 to 400)
- **Reset Physics**: Return to default layout settings
- **Reload DAG Data**: Refresh data from dag_data.R file

### Customizing Your DAG

1. **Edit dag_data.R** with your own data structure
2. **Click "Reload DAG Data"** in the application
3. **No need to restart** the application

#### Node Categories and Colors

The application automatically categorizes nodes based on naming patterns:

- **Primary**: Exposure and outcome variables (red)
- **Biological_Process**: Biological mechanisms (teal)
- **Neural**: Neural-related factors (blue)
- **Molecular**: Molecular markers (green)
- **Disease**: Related diseases (pink)
- **Treatment**: Drugs and treatments (coral)
- **Other**: Other factors (gray)

You can customize these categories by modifying the `categorize_node` function in `dag_data.R`.

## Advanced Usage

### Creating DAGs from dagitty

If you have a dagitty object, you can use the provided helper function:

```r
# In your dag_data.R file
library(dagitty)

# Define your DAG
g <- dagitty('dag {
    X [exposure]
    Y [outcome]
    Z
    X -> Z -> Y
}')

# Use the helper function
network_data <- create_network_data(g)
dag_nodes <- network_data$nodes
dag_edges <- network_data$edges
dag_object <- g
```

### Custom Node Categorization

Modify the `categorize_node` function in `dag_data.R` to create custom categories:

```r
categorize_node <- function(node_name) {
    if (node_name %in% c("MyExposure", "MyOutcome")) {
        return("Primary")
    } else if (grepl("treatment", node_name, ignore.case = TRUE)) {
        return("Treatment")
    } else {
        return("Other")
    }
}
```

## Troubleshooting

### Common Issues

1. **"Could not load dag_data.R"**
   - Ensure `dag_data.R` is in the same directory as `app.R`
   - Check that the file contains `dag_nodes` and `dag_edges` variables
   - Verify the data frame structures match the requirements

2. **"Missing node/edge columns"**
   - Check that your data frames have the required columns
   - The application will attempt to add missing optional columns with defaults

3. **Network not displaying**
   - Ensure `dag_edges` has 'from' and 'to' columns
   - Check that node IDs in edges match those in nodes
   - Verify there are no circular references

4. **Package installation errors**
   - Install packages one by one to identify issues
   - SEMgraph, dagitty, and igraph are optional for basic functionality

### Data Validation

The application includes built-in data validation that will:
- Check for required columns
- Add missing optional columns with defaults
- Display warnings for data issues
- Provide fallback data if loading fails

## Examples

### Simple Three-Node DAG

```r
# dag_data.R
dag_nodes <- data.frame(
    id = c("A", "B", "C"),
    label = c("Variable A", "Variable B", "Variable C"),
    group = c("Primary", "Mediator", "Outcome"),
    color = c("#FF6B6B", "#4ECDC4", "#45B7D1"),
    stringsAsFactors = FALSE
)

dag_edges <- data.frame(
    from = c("A", "B"),
    to = c("B", "C"),
    stringsAsFactors = FALSE
)
```

### Complex Medical DAG

```r
# dag_data.R with medical variables
dag_nodes <- data.frame(
    id = c("Hypertension", "Diabetes", "Stroke", "Age", "BMI"),
    label = c("Hypertension", "Diabetes", "Stroke", "Age", "BMI"),
    group = c("Disease", "Disease", "Outcome", "Demographic", "Risk_Factor"),
    color = c("#D4A5A5", "#D4A5A5", "#FF6B6B", "#A9B7C0", "#FFA07A"),
    stringsAsFactors = FALSE
)

dag_edges <- data.frame(
    from = c("Age", "BMI", "Hypertension", "Diabetes"),
    to = c("Hypertension", "Diabetes", "Stroke", "Stroke"),
    stringsAsFactors = FALSE
)
```

## Support

For issues or questions:
1. Check that all required files are in the correct directory
2. Verify your dag_data.R file structure matches the requirements
3. Check the R console for detailed error messages
4. Use the "Reload DAG Data" button after making changes

## License

This application is provided as-is for educational and research purposes.