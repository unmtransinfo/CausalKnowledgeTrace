#!/bin/bash

# Simple SemDAG Processor Runner
python graph_creation/consolidation.py \
  --model "llama3.3:70b" \
  --input-file "./graph_creation/result/degree_1.R" \
  --output-file "./graph_creation/result/ConsolidatedDAG.R" \
  --consolidate \
  --verbose