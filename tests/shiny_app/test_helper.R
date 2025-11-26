# Test Helper Functions
# Common utilities for shiny_app tests

#' Set Working Directory to shiny_app
#' 
#' This function ensures the working directory is set to the shiny_app directory
#' regardless of where the test is run from (tests/shiny_app/, tests/, or project root)
#' 
#' @return NULL (sets working directory as side effect)
set_shiny_app_wd <- function() {
    original_wd <- getwd()
    current_dir <- basename(getwd())
    parent_dir <- basename(dirname(getwd()))
    
    if (current_dir == "shiny_app" && parent_dir == "tests") {
        # Running from tests/shiny_app, go up two levels then into shiny_app
        setwd(file.path(dirname(dirname(getwd())), "shiny_app"))
    } else if (current_dir == "tests") {
        # Running from tests directory
        setwd(file.path(dirname(getwd()), "shiny_app"))
    } else if (current_dir == "shiny_app" && dir.exists("modules")) {
        # Already in the correct shiny_app directory
        # Do nothing
    } else {
        # Try to find and navigate to shiny_app directory
        if (dir.exists("shiny_app") && dir.exists("shiny_app/modules")) {
            setwd("shiny_app")
        } else if (dir.exists("../../shiny_app")) {
            setwd("../../shiny_app")
        } else {
            stop("Cannot find shiny_app directory with modules. Current dir: ", getwd())
        }
    }
    
    # Verify we're in the right place
    if (!dir.exists("modules")) {
        stop("Failed to navigate to shiny_app directory. Current dir: ", getwd())
    }
    
    invisible(NULL)
}

