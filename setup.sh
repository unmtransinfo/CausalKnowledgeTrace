#!/bin/bash

source .env
# Create and activate conda environment
conda env create -f doc/environment.yml
conda activate causalknowledgetrace

# Install R packages from packages.R
Rscript doc/packages.R

# Create CUI search index table
psql -h "$DB_HOST" -p "${DB_PORT:-5432}" -U "$DB_USER" -d "$DB_NAME" -f doc/create_cui_search_table.sql