FROM continuumio/miniconda3:latest

WORKDIR /causalknowledgetrace

# Install system dependencies needed for R packages
RUN apt-get update && apt-get install -y \
    libxml2-dev \
    libz-dev \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Copy all files into the container
COPY ./ /causalknowledgetrace

# Create conda environment from yaml
RUN conda env create -f doc/environment.yaml && \
    conda clean -a -y

# Set environment variables to activate conda environment
ENV PATH=/opt/conda/envs/causalknowledgetrace/bin:$PATH
ENV CONDA_DEFAULT_ENV=causalknowledgetrace

# Install R packages (now conda env is active)
RUN Rscript doc/packages.R

# Expose port for Shiny
EXPOSE 3838

# Run the shiny app
CMD ["Rscript", "run_app.R"]