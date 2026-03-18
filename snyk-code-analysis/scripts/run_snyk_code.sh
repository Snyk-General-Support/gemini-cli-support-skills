#!/bin/bash

# Script to run Snyk Code test and output JSON for analysis
# Usage: ./run_snyk_code.sh [path/to/project]

PROJECT_PATH=${1:-.}

if ! command -v snyk &> /dev/null
then
    echo "Error: 'snyk' CLI is not installed."
    exit 1
fi

echo "Running 'snyk code test --json' in $PROJECT_PATH..."
snyk code test --json "$PROJECT_PATH"
