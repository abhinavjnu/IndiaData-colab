#!/bin/bash
# ============================================================================
# run_plfs_analysis.sh - One-Command PLFS Analysis Runner
# ============================================================================
# This script runs the complete PLFS analysis pipeline.
# Usage: ./PLFS/run_plfs_analysis.sh
#
# Requirements:
#   - R installed and in PATH
#   - All required R packages installed
#   - Raw PLFS data in PLFS/YYYY-YY/ folders
# ============================================================================

echo ""
echo "========================================"
echo "PLFS Automated Analysis"
echo "========================================"
echo ""
echo "This will run the complete analysis pipeline:"
echo "  1. Parse raw data files"
echo "  2. Create survey designs"
echo "  3. Calculate labour force indicators"
echo "  4. Generate tables and visualizations"
echo ""

# Check if R is installed
if ! command -v Rscript &> /dev/null
then
    echo "ERROR: Rscript not found. Please install R and ensure it's in your PATH."
    exit 1
fi

# Change to the project directory
cd "$(dirname "$0")/.." || exit

echo "Starting analysis..."
echo ""

# Run the R script
Rscript -e "source('PLFS/automated_plfs_analysis.R')"

echo ""
echo "========================================"
echo "Analysis Complete!"
echo "========================================"
echo ""
echo "Check the outputs/ folder for results."
echo ""
