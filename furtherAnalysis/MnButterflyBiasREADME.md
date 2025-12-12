# Butterfly Bias and M-Bias Analysis for Causal DAGs

## Overview

This R script provides tools for identifying the roles of third-factor variables, e.g., confounders, colliders, mediators, precision variables, instrumental variables, in the graph and for addressing two common sources of bias in causal inference from observational data: butterfly bias and M-bias. The functions analyze directed acyclic graphs (DAGs) representing causal relationships and generate adjustment sets that avoid bias introduced by inappropriate conditioning.

## Dependencies
```r
library(dagitty)
```

## Background

### Butterfly Bias

Butterfly bias is a form of sample selection bias that occurs when conditioning on a variable (the "butterfly node") that has two or more common causes, each of which is itself a confounder. Conditioning on the butterfly node can open spurious paths between the exposure and outcome, introducing bias even when adjusting for confounders.

**Example structure:**
```
C1 -> B <- C2
 |         |
 v         v
 A (?) ->  Y

 A <- C1 -> Y
 A <- B  -> Y
 A <- C2 -> Y
```
Where A is the exposure, Y is the outcome, C1 and C2 are confounders, and B is the butterfly node.

### M-Bias

M-bias occurs when a variable is a collider (has two or more parent nodes) on a backdoor path between exposure and outcome, but is not itself a descendant of either. Conditioning on such variables opens previously blocked paths, introducing bias. These variables should **not** be included in adjustment sets.

**Example structure:**
```
U1 -> C <- U2
 |         |
 v         v
 A         Y
```
Where C is the collider that should not be adjusted.

## Core Functions

### Helper Utilities

#### `validate_exposure_outcome(dag)`

Ensures the DAG has exactly one exposure and one outcome defined.

**Parameters:**
- `dag`: A dagitty DAG object

**Returns:**
- List with elements `exp` (exposure) and `out` (outcome)

**Throws:**
- Error if exposure or outcome is missing or multiply defined

---

#### `is_instrumental_variable(dag, candidate, exp, out)`

Tests whether a candidate variable is an instrumental variable by verifying that all paths from the candidate to the outcome flow through the exposure.

**Parameters:**
- `dag`: A dagitty DAG object
- `candidate`: Variable name to test
- `exp`: Exposure variable name
- `out`: Outcome variable name

**Returns:**
- Logical: `TRUE` if candidate is an instrumental variable, `FALSE` otherwise

---

#### `format_set(values)`

Formats a character vector as a set notation string for display.

**Parameters:**
- `values`: Character vector of variable names

**Returns:**
- String in format `"{ var1, var2, ... }"` or `"{ }"` for empty sets

---

### Role Identification

#### `identify_variable_roles(dag)`

Classifies all variables in the DAG according to their causal role relative to the exposure and outcome.

**Parameters:**
- `dag`: A dagitty DAG object with exposure and outcome defined

**Returns:**
List containing:
- `exp`: Exposure variable name
- `out`: Outcome variable name
- `dagitty_minimal_sets`: Minimal adjustment sets from dagitty
- `instrumental_variables`: Variables affecting only exposure (potential instruments)
- `precision_variables`: Variables affecting only outcome (increase precision but not required for unbiased estimation)
- `confounders`: Variables that are common causes of exposure and outcome
- `raw_colliders`: Variables that are descendants of both exposure and outcome
- `raw_mediators`: Variables on causal paths from exposure to outcome
- `colliders`: Refined collider classification excluding mediators and confounders
- `mediators`: Refined mediator classification excluding colliders and confounders

**Details:**

Variables are classified using ancestral and descendant relationships:
- **Instrumental variables**: Ancestors of exposure where all paths to outcome pass through exposure
- **Precision variables**: Ancestors of outcome but not exposure (excluding mediators)
- **Confounders**: Common ancestors of both exposure and outcome that appear in valid adjustment sets
- **Mediators**: On directed paths from exposure to outcome
- **Colliders**: Descendants of both exposure and outcome

---

### Butterfly Bias Analysis

#### `analyze_butterfly_bias(dag)`

Identifies butterfly bias structures and generates valid adjustment sets that avoid introducing this bias.

**Parameters:**
- `dag`: A dagitty DAG object with exposure and outcome defined

**Returns:**
List containing:
- `roles`: Output from `identify_variable_roles()`
- `butterfly_vars`: Confounders with two or more confounder parents
- `butterfly_parents`: Named list mapping each butterfly variable to its confounder parents
- `valid_sets`: List of valid minimal sufficient adjustment sets avoiding butterfly bias
- `non_butterfly_confounders`: Confounders that are not butterfly nodes or their parents

**Details:**

For each butterfly node B with parents P1, P2, ..., Pn, valid adjustment strategies include:
1. Adjust for all parents: {P1, P2, ..., Pn}
2. Adjust for the butterfly node plus a subset of parents: {B, P1}, {B, P2}, etc.

The function generates all valid combinations and removes duplicates.

---

### M-Bias Analysis

#### `analyze_m_bias(dag)`

Identifies M-bias structures where colliders on backdoor paths should not be adjusted.

**Parameters:**
- `dag`: A dagitty DAG object with exposure and outcome defined

**Returns:**
List containing:
- `exp`: Exposure variable name
- `out`: Outcome variable name
- `minimal_sets`: Minimal adjustment sets from dagitty
- `valid_adjustment_set`: First minimal adjustment set (recommended)
- `mbias_vars`: Variables that create M-bias if adjusted
- `mbias_details`: Named list with parents and paths for each M-bias variable

**Details:**

M-bias variables are identified as:
1. Having two or more parent nodes
2. Not appearing in any minimal adjustment set
3. Appearing on paths between exposure and outcome

These variables should be excluded from adjustment sets to avoid opening blocked paths.

---

### Reporting Functions

#### `print_section_header(title)`

Prints a formatted section header for console output.

---

#### `print_vector(label, values)`

Prints a labeled list of variables with proper formatting.

---

#### `run_butterfly_mbias_report(dag)`

Generates a comprehensive report analyzing butterfly bias and M-bias in the provided DAG.

**Parameters:**
- `dag`: A dagitty DAG object with exposure and outcome defined

**Returns:**
- Invisibly returns a list with `butterfly` and `mbias` analysis results
- Prints formatted report to console

**Report sections:**
1. Variable role classification
2. Butterfly bias candidates and their parents
3. Valid minimal sufficient adjustment sets (butterfly-safe)
4. Comparison with dagitty minimal sets
5. M-bias variables to avoid
6. Path verification showing the effect of adjustment

---

## Usage Example
```r
# Source the script
source("butterfly_mbias_analysis.R")

# Define a DAG with butterfly and M-bias structures
example_dag <- dagitty('dag {
  A [exposure]
  Y [outcome]
  
  # Confounding structure
  A <- C1 -> Y
  A <- C2 -> Y
  A <- C3 -> Y
  C1 -> C3 <- C2
  
  # Butterfly candidate: C4 has two confounder parents
  A <- C4 -> Y
  C1 -> C4
  C2 -> C4
  
  # Mediator and collider examples
  A -> M -> Y
  A -> Collider <- Y
  
  # Additional structure
  parent_of_IV -> IV -> A
  Precision1 -> Y
}')

# Run the comprehensive report
results <- run_butterfly_mbias_report(example_dag)

# Access individual components
butterfly_analysis <- results$butterfly
mbias_analysis <- results$mbias

# Get specific information
confounders <- butterfly_analysis$roles$confounders
butterfly_safe_sets <- butterfly_analysis$valid_sets
mbias_vars <- mbias_analysis$mbias_vars
```

## Interpreting Results

### Variable Roles

- **Instrumental variables**: Can potentially be used for instrumental variable analysis, but should not be included in standard adjustment sets
- **Precision variables**: Optional to include; improve statistical precision without introducing bias
- **Confounders**: Must be addressed through adjustment, restriction, or matching
- **Mediators**: Should not be adjusted if estimating total causal effect; adjust only for direct effects
- **Colliders**: Generally should not be adjusted unless part of M-bias structure

### TODO
Add sections for hybrid-type variables: 
- **Confounder/Mediators**: Also called confounders affected by prior treatment (CAPT[s])
- **Confounder/Mediator/Colliders**: an inherently problematic bunch
- **Mediator/Colliders**: --

Process from the raw initial graph to get Precision Variables (PVs) and Instrumental Variables (IVs): 
- **Add in remove leaves code, etc. PRIOR to running identifiers for PVs and IVs:** PVs and IVs are removed in graph preprocessing

### Adjustment Set Selection

1. **Butterfly-safe sets**: Use these when butterfly bias is detected. Select the set that:
   - Is most parsimonious (fewest variables)
   - Contains variables that are reliably measured in your study
   - Avoids adjusting for mediators if estimating total effects

2. **M-bias variables**: Never include these in adjustment sets, even if they appear correlated with exposure or outcome

3. **Path verification**: Check that open paths are reduced to zero (or only mediated paths remain if that is the estimand)

## Integration with CausalKnowledgeTrace

This script is part of the `furtherAnalysis` module in CausalKnowledgeTrace. After extracting and refining causal graphs from literature using the main CKT pipeline, use these functions to:

1. Classify variables by causal role
2. Identify potential sources of selection bias
3. Generate valid adjustment sets for downstream statistical analysis
4. Document causal assumptions for epidemiological studies

## Computational Considerations

- Butterfly bias analysis can generate many adjustment sets when multiple butterfly nodes exist. The number grows as 2^k per butterfly node, where k is the number of parents.
- For large graphs with multiple butterfly structures, consider restricting analysis to a simplified subgraph focusing on the most relevant pathways
- M-bias detection requires path enumeration, which is efficient for most DAGs but may be slow for very dense graphs

## References

- Pearl, J. (2009). Causality: Models, Reasoning, and Inference (2nd ed.). Cambridge University Press.
- Ding, P., & Miratrix, L. W. (2015). To adjust or not to adjust? Sensitivity analysis of M-bias and butterfly-bias. Journal of Causal Inference, 3(1), 41-57.
- VanderWeele, T. J. (2019). Principles of confounder selection. European Journal of Epidemiology, 34, 211-219.

