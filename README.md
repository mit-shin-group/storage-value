# The Value of Storage in Electricity Distribution: The Role of Markets

This repository supplements the paper "The value of storage in electricity distribution: The role of markets" by [Dirk Lauinger](https://www.dirklauinger.com/), [Deepjyoti Deka](https://deepjyotideka.github.io/), and [Sungho Shin](https://shin.mit.edu/), available at [https://arxiv.org/abs/2510.12435](https://arxiv.org/abs/2510.12435). This project was funded by the [Future Energy Systems Center](https://energy.mit.edu/futureenergysystemscenter/) at the MIT Energy Initiative.

The folder `code` contains:
- `01_data.jl`, which is used to generate and populate a data structure for the investment planning optimization problem (B1);
- `02_peak_shaving_potential.jl`, which is used for generating the data underlying Figure A3 and can be used to determine the upper bound $\bar x_\mathrm{s}$ on storage investment levels;
- `03_model.jl`, which is a numerical implementation of problem (B1);
- `04_analysis.jl`, which is used to analyze the results of the numerical experiments and compile Table C1, generate the data underlying Figures 5, 6, and C1, and to generate Figure C1;
- `05_run_plan.jl`, which is used to run an instance of the planning problem specified by command line arguments;
- `05_run_plan.sh`, which is used to run `05_run_plan.jl`;
- `06_run_analysis_experiment.jl`, which is used to run `04_analysis.jl` with a command line argument;
- `06_run_analysis_experiment.sh`, which is used to run `06_run_analysis_experiment.jl`;
- `ex1.sh` ... `ex9.sh`, which are used to run the numerical experiments in Table C1.

The folder `data` contains:
- `eia-860/`, which contains the file `december_generator2025.xlsx`, available from the [Preliminary Monthly Electric Generator Inventory](https://www.eia.gov/electricity/data/eia860m/) by the US Energy Information Administration;
- `ISONE_data/`, which contains the files `nodalloadweights_4006_202401.csv` ... `nodalloadweights_4006_202412.csv`, available from the [ISO New England](https://www.iso-ne.com/isoexpress/web/reports/load-and-demand/-/tree/network-nodel);
- `nrel_battery_cost/`, which contains the files `2019.txt` ... `2025.txt`, each representing NREL cost projections on utility-scale battery storage. The 2025 projections are available at [https://docs.nrel.gov/docs/fy25osti/93281.pdf](https://docs.nrel.gov/docs/fy25osti/93281.pdf);
- `data_analysis_2024.ipynb`, which analyzes electricity price and demand data from `ISONE_data/` and is used to create Figure 2 and the data file `Nantucket_2024.csv`. This file is read by `code/01_data.jl` when populating the data structure for the investment planning problem;
- `data_to_json.jl`, which is used to build the data file `nantucket.json` for the numerical case study. This file is also read by `code/01_data.jl` when populating the data structure for the investment planning problem;
- `nrel_battery_costs.ipynb`, which reads the data in `nrel_battery_cost/` to create Figure A1;
- `storage_eia860.ipynb`, which reads the data in `eia-860/` to compute the numbers on installed US battery storage in Section A.1 of the paper.

The folder `pics` contains:
- `battery_cost.pdf` and `battery_cost.svg`, which correspond to Figure A1.
- `heatmap.pdf`, which corresponds to Figure 6;
- `load_24.pdf`, `load_24.svg`, `price_24.pdf`, and `price_24.svg` which correspond to Figure 2.

The folder `results` contains:
- `experiments/`, which contains the `.jld` and `.log` files for each of the nine numerical experiments;
- `planning/`, which is empty and used by default to log results that do not correspond to one of the nine experiments;
- `potential.txt`, which shows the maximum peak shaving potential and the battery power and energy capacity required to achieve that potential for various roundtrip efficiencies in the Nantucket case study. This data is used to generate Figure A3.

All numerical experiments were conducted on AMD EPYC 9474F CPUs with 48 cores, a 3.6GHz base clock, and 376GB of RAM. The experiments were implemented in Julia 1.11.2 using JuMP 1.23.5 with Gurobi 12.0.2.