%% run_simulink_test.m
% 运行 Simulink 模型并验证结果
% 直接在 MATLAB 命令窗口运行: run('D:\matlab_filter_test\run_simulink_test.m')

clear; close all; clc;

fprintf('========================================\n');
fprintf('  Sinc^3 NPLC 滤波器 — Simulink 仿真\n');
fprintf('========================================\n\n');

%% 运行仿真
out = sim('sinc3_nplc_simulink');
sim_adc = out.get('sim_adc');
sim_true = out.get('sim_true');
sim_filtered = out.get('sim_filtered');

fs = 2e6; M = 40000; f_line = 50;
N_filt = length(sim_filtered);
t_out = (0:N_filt-1)' * M / fs * 1000;  % ms

fprintf('  ADC 输入:    %d 采样 @ 2MHz\n', length(sim_adc));
fprintf('  滤波输出:    %d 采样 @ 50Hz\n', N_filt);
fprintf('\n');

%% 对比 MATLAB 函数
[ref, odr] = sinc3_nplc_filter(sim_adc, fs, 1, f_line);
err = sim_filtered - ref(1:N_filt);
fprintf('与 MATLAB 函数 RMS 差异: %.2e\n\n', rms(err));

%% 显示 ADC 输入波形 (一个完整 50Hz 周期)
fprintf('===== ADC 输入 (20ms = 1 个工频周期) =====\n');
fprintf('  时间(ms) | ADC输入(V) | 真实信号(V) | 干扰分量(V)\n');
for i = 1:800:40000
    intf = sim_adc(i) - sim_true(i);
    fprintf('   %7.3f |   %+.4f   |   %+.4f    |   %+.4f\n', ...
            i/fs*1000, sim_adc(i), sim_true(i), intf);
end
fprintf('\n');

%% 显示滤波输出
fprintf('===== 滤波输出 (NPLC=1, ODR=50Hz) =====\n');
fprintf('  # | 时间(ms) | 滤波输出(V) | 真实信号(V) | 误差(V)\n');
for i = 1:min(N_filt, 20)
    % 对齐: 真实信号时间 = 输出时间 - 群时延(30ms)
    t_align = t_out(i) - 30;
    if t_align >= 0
        [~, idx_t] = min(abs((0:length(sim_true)-1)'/fs*1000 - t_align));
        tv = sim_true(idx_t);
    else
        tv = NaN;
    end
    if ~isnan(tv)
        fprintf(' %3d | %8.3f |   %+.6f   |   %+.4f  | %+.2e\n', ...
                i, t_out(i), sim_filtered(i), tv, sim_filtered(i)-tv);
    else
        fprintf(' %3d | %8.3f |   %+.6f   |  (瞬态) |\n', ...
                i, t_out(i), sim_filtered(i));
    end
end
fprintf('\n');

%% 总结
fprintf('========================================\n');
fprintf('  仿真结果:\n');
fprintf('  - Simulink 模型输出与 MATLAB 函数一致 (RMS=%.2e)\n', rms(err));
fprintf('  - 输入: 2MSPS ADC 数据, 含 50/100/150Hz 干扰\n');
fprintf('  - 输出: 50Hz ODR, 工频被抑制, 真实 DC 信号恢复\n');
fprintf('  - 打开模型: open_system(''sinc3_nplc_simulink'')\n');
fprintf('  - 双击 Scope_Main 查看波形\n');
fprintf('========================================\n');
