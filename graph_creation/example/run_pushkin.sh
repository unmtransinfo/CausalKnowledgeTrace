#!/bin/bash

source .env

echo "🚀 Starting Graph Creation Pipeline..."
echo "======================================"

# Step 1: Run the main graph creation
echo "📊 Step 1: Running graph analysis..."
python graph_creation/pushkin.py \
  --yaml-config user_input.yaml \
  --output-dir graph_creation/result \
  --host "$DB_HOST" \
  --port "$DB_PORT"  \
  --user "$DB_USER" \
  --password "$DB_PASSWORD" \
  --dbname "$DB_NAME" \
  --schema "$DB_SCHEMA" \
  --verbose
  # --markov-blanket  # Uncomment this line to enable Markov blanket analysis

# Check if graph creation was successful
if [ $? -eq 0 ]; then
    echo "✅ Graph creation completed successfully!"
    echo ""

    echo ""
    echo "🎉 PIPELINE COMPLETE!"
    echo "======================================"
    echo "Your causal knowledge graph is ready!"
    echo ""
    echo "📁 Generated files in graph_creation/result/:"
    echo "   - causal_assertions_*.json (graph data)"
    echo "   - degree_*.R (DAG visualization scripts)"
    echo "   - performance_metrics.json (timing data)"
    echo ""
    echo "🚀 Next steps:"
    echo "   1. Open the Shiny app: Rscript run_app.R"
    echo "   2. Load your graph data in the 'Data Upload' tab"
    echo "   3. Explore causal relationships interactively"
else
    echo ""
    echo "❌ GRAPH CREATION FAILED"
    echo "======================================"
    echo "Graph creation did not complete successfully."
    echo "Please check the error messages above."
    exit 1
fi