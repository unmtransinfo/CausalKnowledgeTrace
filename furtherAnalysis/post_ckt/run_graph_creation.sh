#!/bin/bash

# Navigate to project root relative to this script
# Assuming this script is in furtherAnalysis/post_ckt/
cd ../../

# Run graph creation
# Using port 5434 based on local .env configuration
python graph_creation/pushkin.py \
  --yaml-config user_input.yaml \
  --output-dir graph_creation/result \
  --host localhost \
  --port 5432 \
  --user rajesh \
  --password 'Usps@6855' \
  --dbname causalehr \
  --verbose
