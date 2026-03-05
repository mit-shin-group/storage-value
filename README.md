# The Value of Storage in Electricity Distribution: The Role of Markets

This repository supplements the paper **"The value of storage in electricity distribution: The role of markets"** by [Dirk Lauinger](https://www.dirklauinger.com/), [Deepjyoti Deka](https://deepjyotideka.github.io/), and [Sungho Shin](https://shin.mit.edu/), available at [https://arxiv.org/abs/2510.12435](https://arxiv.org/abs/2510.12435), and funded by the [Future Energy Systems Center](https://energy.mit.edu/futureenergysystemscenter/) at the MIT Energy Initiative.

## Repository Structure

The repository is organized as follows:
- `code/` Data structure, optimization model, and experiment scripts;
- `data/` Input data and preprocessing scripts;
- `pics/` Figures reproduced in the paper;
- `results/` Output files from numerical experiments.

## Reproducing the Numerical Experiments

### Software Requirements

The numerical experiments were implemented using:

- Julia 1.11.2  
- JuMP 1.23.5  
- Gurobi 12.0.2  

A valid Gurobi license is required to run the optimization model. To install Julia dependencies, run this command in bash

```bash
sh start_julia.sh
```

followed by this command in Julia

```julia
]
instantiate
```

### Hardware Setup

All numerical experiments were conducted on AMD EPYC 9474F CPUs with 48 cores, a 3.6GHz base clock, and 376GB of RAM. On this hardware, running all nine experiments in Table C1 sequentially took 18 hours. 

### Running the Experiments

Run the experiments as follows:

```bash
sh code/ex1.sh
...
sh code/ex9.sh
```

Results are written to `results/experiments/`.

### Analyzing the Results
Obtain the data in Table C1 for each experiment by running:
```bash
sh code/06_run_analysis_experiment.sh ex1
...
sh code/06_run_analysis_experiment.sh ex9
```

## Code Description

The folder `code/` contains:
- `01_data.jl`: Generates and populates a data structure for the investment planning optimization problem (B1);
- `02_peak_shaving_potential.jl`: Generates the data underlying Figure A3 and can be used to determine the upper bound $\bar x_\mathrm{s}$ on storage investment levels;
- `03_model.jl`: Numerical implementation of problem (B1);
- `04_analysis.jl`: Analyzes the results of the numerical experiments and compiles Table C1, generates the data underlying Figures 5, 6, and C1, and generates Figure C1;
- `05_run_plan.jl`: Runs an instance of the planning problem specified by command line arguments;
- `05_run_plan.sh`: Runs `05_run_plan.jl`;
- `06_run_analysis_experiment.jl`: Runs `04_analysis.jl` with a command line argument;
- `06_run_analysis_experiment.sh`: Runs `06_run_analysis_experiment.jl`;
- `ex1.sh` ... `ex9.sh`: Run the numerical experiments in Table C1.

## Data Description
The folder `data/` contains all datasets used in the numerical experiments.

### Nantucket Electricity Demand and Prices
`ISONE_data/` contains
```
nodalloadweights_4006_202401.csv
...
nodalloadweights_4006_202412.csv
```
These files are available from the [ISO New England](https://www.iso-ne.com/isoexpress/web/reports/load-and-demand/-/tree/network-nodel).

The data is analyzed in `data_analysis_2024.ipynb` and used to create Figure 2 and the data file `Nantucket_2024.csv`, which is used by `code/01_data.jl` when populating the data structure for the investment planning problem.

### US Installed Generation Capacity
`eia-860/` contains
```
december_generator2025.xlsx
```
This file is available from the [Preliminary Monthly Electric Generator Inventory](https://www.eia.gov/electricity/data/eia860m/) by the US Energy Information Administration and analyzed in `storage_eia860.ipynb` to compute the numbers on installed US battery storage in Section A.1 of the paper.

### Battery Cost Projections
`nrel_battery_cost/` contains
```
2019.txt
...
2025.txt
```
These files represent NREL cost projections on utility-scale battery storage. The 2025 projections are available at [https://docs.nrel.gov/docs/fy25osti/93281.pdf](https://docs.nrel.gov/docs/fy25osti/93281.pdf). The data is analyzed in `nrel_battery_costs.ipynb` to create Figure A1.

### Other Data
`data_to_json.jl` builds the data file `nantucket.json` for the numerical case study. This file is read by `code/01_data.jl` when populating the data structure for the investment planning problem.

## Figures
The folder `pics/` contains figures reproduced in the paper:
- `battery_cost.pdf` and `battery_cost.svg` for Figure A1;
- `heatmap.pdf` for Figure 6;
- `load_24.pdf`, `load_24.svg`, `price_24.pdf`, and `price_24.svg` for Figure 2.

## Results
The folder `results/` contains outputs from numerical experiments:
- `experiments/` contains `.jld` and `.log` files for each of the nine numerical experiments;
- `planning/` is empty and used by default to log results that do not correspond to any of the nine experiments;
- `potential.txt` shows the maximum peak shaving potential and the battery power and energy capacity required to achieve that potential for various roundtrip efficiencies in the Nantucket case study. This data is used to generate Figure A3.
