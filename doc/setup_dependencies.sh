#!/bin/bash

# CausalKnowledgeTrace Master Dependency Setup Script
# This script sets up both Python and R dependencies for the entire project
#
# Usage:
#   chmod +x setup_dependencies.sh
#   ./setup_dependencies.sh

echo "=== CausalKnowledgeTrace Master Dependency Setup ==="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
echo "🔍 Checking prerequisites..."

# Check Python
if command_exists python3; then
    PYTHON_VERSION=$(python3 --version 2>&1 | cut -d' ' -f2)
    print_status $GREEN "✅ Python 3 found: $PYTHON_VERSION"
    PYTHON_CMD="python3"
elif command_exists python; then
    PYTHON_VERSION=$(python --version 2>&1 | cut -d' ' -f2)
    if [[ $PYTHON_VERSION == 3.* ]]; then
        print_status $GREEN "✅ Python 3 found: $PYTHON_VERSION"
        PYTHON_CMD="python"
    else
        print_status $RED "❌ Python 3 required, found Python $PYTHON_VERSION"
        exit 1
    fi
else
    print_status $RED "❌ Python 3 not found. Please install Python 3.8 or higher."
    exit 1
fi

# Check pip
if command_exists pip3; then
    print_status $GREEN "✅ pip3 found"
    PIP_CMD="pip3"
elif command_exists pip; then
    print_status $GREEN "✅ pip found"
    PIP_CMD="pip"
else
    print_status $RED "❌ pip not found. Please install pip."
    exit 1
fi

# Check R
if command_exists R; then
    R_VERSION=$(R --version | head -n1 | cut -d' ' -f3)
    print_status $GREEN "✅ R found: $R_VERSION"
else
    print_status $RED "❌ R not found. Please install R 4.0 or higher."
    exit 1
fi

# Check Rscript
if command_exists Rscript; then
    print_status $GREEN "✅ Rscript found"
else
    print_status $RED "❌ Rscript not found. Please ensure R is properly installed."
    exit 1
fi

echo ""

# Install Python dependencies
print_status $BLUE "1️⃣  Installing Python dependencies..."
echo ""

if [ -f "requirements.txt" ]; then
    print_status $YELLOW "📦 Installing Python packages from requirements.txt..."
    if $PIP_CMD install -r requirements.txt; then
        print_status $GREEN "✅ Python dependencies installed successfully"
    else
        print_status $RED "❌ Failed to install Python dependencies"
        exit 1
    fi
else
    print_status $RED "❌ requirements.txt not found"
    exit 1
fi

echo ""

# Install R dependencies
print_status $BLUE "2️⃣  Installing R dependencies..."
echo ""

if [ -f "install_r_dependencies.R" ]; then
    print_status $YELLOW "📦 Installing R packages using automated installer..."
    if Rscript install_r_dependencies.R; then
        print_status $GREEN "✅ R dependencies installation completed"
    else
        print_status $YELLOW "⚠️  R dependencies installation completed with warnings"
    fi
else
    print_status $RED "❌ install_r_dependencies.R not found"
    exit 1
fi

echo ""

# Verify installations
print_status $BLUE "3️⃣  Verifying installations..."
echo ""

# Check Python dependencies
print_status $YELLOW "🔍 Checking Python dependencies..."
if $PYTHON_CMD check_python_dependencies.py; then
    print_status $GREEN "✅ Python dependency check completed"
else
    print_status $YELLOW "⚠️  Python dependency check completed with issues"
fi

echo ""

# Check R dependencies
print_status $YELLOW "🔍 Checking R dependencies..."
if Rscript check_dependencies.R; then
    print_status $GREEN "✅ R dependency check completed"
else
    print_status $YELLOW "⚠️  R dependency check completed with issues"
fi

echo ""

# Final summary
print_status $BLUE "=== Setup Summary ==="
print_status $GREEN "🎉 Dependency setup process completed!"
echo ""
print_status $YELLOW "Next steps:"
echo "  • For Shiny application: source('launch_shiny_app.R')"
echo "  • For Python graph engine: python graph_creation/pushkin.py --help"
echo "  • To verify setup: run the check scripts individually"
echo ""
print_status $BLUE "=== Setup Complete ==="
