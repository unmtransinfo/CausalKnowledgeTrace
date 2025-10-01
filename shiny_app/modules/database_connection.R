# Database Connection Module for CausalKnowledgeTrace
#
# This module provides database connectivity for the Shiny application
# to query the cui_search table for CUI search functionality.
#
# Author: CausalKnowledgeTrace Application
# Dependencies: DBI, RPostgreSQL, pool

# Required libraries with error handling
# Try RPostgres first (more modern), fallback to RPostgreSQL if needed
postgres_driver <- NULL
required_base_packages <- c("DBI", "pool")

for (pkg in required_base_packages) {
    if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
        message(paste("Installing", pkg, "package..."))
        install.packages(pkg)
        library(pkg, character.only = TRUE)
    }
}

# Try to load PostgreSQL driver
tryCatch({
    if (!require("RPostgres", character.only = TRUE, quietly = TRUE)) {
        message("Installing RPostgres package...")
        install.packages("RPostgres")
        library(RPostgres)
    }
    postgres_driver <- RPostgres::Postgres()
    cat("Using RPostgres driver\n")
}, error = function(e) {
    cat("RPostgres not available, trying RPostgreSQL...\n")
    tryCatch({
        if (!require("RPostgreSQL", character.only = TRUE, quietly = TRUE)) {
            message("Installing RPostgreSQL package...")
            install.packages("RPostgreSQL")
            library(RPostgreSQL)
        }
        postgres_driver <- RPostgreSQL::PostgreSQL()
        cat("Using RPostgreSQL driver\n")
    }, error = function(e2) {
        cat("Warning: No PostgreSQL driver available. Database functionality will be limited.\n")
        cat("Error with RPostgres:", e$message, "\n")
        cat("Error with RPostgreSQL:", e2$message, "\n")
        postgres_driver <- NULL
    })
})

# Global connection pool
.db_pool <- NULL

#' Initialize Database Connection Pool
#' 
#' Creates a connection pool to the PostgreSQL database using environment variables
#' or default configuration
#' 
#' @param host Database host (default: localhost)
#' @param port Database port (default: 5432)
#' @param dbname Database name (default: causalehr)
#' @param user Database user
#' @param password Database password
#' @param schema Database schema (default: causalehr)
#' @param min_size Minimum pool size (default: 1)
#' @param max_size Maximum pool size (default: 5)
#' @return List with success status and connection pool
#' @export
init_database_pool <- function(host = NULL, port = NULL, dbname = NULL, 
                              user = NULL, password = NULL, schema = NULL,
                              min_size = 1, max_size = 5) {
    
    tryCatch({
        # Load .env file if it exists
        env_file <- file.path(getwd(), "..", ".env")
        if (file.exists(env_file)) {
            cat("Loading database configuration from .env file\n")
            env_vars <- readLines(env_file)
            for (line in env_vars) {
                line <- trimws(line)
                if (grepl("^[A-Z_]+=", line) && !grepl("^#", line)) {
                    parts <- strsplit(line, "=", fixed = TRUE)[[1]]
                    if (length(parts) >= 2) {
                        var_name <- trimws(parts[1])
                        var_value <- trimws(paste(parts[-1], collapse = "="))
                        # Set environment variable properly
                        do.call(Sys.setenv, setNames(list(var_value), var_name))
                        cat("  Set", var_name, "=", var_value, "\n")
                    }
                }
            }
        }

        # Try to read from environment variables first
        if (is.null(host)) host <- Sys.getenv("DB_HOST", "localhost")
        if (is.null(port)) port <- as.integer(Sys.getenv("DB_PORT", "5432"))
        if (is.null(dbname)) dbname <- Sys.getenv("DB_NAME", "causalehr")
        if (is.null(user)) user <- Sys.getenv("DB_USER", "")
        if (is.null(password)) password <- Sys.getenv("DB_PASSWORD", "")
        if (is.null(schema)) schema <- Sys.getenv("DB_SCHEMA", "public")

        # Fallback to working values if environment variables are not set
        if (user == "") user <- "rajesh"
        if (password == "") password <- ""
        if (host == "localhost" && password == "") {
            # Use Unix socket for peer authentication when no password
            host <- "/var/run/postgresql"
        }
        
        # Check if PostgreSQL driver is available
        if (is.null(postgres_driver)) {
            return(list(
                success = FALSE,
                message = "No PostgreSQL driver available. Please install RPostgres or RPostgreSQL package and ensure PostgreSQL development headers are installed."
            ))
        }

        # Validate required parameters
        if (user == "") {
            return(list(
                success = FALSE,
                message = "Database user is required. Set DB_USER environment variable."
            ))
        }

        # Create connection pool
        .db_pool <<- pool::dbPool(
            drv = postgres_driver,
            host = host,
            port = port,
            dbname = dbname,
            user = user,
            password = password,
            minSize = min_size,
            maxSize = max_size
        )
        
        # Test connection
        test_conn <- pool::poolCheckout(.db_pool)
        
        # Set schema if specified
        if (!is.null(schema) && schema != "") {
            DBI::dbExecute(test_conn, paste("SET search_path TO", schema))
        }
        
        # Test query to verify cui_search table access
        test_query <- "SELECT COUNT(*) FROM causalehr.cui_search LIMIT 1"
        result <- DBI::dbGetQuery(test_conn, test_query)
        
        pool::poolReturn(test_conn)
        
        cat("Database connection pool initialized successfully\n")
        cat("Host:", host, "Port:", port, "Database:", dbname, "Schema:", schema, "\n")
        cat("Pool size:", min_size, "-", max_size, "connections\n")
        
        return(list(
            success = TRUE,
            message = "Database connection pool initialized successfully",
            pool = .db_pool,
            config = list(
                host = host,
                port = port,
                dbname = dbname,
                schema = schema
            )
        ))
        
    }, error = function(e) {
        return(list(
            success = FALSE,
            message = paste("Failed to initialize database connection:", e$message),
            error = e
        ))
    })
}

#' Close Database Connection Pool
#' 
#' Closes the database connection pool
#' 
#' @export
close_database_pool <- function() {
    if (!is.null(.db_pool)) {
        tryCatch({
            pool::poolClose(.db_pool)
            .db_pool <<- NULL
            cat("Database connection pool closed\n")
        }, error = function(e) {
            cat("Error closing database pool:", e$message, "\n")
        })
    }
}

#' Get Database Connection
#' 
#' Gets a connection from the pool (for internal use)
#' 
#' @return Database connection or NULL if pool not initialized
get_db_connection <- function() {
    if (is.null(.db_pool)) {
        warning("Database pool not initialized. Call init_database_pool() first.")
        return(NULL)
    }
    return(.db_pool)
}

#' Search CUI Entities
#'
#' Searches the cui_search table for medical concepts matching the search term
#' Returns ALL matching results (no limit)
#'
#' @param search_term Character string to search for in concept names
#' @param exact_match Whether to perform exact matching (default: FALSE)
#' @return List with success status and search results
#' @export
search_cui_entities <- function(search_term, exact_match = FALSE) {

    if (is.null(.db_pool)) {
        return(list(
            success = FALSE,
            message = "Database connection not initialized. Call init_database_pool() first.",
            results = data.frame(cui = character(0), name = character(0), semtype = character(0), semtype_defination = character(0))
        ))
    }
    
    if (is.null(search_term) || nchar(trimws(search_term)) == 0) {
        return(list(
            success = TRUE,
            message = "Empty search term",
            results = data.frame(cui = character(0), name = character(0), semtype = character(0), semtype_defination = character(0))
        ))
    }
    
    tryCatch({
        # Clean and prepare search term
        clean_term <- trimws(search_term)
        
        # Build query based on match type - NO LIMIT to show all results
        # Now using the optimized cui_search table for faster searches
        if (exact_match) {
            query <- "SELECT DISTINCT cui, name, semtype, semtype_defination FROM causalehr.cui_search WHERE LOWER(name) = LOWER($1) ORDER BY name"
            params <- list(clean_term)
        } else {
            # Use DISTINCT for unique results and case-insensitive partial matching
            search_pattern <- paste0("%", clean_term, "%")
            query <- "SELECT DISTINCT cui, name, semtype, semtype_defination FROM causalehr.cui_search WHERE LOWER(name) LIKE LOWER($1) ORDER BY name"
            params <- list(search_pattern)
        }

        # Log the SQL query being executed
        cat("🔍 Executing SQL Query (using cui_search):\n")
        cat("Query:", query, "\n")
        cat("Parameters:", paste(params, collapse = ", "), "\n")
        cat("Search term:", search_term, "-> Pattern:", if(exact_match) clean_term else search_pattern, "\n")
        cat("Expected to return ALL matching results (no limit)\n")

        # Execute query
        results <- pool::dbGetQuery(.db_pool, query, params = params)
        
        # Ensure consistent column names and types
        if (nrow(results) > 0) {
            results$cui <- as.character(results$cui)
            results$name <- as.character(results$name)
            results$semtype <- as.character(results$semtype)
            results$semtype_defination <- as.character(results$semtype_defination)
        } else {
            results <- data.frame(
                cui = character(0),
                name = character(0),
                semtype = character(0),
                semtype_defination = character(0),
                stringsAsFactors = FALSE
            )
        }
        
        return(list(
            success = TRUE,
            message = paste("Found", nrow(results), "results"),
            results = results,
            search_term = clean_term,
            total_results = nrow(results)
        ))
        
    }, error = function(e) {
        return(list(
            success = FALSE,
            message = paste("Database query error:", e$message),
            results = data.frame(cui = character(0), name = character(0), semtype = character(0), semtype_defination = character(0)),
            error = e
        ))
    })
}

#' Get CUI Details
#'
#' Retrieves detailed information for specific CUI codes
#'
#' @param cui_codes Character vector of CUI codes to look up
#' @return List with success status and CUI details
#' @export
get_cui_details <- function(cui_codes) {

    if (is.null(.db_pool)) {
        return(list(
            success = FALSE,
            message = "Database connection not initialized. Call init_database_pool() first.",
            results = data.frame(cui = character(0), name = character(0), semtype = character(0), semtype_defination = character(0))
        ))
    }

    if (is.null(cui_codes) || length(cui_codes) == 0) {
        return(list(
            success = TRUE,
            message = "No CUI codes provided",
            results = data.frame(cui = character(0), name = character(0), semtype = character(0), semtype_defination = character(0))
        ))
    }

    tryCatch({
        # Clean CUI codes
        clean_cuis <- trimws(cui_codes)
        clean_cuis <- clean_cuis[clean_cuis != ""]

        if (length(clean_cuis) == 0) {
            return(list(
                success = TRUE,
                message = "No valid CUI codes provided",
                results = data.frame(cui = character(0), name = character(0), semtype = character(0), semtype_defination = character(0))
            ))
        }

        # Create placeholders for parameterized query
        placeholders <- paste(rep("$", length(clean_cuis)), 1:length(clean_cuis), sep = "", collapse = ",")
        query <- paste("SELECT DISTINCT cui, name, semtype, semtype_defination FROM causalehr.cui_search WHERE cui IN (", placeholders, ") ORDER BY name")

        # Execute query
        results <- pool::dbGetQuery(.db_pool, query, params = as.list(clean_cuis))

        # Ensure consistent column names and types
        if (nrow(results) > 0) {
            results$cui <- as.character(results$cui)
            results$name <- as.character(results$name)
            results$semtype <- as.character(results$semtype)
            results$semtype_defination <- as.character(results$semtype_defination)
        } else {
            results <- data.frame(
                cui = character(0),
                name = character(0),
                semtype = character(0),
                semtype_defination = character(0),
                stringsAsFactors = FALSE
            )
        }

        return(list(
            success = TRUE,
            message = paste("Found", nrow(results), "of", length(clean_cuis), "requested CUIs"),
            results = results,
            requested_cuis = clean_cuis,
            found_count = nrow(results)
        ))

    }, error = function(e) {
        return(list(
            success = FALSE,
            message = paste("Database query error:", e$message),
            results = data.frame(cui = character(0), name = character(0), semtype = character(0), semtype_defination = character(0)),
            error = e
        ))
    })
}

#' Validate CUI Format
#'
#' Validates that CUI codes follow the expected format (C followed by 7 digits)
#'
#' @param cui_codes Character vector of CUI codes to validate
#' @return List with validation results
#' @export
validate_cui_format <- function(cui_codes) {

    if (is.null(cui_codes) || length(cui_codes) == 0) {
        return(list(
            valid = TRUE,
            message = "No CUI codes to validate",
            valid_cuis = character(0),
            invalid_cuis = character(0)
        ))
    }

    # Clean and split CUI codes
    clean_cuis <- trimws(unlist(strsplit(paste(cui_codes, collapse = ","), ",")))
    clean_cuis <- clean_cuis[clean_cuis != ""]

    if (length(clean_cuis) == 0) {
        return(list(
            valid = TRUE,
            message = "No valid CUI codes provided",
            valid_cuis = character(0),
            invalid_cuis = character(0)
        ))
    }

    # CUI format: C followed by 7 digits
    cui_pattern <- "^C[0-9]{7}$"

    valid_cuis <- clean_cuis[grepl(cui_pattern, clean_cuis)]
    invalid_cuis <- clean_cuis[!grepl(cui_pattern, clean_cuis)]

    is_valid <- length(invalid_cuis) == 0

    message <- if (is_valid) {
        paste("All", length(valid_cuis), "CUI codes are valid")
    } else {
        paste("Found", length(invalid_cuis), "invalid CUI codes:", paste(invalid_cuis, collapse = ", "))
    }

    return(list(
        valid = is_valid,
        message = message,
        valid_cuis = valid_cuis,
        invalid_cuis = invalid_cuis,
        total_count = length(clean_cuis),
        valid_count = length(valid_cuis),
        invalid_count = length(invalid_cuis)
    ))
}

#' Test Database Connection
#'
#' Tests the database connection and cui_search table access
#'
#' @return List with test results
#' @export
test_database_connection <- function() {

    if (is.null(.db_pool)) {
        return(list(
            success = FALSE,
            message = "Database connection pool not initialized"
        ))
    }

    tryCatch({
        # Test basic connection
        test_conn <- pool::poolCheckout(.db_pool)

        # Test cui_search table access
        count_query <- "SELECT COUNT(*) as total_entities FROM causalehr.cui_search"
        count_result <- DBI::dbGetQuery(test_conn, count_query)

        # Test sample query
        sample_query <- "SELECT DISTINCT cui, name, semtype, semtype_defination FROM causalehr.cui_search LIMIT 5"
        sample_result <- DBI::dbGetQuery(test_conn, sample_query)

        pool::poolReturn(test_conn)

        return(list(
            success = TRUE,
            message = "Database connection test successful",
            total_entities = count_result$total_entities[1],
            sample_entities = sample_result
        ))

    }, error = function(e) {
        return(list(
            success = FALSE,
            message = paste("Database connection test failed:", e$message),
            error = e
        ))
    })
}


