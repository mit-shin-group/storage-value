#!/bin/bash
for m in no_exports peak_shaving; do
    for g in 74.0 36.0; do
        for s in $(seq 0 15); do
            echo "Running: julia julia --threads 8 --project=. code/06_run_ops.jl -d code/06_dates.txt -m $m -g $g -s $s"
            julia --threads 8 --project=. code/06_run_ops.jl -d code/06_dates.txt -m $m -g $g -s $s
        done
    done
done