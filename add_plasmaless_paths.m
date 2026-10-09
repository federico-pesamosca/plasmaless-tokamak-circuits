% add local paths required for plasmales model run
% uses the location of this file as root, so the cloned folder name is irrelevant.

plasmaless_root = fileparts(mfilename('fullpath'));
addpath(genpath(plasmaless_root));
clear plasmaless_root