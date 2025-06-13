#!/bin/bash

# Job Flags
#SBATCH -N 1 -n 48 -p mit_quicktest --mem=96G

# Get the directory where the script lives
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Set root project directory (one level above script)
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Set defaults
DATES=peak
MARKET=full
CYCLES=150.

# Get runtime arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --dates) DATES="$2"; shift ;;
        --market) MARKET="$2"; shift ;;
        --cycles) CYCLES="$2"; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

# Run your application
julia +1.11.2 --project="$ROOT_DIR" "$SCRIPT_DIR/07_run_plan.jl" -d $DATES -m $MARKET -c $CYCLES