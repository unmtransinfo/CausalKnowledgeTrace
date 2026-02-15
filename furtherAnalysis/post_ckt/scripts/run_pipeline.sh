#!/bin/bash

# run_pipeline.sh
# Run the complete Post-CKT Analysis Pipeline
#
# Usage:
#   ./run_pipeline.sh <exposure> <outcome> <degree>
#   ./run_pipeline.sh Hypertension Alzheimers 2
#
# This script runs all analysis scripts in sequence for a specific degree graph.
#
# NEW PIPELINE (Refactored Feb 2026):
# 1. Parsing & Centrality (01, 01a)
# 2. Node Removal & Pruning (01b, 01c, 01d)
# 3. Basic & Semantic Analysis (02)
# 4. Confounder Analysis (07)
# 5. Evidence Extraction (08)
# 6. Advanced Confounder & Bias Analysis (09, 10, 10b)

set -e  # Exit on any error

# ============================================
# CONFIGURATION
# ============================================

# Database credentials - MODIFY THESE or set as environment variables
export CKT_DB_HOST="${CKT_DB_HOST:-localhost}"
export CKT_DB_PORT="${CKT_DB_PORT:-5432}"
export CKT_DB_NAME="${CKT_DB_NAME:-causalehr_db}"
export CKT_DB_USER="${CKT_DB_USER:-mpradhan}"
export CKT_DB_PASSWORD="${CKT_DB_PASSWORD:-Software292\$}"

# ============================================
# PARSE ARGUMENTS
# ============================================

if [ $# -lt 3 ]; then
    echo "Usage: $0 <exposure> <outcome> <degree>"
    echo ""
    echo "Example:"
    echo "  $0 Hypertension Alzheimers 1"
    echo "  $0 Hypertension Alzheimers 2"
    echo "  $0 Hypertension Alzheimers 3"
    echo ""
    exit 1
fi

EXPOSURE="$1"
OUTCOME="$2"
DEGREE="$3"

# Validate degree
if [[ ! "$DEGREE" =~ ^[1-3]$ ]]; then
    echo "Error: Degree must be 1, 2, or 3"
    exit 1
fi

# ============================================
# SETUP
# ============================================

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print step header
print_step() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

# Function to print success
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to print error
print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# ============================================
# MAIN PIPELINE
# ============================================

echo ""
echo -e "${YELLOW}================================================${NC}"
echo -e "${YELLOW}  Post-CKT Analysis Pipeline${NC}"
echo -e "${YELLOW}================================================${NC}"
echo ""
echo "Exposure: $EXPOSURE"
echo "Outcome:  $OUTCOME"
echo "Degree:   $DEGREE"
echo ""
echo "Database: $CKT_DB_NAME @ $CKT_DB_HOST:$CKT_DB_PORT"
echo "User:     $CKT_DB_USER"
echo ""

START_TIME=$(date +%s)

cd "$SCRIPT_DIR"

# --- STAGE 1: GRAPH PREPARATION & PRUNING ---

# Step 1: Parse DAGitty
print_step "Step 1/11: Parsing DAGitty file (01)"
if Rscript 01_parse_dagitty.R "$EXPOSURE" "$OUTCOME" "$DEGREE"; then
    print_success "DAGitty parsing complete"
else
    print_error "DAGitty parsing failed"
    exit 1
fi

# Step 2: Calculate Centrality
print_step "Step 2/11: Calculating centrality (01a)"
if Rscript 01a_calculate_centrality.R "$EXPOSURE" "$OUTCOME" "$DEGREE"; then
    print_success "Centrality calculation complete"
else
    print_error "Centrality calculation failed"
    exit 1
fi

# Step 3: Node Removal Impact Analysis (New Centrality-Based)
print_step "Step 3/11: Analyzing node removal impact (01b)"
if Rscript 01b_node_removal_impact.R "$EXPOSURE" "$OUTCOME" "$DEGREE"; then
    print_success "Node removal impact analysis complete"
else
    print_error "Node removal impact analysis failed"
    exit 1
fi

# Step 4: Prune Generic Hubs
print_step "Step 4/11: Pruning generic hubs (01c)"
if Rscript 01c_prune_generic_hubs.R "$EXPOSURE" "$OUTCOME" "$DEGREE"; then
    print_success "Pruning complete"
else
    print_error "Pruning failed"
    exit 1
fi

# Step 5: Post-Pruning Analysis
print_step "Step 5/11: Post-pruning analysis (01d)"
if Rscript 01d_post_node_removal_analysis.R "$EXPOSURE" "$OUTCOME" "$DEGREE"; then
    print_success "Post-pruning analysis complete"
else
    print_error "Post-pruning analysis failed"
    exit 1
fi

# --- STAGE 2: GRAPH ANALYSIS ---

# Step 6: Basic & Semantic Analysis
# (Replaces old 02, 03a, 03b)
print_step "Step 6/11: Basic & Semantic Analysis (02)"
if Rscript 02_basic_analysis.R "$EXPOSURE" "$OUTCOME" "$DEGREE"; then
    print_success "Basic analysis complete"
else
    print_error "Basic analysis failed"
    # Don't exit - semantic analysis might fail due to DB but basic stats are saved
    echo "Warning: Basic analysis encountered issues (likely DB connection). Continuing..."
fi

# --- STAGE 3: CONFOUNDER ANALYSIS ---

# Step 7: Confounder Analysis (Discovery, Reports, Cycle Breaking)
# (Replaces old 07, 07b, 07c)
print_step "Step 7/11: Confounder Analysis & Cycle Breaking (03)"
if Rscript 03_confounder_analysis.R "$EXPOSURE" "$OUTCOME" "$DEGREE"; then
    print_success "Confounder analysis complete"
else
    print_error "Confounder analysis failed"
    exit 1
fi

# Step 8: Evidence Extraction (03b)
print_step "Step 8/11: Extracting Evidence (03b)"
if Rscript 03b_extract_confounder_evidence.R "$EXPOSURE" "$OUTCOME" "$DEGREE"; then
    print_success "Evidence extraction complete"
else
    print_error "Evidence extraction failed"
    exit 1
fi

# Step 9: Confounder Relationships (03c)
print_step "Step 9/11: Analyzing Confounder Relationships (03c)"
if Rscript 03c_confounder_relationships.R "$EXPOSURE" "$OUTCOME" "$DEGREE"; then
    print_success "Relationship analysis complete"
else
    print_error "Relationship analysis failed"
    exit 1
fi

# Step 10: Butterfly Bias Analysis (04)
print_step "Step 10/11: Butterfly Bias Analysis (04)"
if Rscript 04_butterfly_bias_analysis.R "$EXPOSURE" "$OUTCOME" "$DEGREE"; then
    print_success "Butterfly bias analysis complete"
else
    print_error "Butterfly bias analysis failed"
    exit 1
fi

# Step 11: Confounder Subgraphs (04b)
print_step "Step 11/11: Generating Confounder Subgraphs (04b)"
if Rscript 04b_confounder_subgraphs.R "$EXPOSURE" "$OUTCOME" "$DEGREE"; then
    print_success "Subgraph generation complete"
else
    print_error "Subgraph generation failed"
    exit 1
fi

# ============================================
# SUMMARY
# ============================================

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}  Pipeline Complete!${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo "Exposure: $EXPOSURE"
echo "Outcome:  $OUTCOME"
echo "Degree:   $DEGREE"
echo "Time:     ${ELAPSED} seconds"
echo ""
echo "Output directory:"
echo "  data/${EXPOSURE}_${OUTCOME}/degree${DEGREE}/"
echo ""
echo "Key outputs:"
echo "  - Pruned graph:    s1_graph/pruned_graph.rds"
echo "  - Semantic Stats:  s2_semantic/semantic_type_distribution.csv"
echo "  - Confounders:     s3_confounders/valid_confounders.csv"
echo "  - Evidence:        s3b_evidence/all_evidence.csv"
echo "  - Butterfly Bias:  s4_butterfly_bias/analysis_summary.txt"
echo ""
