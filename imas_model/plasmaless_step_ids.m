function [pf_active_out, pf_passive_out, x_new] = plasmaless_step_ids(model, pf_active_in, x)
% one time step of the plasmaless model (as plasmaless_timestep.slx)
% pf_active_in: one slice (homogeneous_time 1) with the coil voltages at t
% x:            state [Ia; Ie] at t
% outputs at t+dt: pf_active coil currents (the input voltages are echoed,
% they are the voltages applied over [t, t+dt]) and pf_passive loop currents

if pf_active_in.ids_properties.homogeneous_time ~= 1 || numel(pf_active_in.time) ~= 1
    error('plasmaless:slice', ['pf_active input must have homogeneous_time 1 and ', ...
        'exactly one time slice (homogeneous_time %d, %d times).'], ...
        pf_active_in.ids_properties.homogeneous_time, numel(pf_active_in.time));
end
t = pf_active_in.time;
if ~isequal(size(x),[model.n_coils+model.n_loops 1])
    error('plasmaless:state','State must be a %dx1 vector.', model.n_coils+model.n_loops);
end

% coil voltages in model order
idx = match_coils(model, pf_active_in);
u = zeros(model.n_coils,1);
for ii = 1:model.n_coils
    v = pf_active_in.coil{idx(ii)}.voltage.data;
    if numel(v) ~= 1 || v == -9e40 || ~isfinite(v)
        error('plasmaless:voltage','pf_active coil %s: expected one voltage value at t = %g, got %d.', ...
            model.coil_names{ii}, t, numel(v));
    end
    u(ii) = v;
end

% state update: use the same function of simulator_plamaless_model (matlab/simulink)
% x_new = model.A*x + model.B*u;
[~,x_new] = plasmaless_timestep_forward(u,x,model.A,model.B,model.C,model.D);

% outputs
pf_active_out = ids_init('pf_active');
pf_active_out.ids_properties.homogeneous_time = 1;
pf_active_out.ids_properties.comment = 'plasmaless coil-vessel model: coil currents';
pf_active_out.time = t + model.dt;
pf_active_out.coil = ids_allocate('pf_active','coil',model.n_coils);
for ii = 1:model.n_coils
    pf_active_out.coil{ii}.name = model.coil_names{ii};
    if isfield(pf_active_out.coil{ii},'identifier')
        pf_active_out.coil{ii}.identifier = model.coil_names{ii};
    end
    pf_active_out.coil{ii}.current.data = x_new(ii);
    pf_active_out.coil{ii}.voltage.data = u(ii);
end

pf_passive_out = ids_init('pf_passive');
pf_passive_out.ids_properties.homogeneous_time = 1;
pf_passive_out.ids_properties.comment = 'plasmaless coil-vessel model: passive loop currents';
pf_passive_out.time = t + model.dt;
pf_passive_out.loop = ids_allocate('pf_passive','loop',model.n_loops);
for ii = 1:model.n_loops
    pf_passive_out.loop{ii}.name = model.loop_names{ii};
    pf_passive_out.loop{ii}.current = x_new(model.n_coils+ii);
end

end

function key = coil_key(coil)
% short coil key (e.g. 'CS3U', 'VS3U') of a pf_active.coil{i} element
% DD3: identifier when present and non-empty, else name
% DD4: name; a long name 'Long description (KEY)' gives 'KEY'

if isfield(coil,'identifier') && ~isempty(strtrim(coil.identifier))
    key = coil.identifier;
else
    key = coil.name;
    tok = regexp(key,'\(([^()]*)\)','tokens','once');
    if ~isempty(tok)
        key = tok{1};
    end
end
key = strtrim(key);
if isempty(key)
    error('plasmaless:coilName','pf_active coil without name/identifier.');
end

end

function idx = match_coils(model, pf_active)
% indices of the model coils in pf_active.coil, matched by short name
% error if a model coil is missing or pf_active has other coils

names = cellfun(@coil_key, pf_active.coil(:)', 'UniformOutput', false);
extra = setdiff(names, model.coil_names);
if ~isempty(extra) || numel(names) ~= model.n_coils
    error('plasmaless:coils','pf_active coils {%s} do not match the model coils {%s}.', ...
        strjoin(names,','), strjoin(model.coil_names,','));
end
[~, idx] = ismember(model.coil_names, names);
if any(idx == 0)
    error('plasmaless:coils','pf_active misses coils %s.', ...
        strjoin(model.coil_names(idx == 0),','));
end
end
