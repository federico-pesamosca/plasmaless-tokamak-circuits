% plot coil and passive loop currents after run_plasmaless_imas
% (uses time, Ia, Ie, model from the workspace, or loads results_file)
% Panels: (a) CS/PF superconducting coils [A], (b) VS resistive coils [kA],
% (c) passive loops [kA]. Coils are grouped by name (names starting with 'VS').
% Figures hang with MATLAB R2025b on the SDCC login nodes: run this script in
% MATLAB R2024b (module load MATLAB/2024b-r5), it then loads results_file.

if ~exist('results_file','var')
    results_file = '/scratch/users/schneim/plasmaless/plasmaless_imas_results.mat';
end
if ~exist('time','var') || ~exist('Ia','var') || ~exist('Ie','var')
    fprintf('Loading results from %s\n', results_file);
    load(results_file,'time','Ia','Ie','coil_names');
end
if exist('model','var')
    coil_names = model.coil_names;
end
coil_names = cellstr(coil_names);

% coil groups by name
is_vs = strncmpi(strtrim(coil_names),'VS',2);
i_sc = find(~is_vs);
i_vs = find(is_vs);

% decimate for display (software-rendered figures are slow with ~28000 points per line)
step = max(1, ceil(numel(time)/2000));
td = time(1:step:end);

fig = figure('Position',[100 100 900 900]);

ax_a = subplot(3,1,1);
plot_distinct(td, Ia(1:step:end,i_sc));
xlabel('Time [s]'); ylabel('Current [A]');
legend(coil_names(i_sc),'Location','eastoutside','Interpreter','none');
title('(a) CS/PF superconducting coil currents (IMAS interface)');
grid on;

ax_b = subplot(3,1,2);
plot_distinct(td, Ia(1:step:end,i_vs)/1e3);
xlabel('Time [s]'); ylabel('Current [kA]');
legend(coil_names(i_vs),'Location','eastoutside','Interpreter','none');
title('(b) VS resistive coil currents');
grid on;

ax_c = subplot(3,1,3);
plot(td,Ie(1:step:end,:)/1e3);
xlabel('Time [s]'); ylabel('Current [kA]');
title('(c) Passive loop currents');
grid on;

% align panel widths (the legends in a and b shrink their axes)
drawnow;
w = min([ax_a.Position(3) ax_b.Position(3)]);
ax_a.Position(3) = w; ax_b.Position(3) = w; ax_c.Position(3) = w;

[png_dir, png_name] = fileparts(results_file);
png_file = fullfile(png_dir, [png_name '.png']);
exportgraphics(fig, png_file);
fprintf('Figure saved to %s\n', png_file);

function plot_distinct(t, y)
% one colour/line style per curve: lines(7) colours with '-', then '--', ':', '-.'
cols = lines(7);
styles = {'-','--',':','-.'};
hold on;
for k = 1:size(y,2)
    c = cols(mod(k-1,7)+1,:);
    s = styles{mod(floor((k-1)/7),numel(styles))+1};
    plot(t, y(:,k), 'Color', c, 'LineStyle', s, 'LineWidth', 1.2);
end
hold off;
box on;
end
