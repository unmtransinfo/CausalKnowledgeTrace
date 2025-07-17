# DAG Data Configuration File
# This file contains the DAG structure and can be easily modified
# Replace the 'g' variable with your own dagitty graph

library(SEMgraph)
library(dagitty)
library(igraph)
library(visNetwork)
library(dplyr)

# DYNAMIC DAG LOADING SYSTEM
# This system allows users to load DAG files through the UI

# Initialize variables
g <- NULL
dag_loaded_from <- "default"
available_dag_files <- character(0)

# Function to scan for available DAG files
scan_for_dag_files <- function() {
    # Look for R files that might contain DAG definitions
    r_files <- list.files(pattern = "\\.(R|r)$", full.names = FALSE)
    
    # Filter out system files
    dag_files <- r_files[!r_files %in% c("app.R", "dag_data.R")]
    
    # Check if files contain dagitty definitions
    valid_dag_files <- c()
    
    for (file in dag_files) {
        if (file.exists(file)) {
            tryCatch({
                # Read first few lines to check for dagitty syntax
                lines <- readLines(file, n = 50, warn = FALSE)
                content <- paste(lines, collapse = " ")
                
                # Check for dagitty syntax
                if (grepl("dagitty\\s*\\(", content, ignore.case = TRUE) || 
                    grepl("dag\\s*\\{", content, ignore.case = TRUE)) {
                    valid_dag_files <- c(valid_dag_files, file)
                }
            }, error = function(e) {
                # Skip files that can't be read
            })
        }
    }
    
    return(valid_dag_files)
}

# Function to load DAG from specified file
load_dag_from_file <- function(filename) {
    if (!file.exists(filename)) {
        return(list(success = FALSE, message = paste("File", filename, "not found")))
    }
    
    tryCatch({
        # Clear existing g variable
        if (exists("g", envir = .GlobalEnv)) {
            rm(g, envir = .GlobalEnv)
        }
        
        # Source the file
        source(filename, local = TRUE)
        
        # Check if g variable was created
        if (exists("g") && !is.null(g)) {
            return(list(success = TRUE, message = paste("Successfully loaded DAG from", filename), dag = g))
        } else {
            return(list(success = FALSE, message = paste("No 'g' variable found in", filename)))
        }
    }, error = function(e) {
        return(list(success = FALSE, message = paste("Error loading", filename, ":", e$message)))
    })
}

# Scan for available DAG files
available_dag_files <- scan_for_dag_files()

# Try to load default file if available
default_files <- c("graph.R", "my_dag.R", "dag.R")
loaded_successfully <- FALSE

for (default_file in default_files) {
    if (default_file %in% available_dag_files) {
        result <- load_dag_from_file(default_file)
        if (result$success) {
            g <- result$dag
            dag_loaded_from <- default_file
            loaded_successfully <- TRUE
            cat("Auto-loaded DAG from", default_file, "\n")
            break
        }
    }
}

# If no default file worked, create a simple fallback
if (!loaded_successfully) {
    cat("No DAG files found. Using default example.\n")
    cat("Available DAG files detected:", if(length(available_dag_files) > 0) paste(available_dag_files, collapse = ", ") else "None", "\n")
    
    g <- dagitty('dag {
    Hypertension [exposure]
    Alzheimers_Disease [outcome]
    Surgical_margins
    PeptidylDipeptidase_A
    TP73ARHGAP24
    Diarrhea
    Superoxides
    Neurohormones
    Cocaine
    Induction
    Excessive_daytime_somnolence
    resistance_education
    Fibromuscular_Dysplasia
    genotoxicity
    Pancreatic_Ductal_Adenocarcinoma
    Gadolinium
    Inspiration_function
    Ataxia_Telangiectasia
    Myocardial_Infarction
    Alteplase
    3MC
    donepezil
    Ovarian_Carcinoma
    semaglutide
    Heart_failure
    Mandibular_Advancement_Devices
    Cerebrovascular_accident
    Allelic_Imbalance
    Sickle_Cell_Anemia
    Cerebral_Infarction
    Mitral_Valve_Insufficiency
    Stents
    Behavioral_and_psychological_symptoms_of_dementia
    Sedation
    Adrenergic_Antagonists
    Hereditary_Diseases
    tau_Proteins
    Norepinephrine
    Substance_P
    Senile_Plaques
    Myopathy

    Triglycerides -> Hypertensive_disease
    Mutation -> Neurodegenerative_Disorders
    Screening_procedure -> Kidney_Diseases
    }')
    
    dag_loaded_from <- "default"
}

# Enhanced function to create nodes and edges from any DAG
create_network_data <- function(dag_object) {
    # Convert DAG to igraph with error handling
    tryCatch({
        ig <- dagitty2graph(dag_object)
    }, error = function(e) {
        cat("Error converting DAG to igraph:", e$message, "\n")
        # Create a simple fallback graph
        ig <- graph.empty(n = 0, directed = TRUE)
        return(list(nodes = data.frame(), edges = data.frame(), dag = dag_object))
    })
    
    # Get all node names from the DAG
    all_nodes <- names(dag_object)
    
    # Create nodes dataframe
    nodes <- data.frame(
        id = all_nodes,
        label = gsub("_", " ", all_nodes),
        stringsAsFactors = FALSE
    )
    
    # Enhanced categorization function that handles large graphs
    categorize_node <- function(node_name) {
        # Extract exposure and outcome from dagitty object
        exposures <- tryCatch(exposures(dag_object), error = function(e) character(0))
        outcomes <- tryCatch(outcomes(dag_object), error = function(e) character(0))
        
        # Convert to lowercase for pattern matching
        node_lower <- tolower(node_name)
        
        # Primary categories (exposure/outcome)
        if (length(exposures) > 0 && node_name %in% exposures) return("Exposure")
        if (length(outcomes) > 0 && node_name %in% outcomes) return("Outcome")
        
        # Medical/biological categories based on keywords
        if (grepl("(cancer|carcinoma|neoplasm|tumor|malignant|adenocarcinoma|lymphoma|sarcoma|melanoma|glioma|neuroblastoma)", node_lower)) {
            return("Cancer")
        } else if (grepl("(cardiovascular|heart|cardiac|myocardial|coronary|artery|vascular|blood_pressure|hypertension|stroke|infarction|bypass|angioplasty|thrombosis|embolism|atherosclerosis)", node_lower)) {
            return("Cardiovascular")
        } else if (grepl("(neuro|neural|brain|alzheim|dementia|parkinson|cognitive|memory|nerve|neural|cerebral|cerebrovascular|huntington|amyotrophic|multiple_sclerosis)", node_lower)) {
            return("Neurological")
        } else if (grepl("(kidney|renal|nephro|dialysis|glomerular|proteinuria|urinary|bladder)", node_lower)) {
            return("Renal")
        } else if (grepl("(diabetes|diabetic|insulin|glucose|hyperglycemia|metabolic|obesity|lipid|cholesterol|triglycerides)", node_lower)) {
            return("Metabolic")
        } else if (grepl("(inflammation|inflammatory|immune|autoimmune|infection|bacterial|viral|sepsis|pneumonia|tuberculosis|hepatitis)", node_lower)) {
            return("Immune_Inflammatory")
        } else if (grepl("(drug|medication|therapy|treatment|agent|inhibitor|antagonist|agonist|pharmaceutical)", node_lower)) {
            return("Treatment")
        } else if (grepl("(gene|genetic|mutation|protein|enzyme|receptor|molecular|dna|rna|chromosome)", node_lower)) {
            return("Molecular")
        } else if (grepl("(surgery|surgical|operation|procedure|transplant|bypass|resection|biopsy|excision)", node_lower)) {
            return("Surgical")
        } else if (grepl("(oxidative|stress|reactive|oxygen|free_radical|antioxidant|superoxide|peroxide|nitric_oxide)", node_lower)) {
            return("Oxidative_Stress")
        } else {
            return("Other")
        }
    }
    
    # Apply categorization with progress indication for large graphs
    if (nrow(nodes) > 100) {
        cat("Processing", nrow(nodes), "nodes for categorization...\n")
    }
    
    nodes$group <- sapply(nodes$id, categorize_node)
    
    # Add node properties
    nodes$font.size <- 14  # Smaller font for large graphs
    nodes$font.color <- "black"
    
    # Enhanced color scheme for medical/biological categories
    color_scheme <- list(
        Exposure = "#FF4444",           # Bright red for exposure
        Outcome = "#FF6B6B",            # Red for outcome
        Cancer = "#8B0000",             # Dark red for cancer
        Cardiovascular = "#DC143C",     # Crimson for cardiovascular
        Neurological = "#4169E1",       # Royal blue for neurological
        Renal = "#20B2AA",              # Light sea green for renal
        Metabolic = "#FF8C00",          # Dark orange for metabolic
        Immune_Inflammatory = "#32CD32", # Lime green for immune/inflammatory
        Treatment = "#9370DB",          # Medium purple for treatments
        Molecular = "#00CED1",          # Dark turquoise for molecular
        Surgical = "#FF1493",           # Deep pink for surgical
        Oxidative_Stress = "#FFD700",   # Gold for oxidative stress
        Other = "#808080"               # Gray for other
    )
    
    # Assign colors with fallback
    nodes$color <- sapply(nodes$group, function(g) {
        if (g %in% names(color_scheme)) {
            return(color_scheme[[g]])
        } else {
            return("#808080")  # Default gray
        }
    })
    
    # Create edges dataframe with error handling
    edges <- data.frame(
        from = character(0),
        to = character(0),
        arrows = character(0),
        smooth = logical(0),
        width = numeric(0),
        color = character(0),
        stringsAsFactors = FALSE
    )
    
    # Try to extract edges
    tryCatch({
        if (length(E(ig)) > 0) {
            edge_list <- get.edgelist(ig)
            if (nrow(edge_list) > 0) {
                edges <- data.frame(
                    from = edge_list[,1],
                    to = edge_list[,2],
                    arrows = "to",
                    smooth = TRUE,
                    width = 1,  # Thinner lines for large graphs
                    color = "#666666",
                    stringsAsFactors = FALSE
                )
            }
        }
    }, error = function(e) {
        cat("Warning: Could not extract edges from graph:", e$message, "\n")
    })
    
    # Print summary for large graphs
    if (nrow(nodes) > 50) {
        cat("Graph summary:\n")
        cat("- Nodes:", nrow(nodes), "\n")
        cat("- Edges:", nrow(edges), "\n")
        cat("- Node categories:", length(unique(nodes$group)), "\n")
        cat("- Categories:", paste(sort(unique(nodes$group)), collapse = ", "), "\n")
        cat("- Loaded from:", dag_loaded_from, "\n")
    }
    
    return(list(nodes = nodes, edges = edges, dag = dag_object))
}

# Function to handle very large graphs with memory optimization
process_large_dag <- function(dag_object, max_nodes = 1000) {
    all_nodes <- names(dag_object)
    
    # If graph is too large, provide option to sample or filter
    if (length(all_nodes) > max_nodes) {
        cat("Warning: Graph has", length(all_nodes), "nodes, which is quite large.\n")
        cat("Consider filtering the graph or increasing max_nodes parameter.\n")
        cat("Processing with current settings...\n")
    }
    
    # Use the standard processing function
    return(create_network_data(dag_object))
}

# Create the network data with error handling
tryCatch({
    network_data <- process_large_dag(g)
    
    # Export the data for the Shiny app
    dag_nodes <- network_data$nodes
    dag_edges <- network_data$edges
    dag_object <- network_data$dag
    
    # Validate the data
    if (nrow(dag_nodes) == 0) {
        warning("No nodes found in the DAG. Please check your dagitty syntax.")
        # Create minimal fallback data
        dag_nodes <- data.frame(
            id = c("Node1", "Node2"),
            label = c("Node 1", "Node 2"),
            group = c("Other", "Other"),
            color = c("#808080", "#808080"),
            font.size = 14,
            font.color = "black",
            stringsAsFactors = FALSE
        )
        dag_edges <- data.frame(
            from = "Node1",
            to = "Node2",
            arrows = "to",
            smooth = TRUE,
            width = 1,
            color = "#666666",
            stringsAsFactors = FALSE
        )
    }
    
    cat("Successfully processed DAG with", nrow(dag_nodes), "nodes and", nrow(dag_edges), "edges.\n")
    cat("DAG loaded from:", dag_loaded_from, "\n")
    
}, error = function(e) {
    cat("Error processing DAG:", e$message, "\n")
    cat("Creating minimal fallback data...\n")
    
    # Create minimal fallback data
    dag_nodes <- data.frame(
        id = c("Error", "Fallback"),
        label = c("Error Node", "Fallback Node"),
        group = c("Other", "Other"),
        color = c("#FF0000", "#808080"),
        font.size = 14,
        font.color = "black",
        stringsAsFactors = FALSE
    )
    
    dag_edges <- data.frame(
        from = "Error",
        to = "Fallback",
        arrows = "to",
        smooth = TRUE,
        width = 1,
        color = "#666666",
        stringsAsFactors = FALSE
    )
    
    dag_object <- NULL
})

# Clean up intermediate variables
rm(network_data)
if (exists("g")) {
    cat("DAG loaded successfully. You can now run the Shiny app.\n")
}