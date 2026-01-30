#!/bin/bash

# generate_graph.sh
# Generate graph from CKT database using YAML configuration file
#
# This script only handles graph generation. Run analysis scripts separately.

set -e  # Exit on any error

# ============================================
# CONFIGURATION
# ============================================

# Default values
DB_HOST="localhost"
DB_PORT="5434"
DB_NAME="causalehr_db"
DB_USER="mpradhan"
DB_PASSWORD="Software292$"
VERBOSE=""

# ============================================
# HELP MESSAGE
# ============================================

show_help() {
    cat << EOF
Usage: $0 [OPTIONS] --yaml-config CONFIG_FILE

Generate graphs from CKT database using YAML configuration files.
This script ONLY generates graphs. Run analysis scripts separately afterward.

REQUIRED:
  --yaml-config FILE        Path to YAML configuration file

OPTIONAL:
  --db-user USER            Database username
  --db-password PASS        Database password
  --db-host HOST            Database host [default: localhost]
  --db-port PORT            Database port [default: 5434]
  --db-name NAME            Database name [default: causalehr_db]
  --output-dir DIR          Output directory [default: manjil_analysis/input]
  --verbose                 Enable verbose output
  -h, --help                Show this help message

YAML CONFIGURATION FORMAT:

  exposure_cuis:
    - C0011570              # Depression CUI
  outcome_cuis:
    - C0002395              # Alzheimer's CUI
  exposure_name: Depression # For file naming (optional, will extract from DB if not provided)
  outcome_name: Alzheimers  # For file naming (optional)
  min_pmids: 50             # Minimum evidence threshold
  degree: 2                 # Graph degree (1, 2, or 3)
  predication_types:        # Relationship types to include
    - CAUSES
    - STIMULATES
    - PREVENTS
  blocklist_cuis:           # CUIs to exclude (optional)
    - C0006104

EXAMPLES:

  # Generate graph using YAML config
  $0 --yaml-config configs/depression_alzheimers.yaml \\
     --db-user myuser --db-password mypass

  # Generate with verbose output
  $0 --yaml-config configs/hypertension_alzheimers.yaml \\
     --db-user myuser --db-password mypass --verbose

  # Custom output directory
  $0 --yaml-config configs/ptsd_selfharm.yaml \\
     --db-user myuser --db-password mypass \\
     --output-dir my_graphs/

WORKFLOW:

  1. Create YAML config file with your exposure/outcome settings
  2. Run this script to generate the graph
  3. Run analysis scripts manually:

     cd manjil_analysis/scripts
     Rscript 01_parse_dagitty.R <exposure> <outcome>
     Rscript 02_basic_analysis.R <exposure> <outcome>
     Rscript 03_cycle_detection.R <exposure> <outcome>
     Rscript 03b_semantic_type_analysis.R <exposure> <outcome>

EOF
}

# ============================================
# PARSE ARGUMENTS
# ============================================

YAML_CONFIG=""
OUTPUT_DIR=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --yaml-config)
            YAML_CONFIG="$2"
            shift 2
            ;;
        --db-user)
            DB_USER="$2"
            shift 2
            ;;
        --db-password)
            DB_PASSWORD="$2"
            shift 2
            ;;
        --db-host)
            DB_HOST="$2"
            shift 2
            ;;
        --db-port)
            DB_PORT="$2"
            shift 2
            ;;
        --db-name)
            DB_NAME="$2"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE="--verbose"
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Error: Unknown option $1"
            show_help
            exit 1
            ;;
    esac
done

# ============================================
# VALIDATION
# ============================================

if [[ -z "$YAML_CONFIG" ]]; then
    echo "Error: --yaml-config is required"
    show_help
    exit 1
fi

if [[ ! -f "$YAML_CONFIG" ]]; then
    echo "Error: YAML config file not found: $YAML_CONFIG"
    exit 1
fi

if [[ -z "$DB_USER" || -z "$DB_PASSWORD" ]]; then
    echo "Error: Database credentials required (--db-user and --db-password)"
    exit 1
fi

# ============================================
# SETUP PATHS
# ============================================

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CKT_ROOT="$(dirname "$PROJECT_ROOT")"

# Default output directory if not specified
if [[ -z "$OUTPUT_DIR" ]]; then
    OUTPUT_DIR="$PROJECT_ROOT/input"
fi

mkdir -p "$OUTPUT_DIR"

# ============================================
# EXTRACT DEGREE FROM YAML
# ============================================

echo "=========================================="
echo "GRAPH GENERATION FROM YAML CONFIG"
echo "=========================================="
echo ""
echo "YAML config: $YAML_CONFIG"
echo "Output directory: $OUTPUT_DIR"
echo ""

# Extract degree from YAML (needed for file renaming)
DEGREE=$(grep -E "^degree:" "$YAML_CONFIG" | awk '{print $2}' || echo "1")

# ============================================
# GENERATE GRAPH
# ============================================

echo "Generating graph using CKT database..."
echo ""

cd "$CKT_ROOT"

PUSHKIN_CMD="python graph_creation/pushkin.py"
PUSHKIN_CMD="$PUSHKIN_CMD --host $DB_HOST"
PUSHKIN_CMD="$PUSHKIN_CMD --port $DB_PORT"
PUSHKIN_CMD="$PUSHKIN_CMD --user $DB_USER"
PUSHKIN_CMD="$PUSHKIN_CMD --password $DB_PASSWORD"
PUSHKIN_CMD="$PUSHKIN_CMD --dbname $DB_NAME"
PUSHKIN_CMD="$PUSHKIN_CMD --yaml-config $YAML_CONFIG"
PUSHKIN_CMD="$PUSHKIN_CMD --output-dir $OUTPUT_DIR"

if [[ -n "$VERBOSE" ]]; then
    PUSHKIN_CMD="$PUSHKIN_CMD $VERBOSE"
fi

echo "Running: $PUSHKIN_CMD"
echo ""
eval "$PUSHKIN_CMD"

if [[ $? -ne 0 ]]; then
    echo ""
    echo "ERROR: Graph generation failed"
    exit 1
fi

echo ""
echo "=========================================="
echo "GRAPH GENERATION COMPLETE"
echo "=========================================="
echo ""

# ============================================
# RENAME FILES
# ============================================

# Try to extract exposure/outcome names from YAML
EXPOSURE_NAME=$(grep -E "^exposure_name:" "$YAML_CONFIG" | awk '{print $2}' | tr -d '"' | tr -d "'" || echo "")
OUTCOME_NAME=$(grep -E "^outcome_name:" "$YAML_CONFIG" | awk '{print $2}' | tr -d '"' | tr -d "'" || echo "")

# If names are provided in YAML, rename the generated files
if [[ -n "$EXPOSURE_NAME" && -n "$OUTCOME_NAME" ]]; then
    echo "Renaming files using exposure: $EXPOSURE_NAME, outcome: $OUTCOME_NAME"

    # Rename degree_N.R to {exposure}_{outcome}_degree_N.R
    if [[ -f "$OUTPUT_DIR/degree_${DEGREE}.R" ]]; then
        NEW_NAME="${EXPOSURE_NAME}_${OUTCOME_NAME}_degree_${DEGREE}.R"
        mv "$OUTPUT_DIR/degree_${DEGREE}.R" "$OUTPUT_DIR/$NEW_NAME"
        echo "  Renamed: degree_${DEGREE}.R -> $NEW_NAME"
    fi

    # Rename causal_assertions_N.json
    if [[ -f "$OUTPUT_DIR/causal_assertions_${DEGREE}.json" ]]; then
        NEW_JSON="${EXPOSURE_NAME}_${OUTCOME_NAME}_causal_assertions_${DEGREE}.json"
        mv "$OUTPUT_DIR/causal_assertions_${DEGREE}.json" "$OUTPUT_DIR/$NEW_JSON"
        echo "  Renamed: causal_assertions_${DEGREE}.json -> $NEW_JSON"
    fi

    echo ""
    echo "Generated files:"
    echo "  - $OUTPUT_DIR/${EXPOSURE_NAME}_${OUTCOME_NAME}_degree_${DEGREE}.R"
    echo "  - $OUTPUT_DIR/${EXPOSURE_NAME}_${OUTCOME_NAME}_causal_assertions_${DEGREE}.json"
    echo ""
else
    echo "Note: exposure_name and outcome_name not found in YAML config."
    echo "Files generated with default names (degree_${DEGREE}.R, causal_assertions_${DEGREE}.json)"
    echo ""
    echo "Generated files:"
    echo "  - $OUTPUT_DIR/degree_${DEGREE}.R"
    echo "  - $OUTPUT_DIR/causal_assertions_${DEGREE}.json"
    echo ""
    echo "To rename manually:"
    echo "  mv $OUTPUT_DIR/degree_${DEGREE}.R $OUTPUT_DIR/<exposure>_<outcome>_degree_${DEGREE}.R"
    echo ""
fi

echo "=========================================="
echo "NEXT STEPS"
echo "=========================================="
echo ""
echo "To run the analysis pipeline, use:"
echo ""
echo "  cd $SCRIPT_DIR"
echo "  Rscript 01_parse_dagitty.R <exposure_name> <outcome_name>"
echo "  Rscript 02_basic_analysis.R <exposure_name> <outcome_name>"
echo "  Rscript 03_cycle_detection.R <exposure_name> <outcome_name>"
echo "  Rscript 03b_semantic_type_analysis.R <exposure_name> <outcome_name>"
echo ""

if [[ -n "$EXPOSURE_NAME" && -n "$OUTCOME_NAME" ]]; then
    echo "For this graph, run:"
    echo ""
    echo "  cd $SCRIPT_DIR"
    echo "  Rscript 01_parse_dagitty.R $EXPOSURE_NAME $OUTCOME_NAME"
    echo "  Rscript 02_basic_analysis.R $EXPOSURE_NAME $OUTCOME_NAME"
    echo "  Rscript 03_cycle_detection.R $EXPOSURE_NAME $OUTCOME_NAME"
    echo "  Rscript 03b_semantic_type_analysis.R $EXPOSURE_NAME $OUTCOME_NAME"
    echo ""
fi
