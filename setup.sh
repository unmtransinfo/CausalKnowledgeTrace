#!/bin/bash

source .env
# Create and activate conda environment
conda env create -f doc/environment.yml
conda activate causalknowledgetrace

# Install R packages from packages.R
Rscript doc/packages.R