function [sysd_plasmaless,A,B,C,D,in_label,out_label] = configure_plasmaless_model(dt)
% initialize plasmaless coil vessel dynamical model for ITER

% reocover mutuals from IMAS
ids_idx = imas_open('imas:mdsplus?path=/work/projects/dina/SRO_JINTRAC/15MA_10perc/output' );
em_coupling = ids_get(ids_idx,'em_coupling');
pf_active = ids_get(ids_idx,'pf_active');
ids_idx = imas_open_env('ids', 115005, 3, 'public','ITER_MD', '3');
pf_passive = ids_get(ids_idx,'pf_passive');
Maa = em_coupling.mutual_active_active;
Mea = em_coupling.mutual_passive_active;
Mee = em_coupling.mutual_passive_passive;
M = [Maa Mea' ; Mea Mee];

% fix resistance
Raa = zeros(size(Maa));
Raa(end-1:end,end-1:end) = blkdiag(pf_active.coil{13}.resistance,pf_active.coil{13}.resistance); % manually fixed VS3
for ii = 1:size(Mee,1)
    Ree(ii,ii) = pf_passive.loop{ii}.resistance; 
end
R = blkdiag(Raa,Ree);

% load labels
for ii = 1:size(Maa,1)
    if ii<=6
        label_a{ii} = ['Ia',pf_active.coil{ii}.name(end-4:end-1)];
    else
        label_a{ii} = ['Ia',pf_active.coil{ii}.name(end-3:end-1)];
    end
    in_label{ii} = ['V',label_a{ii}(2:end)];
end
for ii = 1:size(Mee,1)
    str = pf_passive.loop{ii}.name;
    label_e{ii} = ['Ie',str(2:end)];
end
out_label = [label_a label_e];

% build state space
Ac = -M\R; Bc = M\eye(size([Maa;Mea]));
Cc = eye(size(M)); Dc = zeros(size(Cc,1),size(Bc,2));
sys = ss(Ac,Bc,Cc,Dc);
sys.InputName = in_label;
sys.OutputName = out_label;
sysd_plasmaless = c2d(sys,dt);
A = sysd_plasmaless.A;
B = sysd_plasmaless.B;
C = sysd_plasmaless.C;
D = sysd_plasmaless.D;

% % build input bus
% for k = 1:numel(in_label)
%     elems_in(k) = Simulink.BusElement;
%     elems_in(k).Name = char(in_label(k));
%     elems_in(k).DataType = 'double';
% end
% InBus_plasmaless = Simulink.Bus;
% InBus_plasmaless.Elements = elems_in;
% 
% % build output bus
% for k = 1:numel(out_label)
%     elems_out(k) = Simulink.BusElement;
%     elems_out(k).Name = char(out_label(k));
%     elems_out(k).DataType = 'double';
% end
% OutBus_plasmaless = Simulink.Bus;
% OutBus_plasmaless.Elements = elems_out;

end



