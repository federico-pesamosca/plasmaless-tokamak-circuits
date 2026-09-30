% run simulator_plasmaless.slx 
% featuring plasmaless circuit model (coil-vessel) in plasmaless_model.slx
% and plot the results

clear 

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
%% plot model
plot_plasmaless_model;