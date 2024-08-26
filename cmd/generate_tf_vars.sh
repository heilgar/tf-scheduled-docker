#!/bin/bash

# Check if .env file exists
if [ ! -f ../.env ]; then
    echo ".env file not found!"
    exit 1
fi

# Read .env and create terraform.tfvars
while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip comments and empty lines
    if [[ $line =~ ^#.*$ ]] || [[ -z $line ]]; then
        continue
    fi
    
    # Extract variable name and value
    if [[ $line =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
        name="${BASH_REMATCH[1]}"
        value="${BASH_REMATCH[2]}"
        
        # Remove surrounding quotes if present
        value="${value#\"}"
        value="${value%\"}"
        
        # Write to terraform.tfvars
        echo "$name = \"$value\"" >> terraform.tfvars
    fi
done < .env

echo "terraform.tfvars generated successfully!"