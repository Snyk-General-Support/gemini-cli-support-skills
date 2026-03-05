#!/bin/bash

# Script to set up a new customer case directory
# Usage: ./setup_case.sh <case_number>

CASE_NUMBER=$1

if [ -z "$CASE_NUMBER" ]; then
    echo "Error: Case number is required."
    echo "Usage: ./setup_case.sh <case_number>"
    exit 1
fi

BASE_DIR="$HOME/Documents/Snyk/customers"
CASE_DIR="$BASE_DIR/$CASE_NUMBER"

if [ -d "$CASE_DIR" ]; then
    echo "Directory already exists: $CASE_DIR"
else
    mkdir -p "$CASE_DIR"
    echo "Created directory: $CASE_DIR"
fi
