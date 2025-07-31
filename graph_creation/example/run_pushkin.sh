python graph_creation/pushkin.py \
  --yaml-config user_input.yaml \
  --output-dir graph_creation/result \
  --host localhost \
  --port 5432 \
  --dbname causalehr \
  --user rajesh \
  --password Usps@6855 \
  --schema causalehr \
  --verbose
  # --markov-blanket  # Uncomment this line to enable Markov blanket analysis