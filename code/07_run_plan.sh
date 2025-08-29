#!/bin/bash

# Job Flags
#SBATCH -N 1 -n 96 -p mit_normal --mem=370G

# Set defaults
DATES=peak
MARKET=full
CYCLES=150.
SHED=true
STRIDE=1
BACKUP=true
NEW_BACKUP=true
MIPGAP=0.001
NEW_STORAGE=true
FREE_STORAGE=false
EXPERIMENT=nothing

# Get runtime arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --dates) DATES="$2"; shift ;;
        --market) MARKET="$2"; shift ;;
        --cycles) CYCLES="$2"; shift ;;
        --shed) SHED="$2"; shift ;;
        --stride) STRIDE="$2"; shift ;;
        --backup) BACKUP="$2"; shift ;;
        --new_backup) NEW_BACKUP="$2"; shift ;;
        --new_storage) NEW_STORAGE="$2"; shift ;;
        --free_storage) FREE_STORAGE="$2"; shift ;;
	    --mipgap) MIPGAP="$2"; shift ;;
        --experiment) EXPERIMENT="$2"; shift ;;
	*) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

# Set log file
case $EXPERIMENT in
    nothing) LOGFILE=results/planning/${DATES}_${MARKET}_${CYCLES}_${SHED}_${STRIDE}_${BACKUP}_${NEW_BACKUP}_${NEW_STORAGE}_${FREE_STORAGE}.log ;;
    *) LOGFILE=results/experiments/${EXPERIMENT}.log ;;
esac

# Run your application
julia +1.11.2 --project=. "code/07_run_plan.jl" -d $DATES -m $MARKET -c $CYCLES -l $SHED -s $STRIDE -b $BACKUP --new_backup $NEW_BACKUP --new_storage $NEW_STORAGE --free_storage $FREE_STORAGE -g $MIPGAP --experiment $EXPERIMENT >> $LOGFILE 2>&1