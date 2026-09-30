classdef test_plasmaless_model < matlab.unittest.TestCase
    % Unit tests for the plasmaless coil-vessel circuit model.
    %
    % Simulink (sim()) resolves variables (bus objects, state-space
    % matrices, timeseries, ...) from the BASE workspace, not from the
    % test method's local workspace. Every variable normally created by
    % run_plasmaless_model.m is therefore pushed to the base workspace
    % with assignin(), and the simulation/plot routines are executed
    % with evalin('base', ...) so they see exactly the same context as
    % when run manually.
    %
    % Tests are kept short (small tend, few frames) so they run fast.
    % Three main tests
    % 1) test_basic_run (run all the scripts)
    % 2) test_superconductive_coil (expected step response for CS3U/PF1)
    % 3) test_resistive_coils (expected step resp for VS3)
    properties
        modelName = 'simulator_plasmaless_model';
        rootDir
    end

    methods (TestClassSetup)
        function addModelToPath(testCase)
            % tests/ is one level below the project root
            testCase.rootDir = fileparts(fileparts(mfilename('fullpath')));
            addpath(testCase.rootDir);
        end
    end

    methods (TestMethodSetup)
        function freshBaseWorkspace(testCase)
            % Start every test from a clean base workspace and close any
            % figures left over from a previous test/run.
            evalin('base','clear');
            close all force;
            testCase.addTeardown(@() close('all','force'));
            testCase.addTeardown(@() evalin('base','clear'));
        end
    end

    methods (Test)

        function test_basic_run(testCase)
            % Basic smoke test: configure the model, run the simulation
            % and the plotting routine with a short time horizon, and
            % verify that nothing throws an error/warning.

            % --- same initialization as run_plasmaless_model.m ---
            assignin('base','tstart',0);
            assignin('base','tend',28);   % short horizon -> fast test
            assignin('base','dt',0.01);

            evalin('base', ...
                ['[sysd_plasmaless,A,B,C,D,InBus_plasmaless,OutBus_plasmaless] = ', ...
                 'configure_plasmaless_model(dt);']);

            evalin('base', ...
                'TS = timeseries_plasmaless_model(tstart,tend,dt);');
            evalin('base','x0 = zeros(size(A,1),1);');

            % --- run model ---
            testCase.verifyWarningFree( ...
                @() evalin('base', ...
                    "out = sim('simulator_plasmaless_model.slx');"), ...
                'Simulink simulation raised a warning.');

            % sanity check on simulation output
            out = evalin('base','out');
            testCase.verifyClass(out.simout.Data, 'double');
            testCase.verifyGreaterThan(numel(out.simout.Time), 1);

            % --- plot model (reduced number of frames for speed) ---
            evalin('base','Nframes = 3;'); %#ok<NASGU>
            testCase.verifyWarningFree( ...
                @() evalin('base','plot_plasmaless_model;'), ...
                'Plotting routine raised a warning.');
        end

        function test_superconductive_coil(testCase)
            % Coils 1-12 are superconductive; coils 13/14 and the
            % passive structures are resistive. With zero initial
            % currents and a positive voltage step on one coil only,
            % the driven current slope decreases from V*(M\e_k)(k)
            % toward V/LeffSC, where LeffSC is the Schur complement
            % over the other superconductive coils. Both bounds are
            % at least V/Lkk. The tail need not have settled by 20s.
            % Drive CS3U and PF1 separately and check current and slope.

            assignin('base','tstart',0);
            assignin('base','tend',20);
            assignin('base','dt',0.05); % coarser dt -> fast test

            evalin('base', ...
                ['[sysd_plasmaless,A,B,C,D,InBus_plasmaless,OutBus_plasmaless] = ', ...
                 'configure_plasmaless_model(dt);']);
            evalin('base','x0 = zeros(size(A,1),1);');

            V = 1;               % [V] step amplitude
            tol_rel = 1e-6;      % relative numerical slack on slope bounds
            debugme = 0;        % Set to 1 to plot; close the figure to resume.

            if debugme == 1
                debugFig = figure('Name', ...
                    'Superconductive coil currents - close to resume test', ...
                    'NumberTitle', 'off');
                debugLayout = tiledlayout(debugFig, 2, 1);
            end

            for coilName = {'CS3U','PF1'}
                [coilIdx, Lkk, M] = test_plasmaless_model.getCoilInfo(coilName{1});
                testCase.assertLessThanOrEqual(coilIdx, 12, ...
                    sprintf(['Coil %s is expected to be superconductive ', ...
                    '(index <= 12); check model assumptions.'], coilName{1}));

                tstart = evalin('base','tstart');
                tend   = evalin('base','tend');
                dt     = evalin('base','dt');
                t = (tstart:dt:tend)';
                u = zeros(numel(t),14);
                u(:,coilIdx) = V;
                TS = timeseries(u,t); %#ok<NASGU>
                TS.Name = 'InputSignals';
                assignin('base','TS',TS);

                testCase.verifyWarningFree( ...
                    @() evalin('base', ...
                        "out = sim('simulator_plasmaless_model.slx');"), ...
                    sprintf('Simulation raised a warning for coil %s.', coilName{1}));

                out = evalin('base','out');
                Ik = out.simout.Data(:,coilIdx);
                time = out.simout.Time;

                % --- check 1: current at tend exceeds the naive,
                % uncoupled estimate Imin = (V/Lkk)*tend ---
                Imin = (V/Lkk)*tend;
                testCase.verifyGreaterThan(Ik(end), Imin, ...
                    sprintf(['Coil %s: I(end) = %.4g is not above the ', ...
                    'uncoupled estimate Imin = %.4g A. Coupling with ', ...
                    'other superconductive coils was expected to ', ...
                    'reinforce the current.'], coilName{1}, Ik(end), Imin));

                % --- check 2: tail slope obeys the RL step bounds ---
                otherSC = setdiff(1:12, coilIdx);
                m = M(otherSC,coilIdx);
                LeffSC = Lkk - M(coilIdx,otherSC)*(M(otherSC,otherSC)\m);
                testCase.assertGreaterThan(LeffSC, 0, ...
                    'Superconductive effective inductance must be positive.');

                % Solve using the full matrix, including resistive coils
                % and passive structures, without explicitly inverting it.
                ek = zeros(size(M,1),1);
                ek(coilIdx) = 1;
                initialResponse = M\ek;
                slope_lower = V/LeffSC;
                slope_upper = V*initialResponse(coilIdx);

                if debugme == 1
                    ax = nexttile(debugLayout);
                    % Integrate the slope bounds from zero initial current.
                    elapsed = time - tstart;
                    plot(ax, time, Ik, 'LineWidth', 1.5, ...
                        'DisplayName', 'Simulated current');
                    hold(ax, 'on');
                    plot(ax, time, slope_lower*elapsed, '--', ...
                        'LineWidth', 1.2, 'DisplayName', ...
                        'Lower bound: (V/L_{eff,SC})(t-t_0)');
                    plot(ax, time, slope_upper*elapsed, ':', ...
                        'LineWidth', 1.2, 'DisplayName', ...
                        'Upper bound: V(M^{-1})_{aa}(t-t_0)');
                    hold(ax, 'off');
                    grid(ax, 'on');
                    xlabel(ax, 'Time [s]');
                    ylabel(ax, 'Current [A]');
                    title(ax, sprintf('%s: %g V step', coilName{1}, V));
                    legend(ax, 'Location', 'best');
                    drawnow;
                end

                tailMask = time >= (tstart + 0.8*(tend-tstart));
                p = polyfit(time(tailMask), Ik(tailMask), 1);
                slope = p(1);
                testCase.verifyGreaterThan(slope, V/Lkk, ...
                    sprintf(['Coil %s: tail slope = %.6g A/s must exceed ', ...
                    'the uncoupled slope V/Lkk = %.6g A/s.'], ...
                    coilName{1}, slope, V/Lkk));
                testCase.verifyGreaterThanOrEqual( ...
                    slope, slope_lower - tol_rel*abs(slope_lower), ...
                    sprintf(['Coil %s: tail slope = %.6g A/s is below ', ...
                    'the superconductive bound V/LeffSC = %.6g A/s.'], ...
                    coilName{1}, slope, slope_lower));
                testCase.verifyLessThanOrEqual( ...
                    slope, slope_upper + tol_rel*abs(slope_upper), ...
                    sprintf(['Coil %s: tail slope = %.6g A/s exceeds ', ...
                    'the full-circuit initial slope = %.6g A/s.'], ...
                    coilName{1}, slope, slope_upper));
            end

            if debugme == 1
                % Keep the plot available before test teardown closes figures.
                waitfor(debugFig);
            end
        end


        function test_resistive_coil(testCase)
            % Simultaneously drive coils 13/14 from zero initial currents.
            % At steady state their currents are V/R; superconductive
            % coils 1-12 retain constant, generally nonzero induced currents.
            debugme = 0; % Set to 1 to plot; close the figure to resume.
            V = 5;       % [V]
            tstart = 0;
            tend = 3;    % [s], voltage stays on through the final sample
            dt = 0.01;
            tol_rel = 0.01; % 1% steady-state and tail-variation tolerance
            tol_abs = 1e-6; % [A], for currents close to zero
            drivenCoils = [13 14];

            assignin('base','tstart',tstart);
            assignin('base','tend',tend);
            assignin('base','dt',dt);
            evalin('base', ...
                ['[sysd_plasmaless,A,B,C,D,InBus_plasmaless,OutBus_plasmaless] = ', ...
                 'configure_plasmaless_model(dt);']);
            evalin('base','x0 = zeros(size(A,1),1);');

            % Match the resistance assignment in configure_plasmaless_model:
            % both coils currently use coil 13's resistance (VS3 fix).
            ids_idx = imas_open( ...
                'imas:mdsplus?path=/work/projects/dina/SRO_JINTRAC/15MA_10perc/output');
            pf_active = ids_get(ids_idx,'pf_active');
            resistance = repmat(pf_active.coil{13}.resistance, 1, 2);
            testCase.assertTrue(all(isfinite(resistance) & resistance > 0), ...
                'Driven coils must have finite positive resistance.');
            expectedCurrent = V ./ resistance;

            t = (tstart:dt:tend)';
            u = zeros(numel(t),14);
            u(:,drivenCoils) = V;
            TS = timeseries(u,t);
            TS.Name = 'InputSignals';
            assignin('base','TS',TS);
            testCase.verifyWarningFree( ...
                @() evalin('base', ...
                    "out = sim('simulator_plasmaless_model.slx');"), ...
                'Simulation raised a warning for the resistive-coil step.');

            out = evalin('base','out');
            time = out.simout.Time;
            currents = out.simout.Data;
            testCase.assertEqual(time(end), tend, 'AbsTol', dt*1e-6, ...
                'Simulation must cover the full 3-second voltage step.');
            tailMask = time >= tstart + 0.8*(tend-tstart);
            testCase.assertGreaterThanOrEqual(nnz(tailMask), 2, ...
                'At least two tail samples are required to check settling.');

            % Require the entire tail to be near V/R, rather than merely
            % crossing the expected current at the final sample.
            for k = 1:numel(drivenCoils)
                coilIdx = drivenCoils(k);
                maxError = max(abs(currents(tailMask,coilIdx) - expectedCurrent(k)));
                testCase.verifyLessThanOrEqual(maxError, ...
                    tol_abs + tol_rel*abs(expectedCurrent(k)), ...
                    sprintf(['Coil %d: tail current has not settled to ', ...
                    'V/R = %.6g A within 1%% by 3 s (max error %.6g A).'], ...
                    coilIdx, expectedCurrent(k), maxError));
            end

            % Measure peak-to-peak tail variation relative to each coil's
            % own peak current, with an absolute floor for unexcited coils.
            for coilIdx = 1:12
                tailCurrent = currents(tailMask,coilIdx);
                variation = max(tailCurrent) - min(tailCurrent);
                currentScale = max(abs(currents(:,coilIdx)));
                testCase.verifyLessThanOrEqual(variation, ...
                    tol_abs + tol_rel*currentScale, ...
                    sprintf(['Coil %d: current is not constant after the ', ...
                    'transient (tail variation %.6g A).'], coilIdx, variation));
            end

            if debugme == 1
                debugFig = figure('Name', ...
                    'Resistive coil currents - close to resume test', ...
                    'NumberTitle', 'off');
                debugLayout = tiledlayout(debugFig, 2, 1);
                for k = 1:numel(drivenCoils)
                    coilIdx = drivenCoils(k);
                    ax = nexttile(debugLayout);
                    plot(ax, time, currents(:,coilIdx), 'LineWidth', 1.5, ...
                        'DisplayName', 'Simulated current');
                    hold(ax, 'on');
                    yline(ax, expectedCurrent(k), '--', ...
                        'DisplayName', 'Steady state: V/R');
                    hold(ax, 'off');
                    grid(ax, 'on');
                    xlabel(ax, 'Time [s]');
                    ylabel(ax, 'Current [A]');
                    title(ax, sprintf('Coil %d: %g V step', coilIdx, V));
                    legend(ax, 'Location', 'best');
                end
                drawnow;
                waitfor(debugFig);
            end
        end

    end

    methods (Static, Access = private)
        function [coilIdx, Lkk, M] = getCoilInfo(coilName)
            % Look up the (1-based) index of coilName among the 14 pf
            % coils, its self-inductance Lkk, and the full matrix M, using
            % the same IMAS sources as configure_plasmaless_model.m.
            ids_idx = imas_open( ...
                'imas:mdsplus?path=/work/projects/dina/SRO_JINTRAC/15MA_10perc/output');
            em_coupling = ids_get(ids_idx,'em_coupling');
            pf_active = ids_get(ids_idx,'pf_active');
            Maa = em_coupling.mutual_active_active;
            Mea = em_coupling.mutual_passive_active;
            Mee = em_coupling.mutual_passive_passive;
            M = [Maa Mea'; Mea Mee];

            coilIdx = [];
            for ii = 1:numel(pf_active.coil)
                if strcmp(pf_active.coil{ii}.name, coilName) || ...
                        contains(pf_active.coil{ii}.name, coilName)
                    coilIdx = ii;
                    break
                end
            end
            if isempty(coilIdx)
                error('test_plasmaless_model:CoilNotFound', ...
                    'Coil %s not found in pf_active.coil.', coilName);
            end
            Lkk = Maa(coilIdx,coilIdx);
        end
    end
end
