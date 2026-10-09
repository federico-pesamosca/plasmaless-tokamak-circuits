function [y,xnew] = plasmaless_timestep_forward(u,x,A,B,C,D)
% evolve linear state space model for plasmaless electromagnetic dynamics
% described by A B C D matrices that have been discretized for a specific
% simulation time step for a given input u (voltage on active coils)

xnew = A*x + B*u;
y = C*x + D*u;
