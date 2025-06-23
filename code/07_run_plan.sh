#!/bin/bash

# Job Flags
#SBATCH -N 1 -n 96 -p mit_normal --mem=370G

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

# Set log file
LOGFILE=results/planning/${DATES}${MARKET}${CYCLES}.log

# Run your application
julia +1.11.2 --project=. "code/07_run_plan.jl" -d $DATES -m $MARKET -c $CYCLES >> $LOGFILE 2>&1
