#!/bin/bash

# run_pipeline.sh
# Run the complete post-CKT analysis pipeline
#
# Usage:
#   ./run_pipeline.sh <exposure> <outcome>
#   ./run_pipeline.sh Hypertension Alzheimers
#
# This script runs all analysis scripts in sequence:
#   01_parse_dagitty.R
#   02_basic_analysis.R
#   04a_cycle_detection.R
#   03a_semantic_type_analysis.R (requires DB credentials)
#   03b_semantic_distribution.R
#   04b_extract_analyze_cycle.R
#   04c_visualize_cycles.R

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

if [ $# -lt 2 ]; then
    echo "Usage: $0 <exposure> <outcome>"
    echo ""
    echo "Example:"
    echo "  $0 Hypertension Alzheimers"
    echo "  $0 Depression Alzheimers"
    echo ""
    exit 1
fi

EXPOSURE="$1"
OUTCOME="$2"

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
echo ""
echo "Database: $CKT_DB_NAME @ $CKT_DB_HOST:$CKT_DB_PORT"
echo "User:     $CKT_DB_USER"
echo ""

START_TIME=$(date +%s)

# Step 1: Parse DAGitty
print_step "Step 1/7: Parsing DAGitty file"
cd "$SCRIPT_DIR"
if Rscript 01_parse_dagitty.R "$EXPOSURE" "$OUTCOME"; then
    print_success "DAGitty parsing complete"
else
    print_error "DAGitty parsing failed"
    exit 1
fi

# Step 2: Basic Analysis
print_step "Step 2/7: Running basic graph analysis"
if Rscript 02_basic_analysis.R "$EXPOSURE" "$OUTCOME"; then
    print_success "Basic analysis complete"
else
    print_error "Basic analysis failed"
    exit 1
fi

# Step 3: Cycle Detection
print_step "Step 3/7: Detecting cycles"
if Rscript 04a_cycle_detection.R "$EXPOSURE" "$OUTCOME"; then
    print_success "Cycle detection complete"
else
    print_error "Cycle detection failed"
    exit 1
fi

# Step 4: Semantic Type Analysis (requires DB)
print_step "Step 4/7: Analyzing semantic types (requires database)"
if Rscript 03a_semantic_type_analysis.R "$EXPOSURE" "$OUTCOME"; then
    print_success "Semantic type analysis complete"
else
    print_error "Semantic type analysis failed"
    echo "Note: This step requires database access. Check your credentials."
    exit 1
fi

# Step 5: Semantic Distribution Plots
print_step "Step 5/7: Generating semantic distribution plots"
if Rscript 03b_semantic_distribution.R "$EXPOSURE" "$OUTCOME"; then
    print_success "Semantic distribution plots complete"
else
    print_error "Semantic distribution plots failed"
    exit 1
fi

# Step 6: Extract and Analyze Cycles
print_step "Step 6/7: Extracting and analyzing cycles"
if Rscript 04b_extract_analyze_cycle.R "$EXPOSURE" "$OUTCOME"; then
    print_success "Cycle extraction complete"
else
    print_error "Cycle extraction failed"
    exit 1
fi

# Step 7: Visualize Cycles
print_step "Step 7/7: Visualizing cycles"
if Rscript 04c_visualize_cycles.R "$EXPOSURE" "$OUTCOME"; then
    print_success "Cycle visualization complete"
else
    print_error "Cycle visualization failed"
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
echo "Time:     ${ELAPSED} seconds"
echo ""
echo "Output directories:"
echo "  - Parsed graphs:    ../output/parsed_graphs/${EXPOSURE}_${OUTCOME}/"
echo "  - Analysis results: ../output/analysis_results/${EXPOSURE}_${OUTCOME}/"
echo "  - Cycle subgraphs:  ../output/cycle_subgraph/${EXPOSURE}_${OUTCOME}/"
echo "  - Plots:            ../output/plots/${EXPOSURE}_${OUTCOME}/"
echo ""
