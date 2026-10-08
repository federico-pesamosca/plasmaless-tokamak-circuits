# Plasmaless Tokamak Circuits

A dynamical circuit model of the current response of ITER coils and vessel conductive elements to applied active-coil voltages.

## Installation

Clone the repository on ITER SDCC and load the required modules:

```bash
git clone https://github.com/federico-pesamosca/plasmaless-tokamak-circuits.git
module load IMAS/3.39.0-foss-2023b
module load MATLAB/2023a-r8-GCCcore-13.2.0
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

The circuit response to an input voltage time series Va can be simulated in MATLAB or Simulink. In Simulink mode, `plasmaless_timestep.slx` is included as a referenced model in `simulator_plasmaless_model_simulink.slx`. In MATLAB mode, `simulator_plasmaless_model_matlab.m` executes the simulation loop directly. Both use the shared timestep function, `plasmaless_timestep_forward.m`.

## Use

Set `mode` inside `run_plasmaless_model.m` to select the simulator:

```matlab
mode = 'matlab';    % MATLAB simulation loop (default)
% or
mode = 'simulink';  % Simulink simulation
```

Choose one assignment in the script; setting `mode` in the workspace beforehand will not override it because the script clears the workspace. Then run `run_plasmaless_model` from the project directory in MATLAB.

Both modes use the same input voltages, discrete state-space matrices, and zero initial currents. They return results in `out` for the same plotting script.

Set the timing parameters in `run_plasmaless_model.m`:

| Parameter | Meaning | Current default |
| --- | --- | --- |
| `dt` | Discretization time step | 0.001 s |
| `tstart` | Start of simulation | 0 s |
| `tend` | End of simulation | 28 s |

- **Run the simulation:** `run_plasmaless_model.m` configures the model, runs the selected simulator, and plots the results.
- **Prepare inputs:** `timeseries_plasmaless_model.m` illustrates the structure and format used to create the input voltage time series.
- **Visualize results:** `plot_plasmaless_model.m` plots coil-voltage and current histories and animates the dynamic flux on the DINA grid.
- **Run regression tests:** `tests/test_plasmaless_model.m` contains four tests:
  - a basic run of the scripts
  - the expected response to voltage steps in two superconductive coils
  - the expected response to voltage steps in two resistive coils
  - MATLAB–Simulink output equivalence for the same input waveform and timing, checking matching timestamps and all active/passive current samples within numerical tolerance.

Both simulation modes require MATLAB, Control System Toolbox (for `ss` and `c2d`), IMAS, and access to the IDS data used by the configuration and plotting scripts. Simulink is additionally required for Simulink mode and for running the full regression test suite.

## Licence

This software is open source. ITER-related intellectual property remains &copy; 2026 ITER Organization.

## Contacts

Originally developed in 2026 by Federico Pesamosca (federico.pesamosca@iter.org)
