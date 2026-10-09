# Plasmaless Tokamak Circuits

A dynamical circuit model of the current response of ITER coils and vessel conductive elements to applied active-coil voltages.

## Installation

The original model lives at https://github.com/federico-pesamosca/plasmaless-tokamak-circuits. The IMAS interface, the MUSCLE3 actor and the DD4 machine description (`data/md_dd4`) are on branch `IMAS_Muscle3` clone that version on ITER SDCC:

```bash
git clone -b IMAS_Muscle3 https://github.com/federico-pesamosca/plasmaless-tokamak-circuits.git
```

Load the module matching what you run (see also `howto.txt`):

```bash
# IMAS version (run_plasmaless_imas)
module purge; module load IMAS-MATLAB/5.6.0-intel-2025b-DD-4.1.1
# original Simulink version (run_plasmaless_model; reads the DD3 em_coupling fields)
module purge; module load IMAS-MATLAB/5.6.0-intel-2025b-DD-3.42.2
# plotting (plot_plasmaless_imas): figures hang with MATLAB R2025b on the SDCC login nodes
module purge; module load MATLAB/2024b-r5
# MUSCLE3 standalone run (loads its own modules)
muscle3/run_plasmaless_muscle3.sh
```

No separate installation is required. The scripts retrieve local IDS data for circuit parameters and geometry, so the required IDS data must be accessible from your environment.

## Description

The model evolves the coupled circuit dynamics of the ITER active coils, \(a\), and passive vessel conductive elements, \(e\). For applied active-coil voltages **Va**, the circuit equations are

|&nbsp; Maa&nbsp; Mae&nbsp; |&nbsp; |&nbsp; dIa/dt&nbsp; | + |&nbsp; Ra&nbsp; 0&nbsp; |&nbsp; |&nbsp;Ia&nbsp;| = |&nbsp;Va| \
|&nbsp; Mea&nbsp; Mee&nbsp; |&nbsp; |&nbsp; dIe/dt&nbsp; |&nbsp;&nbsp;&nbsp;   |&nbsp; 0&nbsp; Re&nbsp; |&nbsp; |&nbsp;Ie&nbsp;|&nbsp;&nbsp;&nbsp; |&nbsp; 0&nbsp;|

Here, **M** is the mutual-inductance matrix, **R** contains the circuit resistances, and **Ia** and **Ie** are the active- and passive-element currents. Magnetic flux on the DINA grid is computed from the currents as

psi = Mxi |&nbsp;I_a&nbsp;|
          |&nbsp;I_e&nbsp;|

where **Mxi** is the Green’s-function matrix mapping conductor currents to flux on that grid. For ITER, **Ra = 0** (superconductivity) is assumed for all coils **except the VS** (vertical stabilization) circuit.

The Simulink model `plasmaless_timestep.slx` is included as a referenced model in `simulator_plasmaless_model.slx`. It evolves the circuit response to an input voltage time series Va.

## MATLAB/Simulink basic simulation
- **Add the local paths**
run `add_plasmaless_paths.m` to add the local subfolders.
- **Run the simulation:** `run_plasmaless_model.m` configures and runs `simulator_plasmaless_model.slx` (IMAS-MATLAB DD-3.x module: it reads the DD3 `em_coupling` fields), saves `time`, `Ia`, `Ie` and the coil/loop names to `plasmaless_simulink_results.mat` in the repository root (same variables, units and names as `run_plasmaless_imas.m`), and plots the results with `plot_plasmaless_model.m` if `do_plot = 1` is set before the call (default 0, see below). Adapt it to set the simulation parameters and input for your application.
  Set `mode` inside `run_plasmaless_model.m` to select the simulator:
  ```matlab
  mode = 'matlab';    % MATLAB simulation loop (default)
  % or
  mode = 'simulink';  % Simulink simulation
  ```
  Only required parameters
  - dt: discretization time
  - tstart: start of simulation
  - tend: end of simulation
    
- **Prepare inputs:** `timeseries_plasmaless_model.m` illustrates the structure and format used to create the input voltage time series.
- **Visualize results:** `plot_plasmaless_model.m` plots coil-voltage and current histories and animates the dynamic flux on the DINA grid.
- **Run regression tests:** `tests/test_plasmaless_model.m` contains four tests:
  - a basic run of the scripts
  - the expected response to voltage steps in two superconductive coils
  - the expected response to voltage steps in two resistive coils
  - MATLAB–Simulink output equivalence for the same input waveform and timing, checking matching timestamps and all active/passive current samples within numerical tolerance.

Both simulation modes require MATLAB, Control System Toolbox (for `ss` and `c2d`), IMAS, and access to the IDS data used by the configuration and plotting scripts. Simulink is additionally required for Simulink mode and for running the full regression test suite.

## IMAS interface (imas_model/)

The same model as plain MATLAB functions with IDS inputs and outputs, for use as a step in a coupled workflow. The model is built once, then stepped once per time step:

- Build once: `[model, x0] = plasmaless_model_from_ids(em_coupling, pf_active, pf_passive, dt)` builds **M**, **R**, the continuous state space and its `c2d` discretization exactly as `configure_plasmaless_model.m`. Each coil resistance is read from `pf_active.coil{i}.resistance` (with the DINA data this gives the same values as the original VS3 fix). Missing resistances or inconsistent sizes raise an error. With these four inputs `x0` is zero (cold start). For a warm start, add a one-slice pair: `[model, x0] = plasmaless_model_from_ids(..., dt, pf_active_init, pf_passive_init)` takes the coil currents (matched by short name) and the loop currents (by position, names checked).
- Per step: `[pf_active_out, pf_passive_out, x] = plasmaless_step_ids(model, pf_active_in, x)` is the main function. It stands in for NICE in a coupled workflow and performs one time step, `x_new = A*x + B*u`, as `plasmaless_timestep.slx`.
  - Input: a one-slice `pf_active` (`homogeneous_time = 1`, a single time `t`) with one `coil{i}.voltage.data` value per coil. Coils are matched by short name (CS3U ... PF6, VS3U, VS3L). A missing coil, an extra coil or a missing voltage raises an error.
  - Output: `pf_active` with the coil currents and `pf_passive` with the loop currents, both at `t + dt`. The `pf_active` output also echoes the voltages applied over [t, t+dt].
- Example driver: `run_plasmaless_imas.m` (repo root, next to `run_plasmaless_model.m`; type `run_plasmaless_imas` from the repo root) uses the same input voltages as `run_plasmaless_model.m`, sends one input slice per step, and can write the output slices with `ids_put_slice`.
  It reads the machine description shipped in `data/md_dd4` and saves `time`, `Ia`, `Ie` and the coil/loop names to `results_file` (default `plasmaless_imas_results.mat` in the repository root; generated result files are ignored by git). The post-processing script `plot_plasmaless_imas.m` reloads this file (or the file named by `results_file` if set before the call, e.g. `results_file = 'plasmaless_simulink_results.mat'` or `'plasmaless_muscle3_results.mat'`), plots the CS/PF coil currents (A), the VS coil currents (kA) and the passive loop currents (kA) in three panels, and saves the figure as a PNG next to the results file. It works from a fresh MATLAB R2024b session (`module load MATLAB/2024b-r5`, IMAS not needed).
  MATLAB R2025b (used by the IMAS-MATLAB module) hangs on figure rendering/export on the SDCC login nodes, so `do_plot` defaults to 0; set `do_plot = 1` before calling `run_plasmaless_imas` to plot at the end of the run.

Both DD3 and DD4 `em_coupling` are supported: DD3 through the `mutual_*` fields, DD4 through `coupling_matrix` entries named `mutual_active_active`, `mutual_passive_active` and `mutual_passive_passive`. The DD4 IMAS-MATLAB API returns an empty `coupling_matrix` when it reads the DD3 DINA entry. A DD4 machine-description entry is therefore shipped with the model in `data/md_dd4` (`em_coupling`, `pf_active`, `pf_passive`; not pulse-specific; default of `run_plasmaless_imas.m` and of the MUSCLE3 actor). It was made with `tools/convert_md_dd3_to_dd4.py` (imas-python), which writes to `data/md_dd4` by default. This tool copies the three conductor mutual-inductance matrices unchanged (it does not copy the grid matrices), converts `pf_active` (without its time-dependent data) and `pf_passive` 115005/3 to DD 4.1.1, then rereads the entry and checks it against the DD3 source:

```bash
module use /work/projects/pds/modules/all; module load IMAS-MUSCLE3/1.0.0-intel-2025b-pds
python tools/convert_md_dd3_to_dd4.py   # or --output-uri "imas:hdf5?path=<dir>/md_dd4"
module purge; module load IMAS-MATLAB/5.6.0-intel-2025b-DD-4.1.1
```

Limitations:
- The inputs are coil voltages only. There is no supply/circuit-to-coil mapping, so CS1U/CS1L and VS3U/VS3L are treated as independent coil voltages, as in the original model.
- There is no flux output on the DINA grid yet.

## PDS integration

The model runs in IMAS-PDS as the `plasmaless` actor of the `plasmaless_controller` workflow (branch `feature/plasmaless_controller`), closed on the PCS magnetic controller. How to run it and the standalone checks: `instructions.txt`. How the integration was done: `pds_integration.txt`.

## Licence

This software is open source. ITER-related intellectual property remains &copy; 2026 ITER Organization.

## Contacts

Originally developed in 2026 by Federico Pesamosca (federico.pesamosca@iter.org)

IMAS interfacing and MUSCLE3 adaptation by Mireille Schneider (mireille.schneider@iter.org)
