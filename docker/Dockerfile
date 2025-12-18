FROM continuumio/miniconda3:latest

WORKDIR /causalknowledgetrace

# Install system dependencies needed for R packages
RUN apt-get update && apt-get install -y \
    libxml2-dev \
    libz-dev \
    libpq-dev \
    libssl-dev \
    libcurl4-openssl-dev \
    libfontconfig1-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libfreetype6-dev \
    libpng-dev \
    libtiff5-dev \
    libjpeg-dev \
    net-tools \
    build-essential \
    gfortran \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Copy all files into the container
COPY ./ /causalknowledgetrace

# Create conda environment from yaml
RUN conda env create -f doc/environment.yaml && \
    conda clean -a -y

# Set environment variables to activate conda environment
ENV PATH=/opt/conda/envs/causalknowledgetrace/bin:$PATH
ENV CONDA_DEFAULT_ENV=causalknowledgetrace

# Configure R compiler settings BEFORE installing R packages
RUN mkdir -p /root/.R && \
    echo "CC=gcc" > /root/.R/Makevars && \
    echo "CXX=g++" >> /root/.R/Makevars && \
    echo "CXX11=g++" >> /root/.R/Makevars && \
    echo "CXX14=g++" >> /root/.R/Makevars && \
    echo "CXX17=g++" >> /root/.R/Makevars && \
    echo "CC17=gcc" >> /root/.R/Makevars && \
    echo "FC=gfortran" >> /root/.R/Makevars && \
    echo "F77=gfortran" >> /root/.R/Makevars && \
    echo "CFLAGS=-O2 -fPIC" >> /root/.R/Makevars && \
    echo "CXXFLAGS=-O2 -fPIC" >> /root/.R/Makevars

# Install R packages (now conda env is active and compiler is configured)
RUN Rscript doc/packages.R

# Expose port for Shiny
EXPOSE 3838

# Run the shiny app
CMD ["Rscript", "run_app.R"]