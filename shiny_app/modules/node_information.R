# Node Information Module
# This module contains functions for managing, processing, and displaying node data and metadata
# Author: Refactored from original dag_data.R and app.R
# Dependencies: dplyr, dagitty, igraph

# Required libraries for this module
if (!require(dplyr)) stop("dplyr package is required")
if (!require(dagitty)) stop("dagitty package is required")
if (!require(igraph)) stop("igraph package is required")

#' Enhanced Node Categorization Function
#' 
#' Categorizes nodes based on their names and DAG properties (exposure/outcome)
#' 
#' @param node_name Name of the node to categorize
#' @param dag_object dagitty object containing the DAG
#' @return String representing the node category
#' @export
categorize_node <- function(node_name, dag_object = NULL) {
    # Extract exposure and outcome from dagitty object if available
    exposures <- character(0)
    outcomes <- character(0)
    
    if (!is.null(dag_object)) {
        exposures <- tryCatch(exposures(dag_object), error = function(e) character(0))
        outcomes <- tryCatch(outcomes(dag_object), error = function(e) character(0))
    }
    
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

#' Get Node Color Scheme
#' 
#' Returns the color scheme mapping for different node categories
#' 
#' @return Named list of colors for each category
#' @export
get_node_color_scheme <- function() {
    return(list(
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
    ))
}

#' Create Nodes Data Frame
#' 
#' Creates a properly formatted nodes data frame from DAG object
#' 
#' @param dag_object dagitty object containing the DAG
#' @return Data frame with node information including id, label, group, and color
#' @export
create_nodes_dataframe <- function(dag_object) {
    if (is.null(dag_object)) {
        # Return minimal fallback data
        return(data.frame(
            id = c("Node1", "Node2"),
            label = c("Node 1", "Node 2"),
            group = c("Other", "Other"),
            color = c("#808080", "#808080"),
            font.size = 14,
            font.color = "black",
            stringsAsFactors = FALSE
        ))
    }
    
    # Get all node names from the DAG
    all_nodes <- names(dag_object)
    
    if (length(all_nodes) == 0) {
        return(data.frame(
            id = character(0),
            label = character(0),
            group = character(0),
            color = character(0),
            font.size = numeric(0),
            font.color = character(0),
            stringsAsFactors = FALSE
        ))
    }
    
    # Create nodes dataframe
    nodes <- data.frame(
        id = all_nodes,
        label = gsub("_", " ", all_nodes),
        stringsAsFactors = FALSE
    )
    
    # Apply categorization with progress indication for large graphs
    if (nrow(nodes) > 100) {
        cat("Processing", nrow(nodes), "nodes for categorization...\n")
    }
    
    nodes$group <- sapply(nodes$id, function(x) categorize_node(x, dag_object))
    
    # Add node properties
    nodes$font.size <- 14  # Smaller font for large graphs
    nodes$font.color <- "black"
    
    # Get color scheme and assign colors
    color_scheme <- get_node_color_scheme()
    nodes$color <- sapply(nodes$group, function(g) {
        if (g %in% names(color_scheme)) {
            return(color_scheme[[g]])
        } else {
            return("#808080")  # Default gray
        }
    })
    
    return(nodes)
}

#' Validate Node Data
#' 
#' Validates and fixes node data structure
#' 
#' @param nodes Data frame containing node information
#' @return Validated and corrected nodes data frame
#' @export
validate_node_data <- function(nodes) {
    # Validate nodes
    required_node_cols <- c("id", "label", "group", "color")
    missing_node_cols <- setdiff(required_node_cols, names(nodes))
    
    if (length(missing_node_cols) > 0) {
        warning(paste("Missing node columns:", paste(missing_node_cols, collapse = ", ")))
        # Add missing columns with defaults
        if (!"id" %in% names(nodes)) stop("Node 'id' column is required")
        if (!"label" %in% names(nodes)) nodes$label <- nodes$id
        if (!"group" %in% names(nodes)) nodes$group <- "Other"
        if (!"color" %in% names(nodes)) nodes$color <- "#A9B7C0"
    }
    
    # Add optional columns if missing
    if (!"font.size" %in% names(nodes)) nodes$font.size <- 16
    if (!"font.color" %in% names(nodes)) nodes$font.color <- "black"
    
    return(nodes)
}

#' Get Node Summary Statistics
#' 
#' Generates summary statistics for nodes
#' 
#' @param nodes_df Data frame containing node information
#' @return List containing various node statistics
#' @export
get_node_summary <- function(nodes_df) {
    if (is.null(nodes_df) || nrow(nodes_df) == 0) {
        return(list(
            total_nodes = 0,
            total_groups = 0,
            group_counts = data.frame(),
            primary_nodes = character(0)
        ))
    }
    
    group_counts <- nodes_df %>%
        group_by(group) %>%
        summarise(count = n(), .groups = 'drop') %>%
        arrange(desc(count))
    
    primary_nodes <- nodes_df[nodes_df$group %in% c("Exposure", "Outcome"), ]
    
    return(list(
        total_nodes = nrow(nodes_df),
        total_groups = length(unique(nodes_df$group)),
        group_counts = group_counts,
        primary_nodes = primary_nodes$label
    ))
}

#' Create Nodes Table for Display
#' 
#' Prepares node data for display in data tables
#' 
#' @param nodes_df Data frame containing node information
#' @return Data frame formatted for display
#' @export
create_nodes_display_table <- function(nodes_df) {
    if (is.null(nodes_df) || nrow(nodes_df) == 0) {
        return(data.frame(
            ID = character(0),
            Label = character(0),
            Group = character(0),
            stringsAsFactors = FALSE
        ))
    }
    
    display_table <- nodes_df[, c("id", "label", "group")]
    names(display_table) <- c("ID", "Label", "Group")
    
    return(display_table)
}

#' Get Available Node Categories
#' 
#' Returns all available node categories with descriptions
#' 
#' @return Data frame with category names and descriptions
#' @export
get_node_categories_info <- function() {
    return(data.frame(
        Category = c("Exposure", "Outcome", "Cancer", "Cardiovascular", "Neurological", 
                    "Renal", "Metabolic", "Immune_Inflammatory", "Treatment", 
                    "Molecular", "Surgical", "Oxidative_Stress", "Other"),
        Description = c(
            "Variables marked as exposure in the DAG",
            "Variables marked as outcome in the DAG",
            "Cancer-related variables and conditions",
            "Cardiovascular system related variables",
            "Neurological and brain-related variables",
            "Kidney and renal system variables",
            "Metabolic processes and conditions",
            "Immune system and inflammatory processes",
            "Treatments, drugs, and therapeutic interventions",
            "Molecular, genetic, and protein-related variables",
            "Surgical procedures and interventions",
            "Oxidative stress and related processes",
            "Variables that don't fit other categories"
        ),
        Color = unlist(get_node_color_scheme()),
        stringsAsFactors = FALSE
    ))
}
