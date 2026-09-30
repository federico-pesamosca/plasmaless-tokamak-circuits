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

The Simulink model `plasmaless_timestep.slx` is included as a referenced model in `simulator_plasmaless_model.slx`. It evolves the circuit response to an input voltage time series Va.

## Use

- **Run the simulation:** `run_plasmaless_model.m` configures and runs `simulator_plasmaless_model.slx`, then plots the results. Adapt it to set the simulation parameters and input for your application. Only required parameters
  - dt: discretization time
  - tstart: start of simulation
  - tend: end of simulation
- **Prepare inputs:** `timeseries_plasmaless_model.m` illustrates the structure and format used to create the input voltage time series.
- **Visualize results:** `plot_plasmaless_model.m` plots coil-voltage and current histories and animates the dynamic flux on the DINA grid.
- **Run regression tests:** `tests/test_plasmaless_model.m` contains three tests:
  - a basic run of the scripts
  - the expected response to voltage steps in two superconductive coils
  - the expected response to voltage steps in two resistive coils.

The simulation and tests require MATLAB, Simulink, IMAS, and access to the IDS data used by the scripts.

## Licence

This software is open source. ITER-related intellectual property remains &copy; 2026 ITER Organization.

## Contacts

Originally developed in 2026 by Federico Pesamosca (federico.pesamosca@iter.org)
