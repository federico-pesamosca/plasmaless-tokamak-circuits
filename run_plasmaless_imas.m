% run the plasmaless coil-vessel model through its IMAS interface
% (same inputs as run_plasmaless_model.m): the model is built from
% machine-description IDSs, and every time step takes a one-slice pf_active
% with the coil voltages at t and returns pf_active/pf_passive currents at t+dt

clearvars -except do_plot
% plot coil currents at the end (set do_plot = 1 before calling to enable).
% Default 0: figures hang with MATLAB R2025b on the SDCC login nodes; plot
% afterwards with plot_plasmaless_imas in MATLAB R2024b
% (module load MATLAB/2024b-r5), which loads the results file.
if ~exist('do_plot','var'), do_plot = 0; end

% IMAS interface functions in imas_model/ (next to this script)
repo_root = fileparts(mfilename('fullpath'));
addpath(fullfile(repo_root,'imas_model'));

%% simulation parameters
tstart = 0;
tend = 28;
dt = 0.001;
write_output = 0;   % 1: write the output slices to out_uri
out_uri = 'imas:hdf5?path=/scratch/users/schneim/plasmaless/run_out';
results_file = fullfile(repo_root,'plasmaless_imas_results.mat');  % saved time, Ia, Ie, names

%% load machine description
% DD4 entry shipped in data/md_dd4, made with tools/convert_md_dd3_to_dd4.py
% (IMAS-MATLAB DD-4.x module)
md_uri = ['imas:hdf5?path=' fullfile(repo_root,'data','md_dd4')];
fprintf('Loading machine description from %s\n', md_uri);
idx = imas_open(md_uri,40);
em_coupling = ids_get(idx,'em_coupling');
pf_active_md = ids_get(idx,'pf_active');
pf_passive_md = ids_get(idx,'pf_passive');
imas_close(idx);
% DD3 alternative (IMAS-MATLAB DD-3.x module):
% idx = imas_open('imas:mdsplus?path=/work/projects/dina/SRO_JINTRAC/15MA_10perc/output',40);
% em_coupling = ids_get(idx,'em_coupling');
% pf_active_md = ids_get(idx,'pf_active');
% imas_close(idx);
% idx = imas_open('imas:mdsplus?path=/work/imas/shared/imasdb/ITER_MD/3/115005/3',40);
% pf_passive_md = ids_get(idx,'pf_passive');
% imas_close(idx);

%% build model and initial state (cold start)
[model, x] = plasmaless_model_from_ids(em_coupling, pf_active_md, pf_passive_md, dt);
fprintf('Model built: %d coils, %d passive loops, dt = %g s\n', model.n_coils, model.n_loops, dt);
% warm start from a one-slice pf_active/pf_passive pair:
% [model, x] = plasmaless_model_from_ids(em_coupling, pf_active_md, pf_passive_md, dt, ...
%     pf_active_slice, pf_passive_slice);

%% prepare inputs
TS = timeseries_plasmaless_model(tstart,tend,dt);

pf_active_in = ids_init('pf_active');
pf_active_in.ids_properties.homogeneous_time = 1;
pf_active_in.coil = ids_allocate('pf_active','coil',model.n_coils);
for ii = 1:model.n_coils
    pf_active_in.coil{ii}.name = model.coil_names{ii};
end

%% run model
time = TS.Time;
nt = numel(time);
Ia = zeros(nt,model.n_coils);
Ie = zeros(nt,model.n_loops);
Ia(1,:) = x(1:model.n_coils);
Ie(1,:) = x(model.n_coils+1:end);
if write_output
    idx_out = imas_open(out_uri,43);
end
fprintf('Running %d steps, t = %g .. %g s\n', nt-1, tstart, tend);
tic;
for k = 1:nt-1
    % one-slice input, as sent by a coupled controller
    pf_active_in.time = time(k);
    for ii = 1:model.n_coils
        pf_active_in.coil{ii}.voltage.data = TS.Data(k,ii);
    end
    [pf_active_out, pf_passive_out, x] = plasmaless_step_ids(model, pf_active_in, x);
    Ia(k+1,:) = cellfun(@(c) c.current.data, pf_active_out.coil);
    Ie(k+1,:) = cellfun(@(l) l.current, pf_passive_out.loop);
    if floor(time(k+1)+1e-9) > floor(time(k)+1e-9)  % progress every simulated second
        fprintf('t = %6.3f s (%3.0f%%), elapsed %.1f s\n', time(k+1), 100*k/(nt-1), toc);
        drawnow;
    end
    if write_output
        if k == 1
            ids_put(idx_out,'pf_active',pf_active_out);
            ids_put(idx_out,'pf_passive',pf_passive_out);
        else
            ids_put_slice(idx_out,'pf_active',pf_active_out);
            ids_put_slice(idx_out,'pf_passive',pf_passive_out);
        end
    end
end
if write_output
    imas_close(idx_out);
end
fprintf('Simulation done in %.1f s wall time\n', toc);

%% save results and plot (post-processing in plot_plasmaless_imas.m)
coil_names = model.coil_names;
loop_names = model.loop_names;
save(results_file,'time','Ia','Ie','coil_names','loop_names','-v7');
fprintf('Results saved to %s\n', results_file);
if do_plot, plot_plasmaless_imas; end
