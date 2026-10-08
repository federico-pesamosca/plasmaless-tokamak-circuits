% run simulator_plasmaless.slx 
% featuring plasmaless circuit model (coil-vessel) in plasmaless_model.slx
% and plot the results

clearvars -except do_plot
% plot at the end (set do_plot = 1 before calling to enable). Default 0:
% plotting in R2025b hangs on SDCC login nodes; plot afterwards in R2024b with
%   results_file = 'plasmaless_simulink_results.mat'; plot_plasmaless_imas
if ~exist('do_plot','var'), do_plot = 0; end

%% simulation parameters
tstart = 0;
tend = 28;
dt = 0.001;

%% load model
[sysd_plasmaless,A,B,C,D,in_label,out_label] = configure_plasmaless_model(dt);

%% prepare timeseries
TS = timeseries_plasmaless_model(tstart,tend,dt);
x0 = zeros(size(A,1),1);

%% run model
out = sim('simulator_plasmaless_model.slx');
out.signalNames = out_label;

%% save results (same variables and units as run_plasmaless_imas.m)
time = out.simout.Time;
y = squeeze(out.simout.Data);
if size(y,1) ~= numel(time), y = y.'; end
n_coils = numel(in_label);
Ia = y(:,1:n_coils);
Ie = y(:,n_coils+1:end);
% coil names: pf_active identifiers of the configure_plasmaless_model entry
% (CS3U..PF6, VS3U, VS3L; its labels say VSU/VSL), as run_plasmaless_imas.m
ids_idx = imas_open('imas:mdsplus?path=/work/projects/dina/SRO_JINTRAC/15MA_10perc/output');
pf_active = ids_get(ids_idx,'pf_active');
imas_close(ids_idx);
coil_names = cellfun(@(c) strtrim(c.identifier), pf_active.coil(1:n_coils)', 'UniformOutput', false);
loop_names = regexprep(out_label(n_coils+1:end),'^Ie','');
results_file = fullfile(fileparts(mfilename('fullpath')),'plasmaless_simulink_results.mat');
save(results_file,'time','Ia','Ie','coil_names','loop_names','-v7');
fprintf('Results saved to %s\n', results_file);

%% plot model
if do_plot, plot_plasmaless_model; end