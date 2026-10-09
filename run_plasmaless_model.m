% run simulator_plasmaless.slx 
% featuring plasmaless circuit model (coil-vessel) in plasmaless_model.slx
% and plot the results

clear 

%% flag for executing matlab or simulink mode
mode = 'matlab'; % 'matlab' or 'simulink'

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
switch mode
    case 'simulink'
        out = sim('simulator_plasmaless_model_simulink.slx');
        out.signalNames = out_label;
    case 'matlab'
        out = simulator_plasmaless_model_matlab(TS,A,B,C,D,x0,out_label);
end
%% plot model
plot_plasmaless_model;