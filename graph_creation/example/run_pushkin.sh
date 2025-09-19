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

    # Step 2: Run post-processing optimization
    echo "⚡ Step 2: Creating optimized file versions..."
    echo "This will create binary and lightweight versions for faster loading."
    python graph_creation/post_process_optimization.py graph_creation/result

    if [ $? -eq 0 ]; then
        echo ""
        echo "🎉 COMPLETE SUCCESS!"
        echo "======================================"
        echo "✅ Graph creation: SUCCESS"
        echo "✅ File optimization: SUCCESS"
        echo ""
        echo "Your graph files are ready with:"
        echo "  • Original JSON files"
        echo "  • Binary RDS files (75% compression)"
        echo "  • Lightweight JSON files (94% size reduction)"
        echo "  • Binary DAG files (50-66% compression)"
        echo ""
        echo "🚀 Ready for lightning-fast loading in the Shiny app!"
    else
        echo ""
        echo "⚠️ PARTIAL SUCCESS"
        echo "======================================"
        echo "✅ Graph creation: SUCCESS"
        echo "❌ File optimization: FAILED"
        echo ""
        echo "Graph files were created but optimization failed."
        echo "You can manually run optimization later:"
        echo "  python graph_creation/post_process_optimization.py graph_creation/result"
    fi
else
    echo ""
    echo "❌ GRAPH CREATION FAILED"
    echo "======================================"
    echo "Graph creation did not complete successfully."
    echo "Please check the error messages above."
    exit 1
fi