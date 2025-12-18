#!/bin/bash

echo "🚀 Starting Graph Creation Pipeline..."
echo "======================================"


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
else
    echo ""
    echo "❌ GRAPH CREATION FAILED"
    echo "======================================"
    echo "Graph creation did not complete successfully."
    echo "Please check the error messages above."
    exit 1
fi
