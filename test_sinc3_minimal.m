%% test_sinc3_minimal.m
% Minimal test — 展示 sinc^3 NPLC 滤波器对工频干扰的抑制效果
% 模拟 DMM 测量场景: 被测信号(DC/慢变) + 工频干扰 + 噪声 -> 滤波后恢复原始信号

fprintf('========================================\n');
fprintf('  Sinc^3 NPLC 数字滤波器 — 数值测试\n');
fprintf('  模拟 DMM 工频抑制场景\n');
fprintf('========================================\n\n');

%% Parameters
fs = 2e6;        % ADC 采样率 = 2 MSPS
f_line = 50;     % 工频
duration = 0.5;  % 0.5 秒数据
N = round(duration * fs);
M_per_plc = round(fs / f_line);  % 每工频周期 40000 个采样

fprintf(' ADC 采样率 fs       = %.0f Hz  (%.1f MSPS)\n', fs, fs/1e6);
fprintf(' 工频 f_line         = %.0f Hz  (周期 %.1f ms)\n', f_line, 1000/f_line);
fprintf(' 1PLC 滑动平均长度 M = %d = %.2f ms 数据\n', M_per_plc, M_per_plc/fs*1000);
fprintf(' 信号时长            = %.1f s  (%d 个采样点)\n', duration, N);
fprintf('\n');

%% ===== 生成测试信号 =====
t = (0:N-1)' / fs;

% --- 真实被测信号 (DMM 测量的目标) ---
% 场景: 测一个 0.5V 直流电压, 叠加 5% 的慢波动
V_dc = 0.5;                    % 直流分量
V_slow = 0.05 * sin(2*pi*3*t); % 3 Hz 低频波动 (模拟电源纹波或信号漂移)
signal_true = V_dc + V_slow;   % 真实被测信号

% --- 工频干扰 (要滤除的噪声) ---
f_50  = 1.0 * sin(2*pi*50*t);       % 50 Hz 基波
f_100 = 0.3 * sin(2*pi*100*t);      % 100 Hz 二次谐波
f_150 = 0.1 * sin(2*pi*150*t);      % 150 Hz 三次谐波
f_noise = 0.02 * randn(size(t));    % 宽带噪声

% --- ADC 输入 = 真实信号 + 干扰 ---
adc_input = signal_true + f_50 + f_100 + f_150 + f_noise;
% 24-bit 量化
adc_input = round(adc_input * 2^22) / 2^22;

fprintf('=============== 滤波器输入: 原始 ADC 数据 ===============\n');
fprintf(' 真实被测信号  = %.2f V DC + %.2f Vpp @ 3 Hz 慢波动\n', V_dc, 0.1);
fprintf('   + 工频干扰  = 50Hz(1.0V) + 100Hz(0.3V) + 150Hz(0.1V)\n');
fprintf('   + 噪声      = 高斯白噪声, 标准差 %.3f V\n', 0.02);
fprintf('   -> ADC 满量程 ±1 V, 24-bit, LSB = %.2e V\n', 2/2^24);
fprintf('\n');

%% ---- 展示输入时域数据: 看 "波形" ----
% 要展示一个完整的 50 Hz 周期 (20 ms = 40000 个采样)
% 只看 40000 个点里取等间隔的 50 个点来示意波形形状
fprintf('【时域】输入信号 — 一个完整 50 Hz 周期 (20 ms):\n');
fprintf(' (每 800 个采样取 1 点展示, 共 50 个点)\n');
fprintf('  时间(ms) | 真实信号  | ADC输入(含干扰) |  干扰分量\n');
fprintf('   ---------+-----------+-----------------+------------\n');
dec = round(M_per_plc / 50);  % 每 dec 个采样取一点
for i = 1:dec:M_per_plc
    fprintf('   %7.3f  | %+.6f  | %+.6f       | %+.6f\n', ...
            t(i)*1000, signal_true(i), adc_input(i), ...
            f_50(i)+f_100(i)+f_150(i));
end
fprintf('  ... 完整 20 ms 波形如上\n');
fprintf('  幅值范围 (全部数据): [%.4f, %.4f] V, RMS = %.4f V\n\n', ...
        min(adc_input), max(adc_input), rms(adc_input));

%% ---- 输入频域 ----
N_fft = 2^nextpow2(N);
S = fft(adc_input, N_fft);
S_mag = abs(S(1:floor(N_fft/2)+1));
f_ax = (0:floor(N_fft/2))' / N_fft * fs;

fprintf('【频域】输入信号频谱 (主要分量):\n');
targets = [0, 3, 50, 100, 150, 250, 350, 450, 1000];
labels  = {"DC", "3Hz慢变", "50Hz工频", "100Hz", "150Hz", "噪声", "噪声", "噪声", "噪声底噪"};
for k = 1:length(targets)
    [~, idx] = min(abs(f_ax - targets(k)));
    fprintf('  %-10s: %.1f Hz, 幅值 = %.4f\n', ...
            labels{k}, f_ax(idx), S_mag(idx));
end
fprintf('\n');

%% ===== 滤波测试 (NPLC=1, 5, 10) =====
nplc_list = [1, 5, 10];

for idx = 1:length(nplc_list)
    nplc = nplc_list(idx);
    M = round(nplc * fs / f_line);
    T_int = nplc / f_line;
    gd_s = 1.5 * T_int;
    odr = fs / M;

    tic;
    [filtered, odr_out] = sinc3_nplc_filter(adc_input, fs, nplc, f_line);
    elapsed = toc;

    t_out = (0:length(filtered)-1)' / odr;

    fprintf('=============== NPLC = %d  ===============\n', nplc);
    fprintf('  滤波器参数:\n');
    fprintf('    M = %d,  积分时间 = %.1f ms,  ODR = %.2f Hz\n', M, T_int*1000, odr);
    fprintf('    群时延 = %.2f ms\n', gd_s*1000);
    fprintf('    输出 %d 个样本\n', length(filtered));

    % 1) 展示输出值 — 应该接近真实被测信号 V_dc + V_slow
    if nplc == 1  % 最多输出样本, 最有参考价值
        fprintf('\n【滤波输出 vs 真实信号】NPLC=1:\n');
        fprintf('    输出# | 时间(ms) |  滤波输出     |  真实信号    |  误差\n');
        fprintf('    ------+----------+---------------+-------------+-----------\n');
        n_show = min(15, length(filtered));
        for i = 1:n_show
            t_i = t_out(i);
            t_corr = t_i - gd_s;  % 减去群时延对齐
            if t_corr >= 0
                [~, i_in] = min(abs(t - t_corr));
                true_val = signal_true(i_in);
            else
                true_val = NaN;
            end
            err = filtered(i) - true_val;
            if ~isnan(err)
                fprintf('    [%5d] | %8.3f | %+.10f | %+.6f | %+.2e\n', ...
                        i, t_i*1000, filtered(i), true_val, err);
            else
                fprintf('    [%5d] | %8.3f | %+.10f |  (瞬态)\n', ...
                        i, t_i*1000, filtered(i));
            end
        end
        fprintf('\n');

        % 2) 统计误差
        valid = t_out - gd_s >= 0;
        if sum(valid) >= 3
            t_valid = t_out(valid);
            f_valid = filtered(valid);
            [~, i_start] = min(abs(t - (t_valid(1) - gd_s)));
            i_end = i_start + length(f_valid) - 1;
            if i_end <= length(signal_true)
                true_valid = signal_true(i_start:i_end);
                err_rms = rms(f_valid - true_valid);
                fprintf('【误差统计】(去瞬态后):\n');
                fprintf('    滤波输出均值: %.6f V  (真实 DC = %.2f V)\n', mean(f_valid), V_dc);
                fprintf('    与真实信号的 RMS 误差: %.6f V\n', err_rms);
                fprintf('    等效 SNR: %.1f dB\n', 20*log10(V_dc/err_rms));
            end
        else
            fprintf('  (瞬态后有效样本太少, 无法统计)\n');
        end
    elseif length(filtered) >= 2
        fprintf('\n【滤波输出】NPLC=%d (仅 %d 个输出):\n', nplc, length(filtered));
        for i = 1:length(filtered)
            t_i = t_out(i);
            t_corr = t_i - gd_s;
            if t_corr >= 0
                [~, i_in] = min(abs(t - t_corr));
                fprintf('    [%d] t=%6.2fms  输出=%+.6f  (真实信号=%.6f)\n', ...
                        i, t_i*1000, filtered(i), signal_true(i_in));
            else
                fprintf('    [%d] t=%6.2fms  输出=%+.6f  (瞬态)\n', ...
                        i, t_i*1000, filtered(i));
            end
        end
    end
    fprintf('\n');

    % 3) RMS 衰减
    fprintf('【RMS】输入 %.6f -> 输出 %.6f (衰减 %.1f dB)\n', ...
            rms(adc_input), rms(filtered), 20*log10(rms(adc_input)/rms(filtered)));
    fprintf('  滤波耗时: %.3f s\n\n', elapsed);
end

%% ========== 总结 ==========
fprintf('=============== NPLC 参数对比 ===============\n');
fprintf('  NPLC |   M    |  ODR(Hz) | 积分时间 |  群时延  | 输出样本\n');
fprintf('  -----+--------+----------+----------+----------+---------\n');
for idx = 1:length(nplc_list)
    nplc = nplc_list(idx);
    M = round(nplc * fs / f_line);
    odr = fs / M;
    [filtered, ~] = sinc3_nplc_filter(adc_input, fs, nplc, f_line);
    fprintf('  %4d  | %6d | %8.2f | %6.1fms | %7.2fms |   %d\n', ...
            nplc, M, odr, nplc/f_line*1000, 1.5*nplc/f_line*1000, length(filtered));
end
fprintf('  -----+--------+----------+----------+----------+---------\n');
fprintf('\n');
fprintf('  测试信号说明:\n');
fprintf('    真实信号  = %.1fV DC + 3Hz 慢波动\n', V_dc);
fprintf('    工频干扰  = 50Hz(1V) + 100Hz(0.3V) + 150Hz(0.1V)\n');
fprintf('    -> 滤波后工频被抑制, 输出应接近 %.1fV DC\n', V_dc);
fprintf('========================================\n');
fprintf('  测试完成\n');
fprintf('========================================\n');
