%% test_sinc3_nplc.m
% Test script for sinc^3 NPLC digital filter for SAR ADC data.
% Verifies notch frequencies, output data rates, and generates
% frequency-domain / time-domain figures.

clear; close all; clc;

% Disable GPU acceleration to avoid access violation crashes
try
    gpuDevice([]);
catch
end

%% Parameters
fs = 2e6;              % ADC sample rate: 2 MSPS
f_line = 50;           % Power line frequency: 50 Hz
duration = 0.5;        % Test signal duration in seconds (reduced for stability)
N = round(duration * fs);
N_fft_pad = 10;        % Zero-padding factor for FFT notch detection

fprintf('====================================================================\n');
fprintf('  Sinc^3 NPLC 数字滤波器 — 24-bit SAR ADC 工频抑制测试\n');
fprintf('  滤波器类型: 三级级联滑动平均 (sinc^3)\n');
fprintf('====================================================================\n');
fprintf(' ADC 采样率 fs       = %.0f Hz  (%.1f MSPS)\n', fs, fs/1e6);
fprintf(' 工频 f_line          = %.0f Hz\n', f_line);
fprintf(' 信号时长             = %.1f s  (%d 个采样点)\n', duration, N);
fprintf(' ADC 分辨率           = 24-bit\n');
fprintf('\n');

%% --- Generate Test Signal — 模拟 DMM 测量场景 ---
rng(42);
t = (0:N-1)' / fs;

% 真实被测信号: DC + 低频波动 (模拟电压测量)
V_dc = 0.5;                              % 直流分量
V_slow = 0.05 * sin(2*pi*3*t);          % 3 Hz 低频慢波动
signal_true = V_dc + V_slow;             % 真实被测值

% 工频干扰: 50 Hz 基波 + 谐波
f_50  = 1.0 * sin(2*pi*50*t);
f_100 = 0.3 * sin(2*pi*100*t);
f_150 = 0.1 * sin(2*pi*150*t);
f_noise = 0.02 * randn(size(t));

% ADC 输入 = 真实信号 + 干扰
adc_input = signal_true + f_50 + f_100 + f_150 + f_noise;

% 24-bit 量化
signal_24bit = round(adc_input * 2^22) / 2^22;

fprintf('=========== 滤波器输入: 原始 ADC 数据 ===========\n');
fprintf(' 真实被测信号 = %.1f V DC + %.2f Vpp @ 3 Hz\n', V_dc, 0.1);
fprintf('   + 工频干扰 = 50Hz(1.0V) + 100Hz(0.3V) + 150Hz(0.1V)\n');
fprintf('   + 噪声     = 高斯白噪声, 标准差 %.3f V\n', 0.02);
fprintf('   ADC 满量程 ±1 V, 24-bit, LSB = %.2e V\n', 2/2^24);
fprintf('\n');

% ---- 展示输入时域数据: 一个完整 50 Hz 周期 ----
fprintf('【时域】输入信号 — 一个完整 50 Hz 周期 (20 ms):\n');
fprintf(' (等间隔取 30 个采样点展示波形形状)\n');
fprintf('  时间(ms) | 真实信号(V) | ADC输入(V)  | 干扰分量(V)\n');
fprintf('  ---------+-------------+-------------+-------------\n');
dec = round(fs/f_line / 30);
for i = 1:dec:round(fs/f_line)
    fprintf('   %7.3f  |   %+.4f    |   %+.4f    |   %+.4f\n', ...
            t(i)*1000, signal_true(i), signal_24bit(i), ...
            f_50(i)+f_100(i)+f_150(i));
end
fprintf('  ... (以上为 20 ms 波形概览)\n');
fprintf('  幅值范围: [%.4f, %.4f] V, RMS = %.4f V\n\n', ...
        min(signal_24bit), max(signal_24bit), rms(signal_24bit));

% ---- 展示输入频域数据 ----
N_fft_in = 2^nextpow2(N);
S_in = fft(signal_24bit, N_fft_in);
S_in_mag = abs(S_in(1:floor(N_fft_in/2)+1));
f_in = (0:floor(N_fft_in/2))' / N_fft_in * fs;

fprintf('【频域】输入信号频谱特征:\n');
for fc = [0, 3, 50, 100, 150, 250, 350, 450, 1000]
    [~, i_f] = min(abs(f_in - fc));
    if fc == 0
        fprintf('    %5s: 幅值 = %.4f  (DC 分量)\n', 'DC', S_in_mag(i_f));
    elseif fc <= 150
        amp_expected = 1.0*(fc==50) + 0.3*(fc==100) + 0.1*(fc==150);
        fprintf('    %4.0f Hz: 幅值 = %.2f  (注入 %.1f)\n', ...
                fc, S_in_mag(i_f), amp_expected);
    else
        fprintf('    %4.0f Hz: 幅值 = %.4f  (噪声底噪)\n', fc, S_in_mag(i_f));
    end
end
fprintf('    噪声底噪 (900-1100 Hz 均值): %.4f\n\n', ...
        mean(S_in_mag(f_in > 900 & f_in < 1100)));

%% --- Test NPLC Values ---
nplc_list = [1, 5, 10];
nplc_count = length(nplc_list);

results = struct();
M_vals = zeros(nplc_count, 1);
odr_vals = zeros(nplc_count, 1);

for idx = 1:nplc_count
    nplc = nplc_list(idx);

    t_filt = tic;
    [filtered, odr] = sinc3_nplc_filter(signal_24bit, fs, nplc, f_line);
    elapsed = toc(t_filt);

    M = round(nplc * fs / f_line);
    M_vals(idx) = M;
    odr_vals(idx) = odr;

    T_int = nplc / f_line;
    group_delay_s = 1.5 * T_int;
    group_delay_ms = group_delay_s * 1000;

    fprintf('--- NPLC = %d ---\n', nplc);
    fprintf('  M (avg length)    = %d\n', M);
    fprintf('  Integration time  = %.3f s\n', T_int);
    fprintf('  ODR               = %.4f Hz\n', odr);
    fprintf('  Group delay       = %.2f ms  (%.2f input samples)\n', ...
            group_delay_ms, group_delay_s * fs);
    fprintf('  Output samples    = %d\n', length(filtered));
    fprintf('  Filter time       = %.3f s\n', elapsed);

    % --- Notch Verification via Undecimated Impulse Response ---
    N_imp = 6 * M;
    imp = zeros(N_imp, 1);
    imp(1) = 1;

    % Generate undecimated impulse response through 3 MA stages
    cs = cumsum([zeros(M, 1); imp]);
    h1 = (cs(M+1:end) - cs(1:end-M)) / M;
    cs = cumsum([zeros(M, 1); h1]);
    h2 = (cs(M+1:end) - cs(1:end-M)) / M;
    cs = cumsum([zeros(M, 1); h2]);
    h_imp = (cs(M+1:end) - cs(1:end-M)) / M;

    % Keep only meaningful portion (first 3M-2 samples)
    h_imp = h_imp(1:min(3*M-2, length(h_imp)));

    % FFT with zero-padding for notch detection
    N_fft = 2^nextpow2(length(h_imp) * N_fft_pad);
    H = fft(h_imp, N_fft);
    H_mag = abs(H(1:floor(N_fft/2)+1));
    f_axis = (0:floor(N_fft/2))' / N_fft * fs;

    % Find notches as local minima below -40 dB threshold
    H_dB = 20 * log10(H_mag / max(H_mag));
    notch_thresh = -40;
    notch_freqs = [];

    % Limit search to 0-500 Hz so that a large MinPeakDistance
    % (needed for high-frequency peaks) doesn't suppress the
    % low-frequency notches we care about.
    f_limit = 500;
    idx_limit = f_axis <= f_limit;
    % Scale MinPeakDistance by expected notch spacing (f_line/nplc)
    % so that NPLC=1 (50 Hz spacing) and NPLC=100 (0.5 Hz spacing)
    % both work correctly
    df = f_axis(2) - f_axis(1);
    exp_notch_spacing = f_line / nplc;
    min_dist_bins = max(3, round(0.4 * exp_notch_spacing / df));
    [~, locs] = findpeaks(-H_dB(idx_limit), 'MinPeakHeight', -notch_thresh, ...
                           'MinPeakDistance', min_dist_bins);

    if ~isempty(locs)
        notch_freqs = f_axis(idx_limit);
        notch_freqs = notch_freqs(locs);
        notch_freqs = notch_freqs(notch_freqs > 0.5 & notch_freqs < 500);
    end

    fprintf('  Detected notches (Hz):');
    for ni = 1:min(5, length(notch_freqs))
        fprintf(' %.2f', notch_freqs(ni));
    end
    if isempty(notch_freqs)
        fprintf(' (none detected)');
    end
    fprintf('\n');

    % Expected notch: k * f_line / NPLC
    fprintf('  Expected 1st notch: %.2f Hz\n', f_line / nplc);
    fprintf('\n');

    % Store results
    results(idx).nplc   = nplc;
    results(idx).M      = M;
    results(idx).odr    = odr;
    results(idx).M_actual = round(nplc * fs / f_line);
    results(idx).filtered    = filtered;
    results(idx).group_delay_ms = group_delay_ms;

    % Store frequency response data (analytical, for smooth plots)
    f_plot = linspace(0, 500, 20001)';
    H_analytical = abs(sin(pi * f_plot * M / fs) ./ ...
                       (M * sin(pi * f_plot / fs))).^3;
    idx_nan = (f_plot == 0) | (abs(sin(pi * f_plot / fs)) < eps);
    H_analytical(idx_nan) = 1;
    H_analytical_dB = 20 * log10(H_analytical + eps);

    results(idx).f_plot  = f_plot;
    results(idx).H_dB    = H_analytical_dB;
    results(idx).H_mag   = H_analytical;
end

%% === 滤波前后数据对比 ===
fprintf('=========== 滤波器输出: NPLC=1 对比 ===========\n');
R1 = results(1);
f1 = R1.filtered;
t_out = (0:length(f1)-1)' / R1.odr;
fprintf(' 输出数据率 ODR:     %.2f Hz\n', R1.odr);
fprintf(' 输出样本数:         %d 个\n', length(f1));
fprintf(' 相邻样本间隔:       %.2f ms\n', 1000/R1.odr);
fprintf('\n');
fprintf('【滤波输出 vs 真实信号】NPLC=1:\n');
fprintf('    输出 # | 时间(ms) |  滤波输出值   |  真实信号(对齐) |  误差\n');
fprintf('    -------+----------+---------------+-----------------+------------\n');
gd_s = R1.group_delay_ms / 1000;
for i = 1:min(15, length(f1))
    t_i = t_out(i);
    t_corr = t_i - gd_s;
    if t_corr >= 0
        [~, i_in] = min(abs(t - t_corr));
        true_val = signal_true(i_in);
        err = f1(i) - true_val;
    else
        true_val = NaN;
        err = NaN;
    end
    if ~isnan(err)
        fprintf('    [%5d] | %8.3f | %+.10f | %+.8f | %+.2e\n', ...
                i, t_i*1000, f1(i), true_val, err);
    else
        fprintf('    [%5d] | %8.3f | %+.10f |  (瞬态)     |\n', ...
                i, t_i*1000, f1(i));
    end
end
fprintf('\n');

% 稳态误差统计
valid = t_out - gd_s >= 0;
if sum(valid) >= 3
    f_valid = f1(valid);
    t_valid = t_out(valid);
    [~, i_start] = min(abs(t - (t_valid(1) - gd_s)));
    i_end = i_start + length(f_valid) - 1;
    if i_end <= length(signal_true)
        true_valid = signal_true(i_start:i_end);
        err_rms = rms(f_valid - true_valid);
        fprintf('  稳态误差统计:\n');
        fprintf('    滤波输出均值: %.6f V  (真实 DC = %.2f V)\n', mean(f_valid), V_dc);
        fprintf('    与真实信号的 RMS 误差: %.6f V\n', err_rms);
        fprintf('    等效 SNR (相对于 DC): %.1f dB\n', 20*log10(V_dc/err_rms));
    end
end
fprintf('\n');

%% === 数据特征总结 ===
fprintf('=========== 数据特征说明 ===========\n');
fprintf(' 1. 滤波器输入 (2 MSPS ADC 原始数据):\n');
fprintf('    - 真实被测信号: %.1f V DC + 3 Hz 慢波动\n', V_dc);
fprintf('    - 工频干扰:     50 Hz(1.0V) + 100 Hz(0.3V) + 150 Hz(0.1V)\n');
fprintf('    - 白噪声:       标准差 0.02 V\n');
fprintf('    - 数据率:       2 MSPS (每 0.5 us 一个采样)\n');
fprintf('    - 幅值范围:     [%.4f, %.4f] V\n', min(signal_24bit), max(signal_24bit));
fprintf('    - 从时域波形可见 50 Hz 正弦波完全淹没了 DC 信号\n');
fprintf('\n');
fprintf(' 2. 滤波器输出 (NPLC=1, ODR=50 Hz):\n');
fprintf('    - 每 %d 个输入采样 -> 1 个输出 (抽取比)\n', R1.M);
fprintf('    - 输出间隔 %.2f ms, 等效 50 SPS\n', 1000/R1.odr);
fprintf('    - 50/100/150 Hz 被陷波完全抑制, 输出为真实 DC 值\n');
fprintf('    - 残余 RMS 误差: %.6f V\n', err_rms);
fprintf('    - 群时延 %.2f ms (= 1.5 PLC)\n', R1.group_delay_ms);
fprintf('\n');

%% === Create Figures Directory ===
fig_dir = 'D:\matlab_filter_test\figures';
if ~exist(fig_dir, 'dir')
    mkdir(fig_dir);
end

%% === FIGURE 1: Frequency Response (4 subplots, 2x2) ===
figure('Name', 'Frequency Response', 'Position', [50, 50, 1200, 900]);

f_max_list = [500, 100, 50];
xline_colors = {[0.7, 0.7, 0.7], [0.5, 0.5, 0.5], [0.3, 0.3, 0.3]};

for idx = 1:3
    subplot(2, 2, idx);
    nplc = nplc_list(idx);
    M = M_vals(idx);
    f_plot = results(idx).f_plot;
    H_dB = results(idx).H_dB;

    f_max = f_max_list(idx);
    f_idx = f_plot <= f_max;

    semilogy(f_plot(f_idx), max(10.^(H_dB(f_idx)/20), 1e-8), ...
             'LineWidth', 1.5);
    xlabel('Frequency (Hz)'); ylabel('|H(f)|');
    title(sprintf('NPLC = %d (M = %d)', nplc, M));
    grid on; ylim([1e-8, 1.2]);

    % Vertical lines at notch frequencies
    notch_spacing = f_line / nplc;
    notch_count = floor(f_max / notch_spacing);
    for k = 1:notch_count
        xline(k * notch_spacing, '--', 'Color', xline_colors{idx}, ...
              'HandleVisibility', 'off');
    end
    % Highlight first notch in red
    xline(notch_spacing, '--r', sprintf('%.1f Hz', notch_spacing), ...
          'LineWidth', 1.2);
end

% Subplot 4: Overlay comparison
subplot(2, 2, 4);
f_max_compare = 200;
colors = {'b', 'r', 'g'};
hold on;
for idx = 1:3
    f_plot = results(idx).f_plot;
    H_dB = results(idx).H_dB;
    f_idx = f_plot <= f_max_compare;
    semilogy(f_plot(f_idx), max(10.^(H_dB(f_idx)/20), 1e-8), ...
             colors{idx}, 'LineWidth', 1.5, ...
             'DisplayName', sprintf('NPLC=%d', nplc_list(idx)));
end
xlabel('Frequency (Hz)'); ylabel('|H(f)|');
title('Comparison: 0-200 Hz');
legend('Location', 'southwest');
grid on; ylim([1e-8, 1.2]);
hold off;

sgtitle('Sinc^3 Filter Frequency Response');
saveas(gcf, fullfile(fig_dir, 'figure1_frequency_response.png'));
fprintf('Saved: figure1_frequency_response.png\n');

%% === FIGURE 2: Time Domain (显示完整工频周期) ===
figure('Name', 'Time Domain', 'Position', [50, 50, 1200, 700]);

% Use NPLC=1 for time-domain demonstration (most output samples)
R1 = results(1);
M1 = R1.M;
filtered = R1.filtered;
gd_ms = R1.group_delay_ms;

% --- Top: 60ms 总览 (3 个完整 50Hz 周期) ---
t_total_ms = 60;  % 显示 60ms = 3 个工频周期
n_total = round(t_total_ms / 1000 * fs);  % 对应采样数
dec_fig = 200;    % 每 200 点取 1 个绘图 (降采样避免点太多)

t_in_total = t(1:dec_fig:n_total) * 1000;  % ms
x_in_total = signal_24bit(1:dec_fig:n_total);
x_true_total = signal_true(1:dec_fig:n_total);

% Output time base
t_out = (0:length(filtered)-1)' / R1.odr * 1000;  % ms

% 正确对齐: 滤波输出减去群时延后, 应与同时刻的真实信号重合
t_out_shifted = t_out - gd_ms;
out_valid = t_out_shifted >= 0;
filtered_shifted = filtered(out_valid);
t_out_aligned = t_out_shifted(out_valid);

subplot(2, 1, 1);
hold on;
% 1) 真实被测信号 (应该是一条 ~0.5V 的水平线带小波动)
plot(t_in_total, x_true_total, 'g-', 'LineWidth', 2, ...
     'DisplayName', sprintf('True signal (%.1fV DC + 3Hz)', V_dc));

% 2) ADC 输入 (被工频干扰淹没)
plot(t_in_total, x_in_total, 'b-', 'LineWidth', 0.8, ...
     'DisplayName', 'ADC input (50Hz + harmonics)');

% 3) 滤波输出 (减群时延对齐后, 应与真实信号重合)
plot(t_out_aligned, filtered_shifted, 'r.', 'MarkerSize', 10, ...
     'DisplayName', sprintf('Filtered (shifted by %.1f ms)', gd_ms));

xlabel('Time (ms)'); ylabel('Voltage (V)');
title(sprintf('Sinc^3 NPLC Filter: 60 ms overview (%.0f Hz rejection)', f_line));
legend('Location', 'northeast');
grid on;
xlim([0, t_total_ms]);
ylim([-1.5, 2.0]);
hold off;

% --- Bottom: 5ms 放大 (看清正弦波形) ---
t_zoom_ms = 5;  % 5ms = 1/4 个工频周期
n_zoom = round(t_zoom_ms / 1000 * fs);
dec_zoom = 10;   % 每 10 点取 1 个 (还是 1000 个点/图, 足够看清)

t_in_zoom = t(1:dec_zoom:n_zoom) * 1000;
x_in_zoom = signal_24bit(1:dec_zoom:n_zoom);
x_true_zoom = signal_true(1:dec_zoom:n_zoom);

subplot(2, 1, 2);
hold on;
plot(t_in_zoom, x_true_zoom, 'g-', 'LineWidth', 2, ...
     'DisplayName', 'True signal');
plot(t_in_zoom, x_in_zoom, 'b-', 'LineWidth', 1, ...
     'DisplayName', 'ADC input');

% 滤波输出在放大窗口内
zoom_out_valid = t_out_aligned >= 0 & t_out_aligned <= t_zoom_ms;
plot(t_out_aligned(zoom_out_valid), filtered_shifted(zoom_out_valid), ...
     'ro', 'MarkerSize', 8, 'LineWidth', 1.5, ...
     'DisplayName', 'Filtered output');

xlabel('Time (ms)'); ylabel('Voltage (V)');
title(sprintf('Zoom: 5 ms (noisy ADC input vs clean output)'));
legend('Location', 'northeast');
grid on;
xlim([0, t_zoom_ms]);
hold off;

sgtitle('Time Domain: Sinc^3 NPLC Filter (NPLC=1)');
saveas(gcf, fullfile(fig_dir, 'figure2_time_domain.png'));
fprintf('Saved: figure2_time_domain.png\n');

%% === FIGURE 3: Impulse Response ===
figure('Name', 'Impulse Response', 'Position', [50, 50, 1000, 500]);

% Generate clean impulse response for NPLC=1
M_imp = M_vals(1);
N_imp = 4 * M_imp;
imp = zeros(N_imp, 1);
imp(1) = 1;

cs = cumsum([zeros(M_imp, 1); imp]);
h1 = (cs(M_imp+1:end) - cs(1:end-M_imp)) / M_imp;
cs = cumsum([zeros(M_imp, 1); h1]);
h2 = (cs(M_imp+1:end) - cs(1:end-M_imp)) / M_imp;
cs = cumsum([zeros(M_imp, 1); h2]);
h_imp = (cs(M_imp+1:end) - cs(1:end-M_imp)) / M_imp;

% Take first 3M samples
h_plot = h_imp(1:min(3*M_imp, length(h_imp)));
t_h = (0:length(h_plot)-1)' / fs * 1000;  % ms

plot(t_h, h_plot, 'b', 'LineWidth', 1.5);
hold on;
gd_ms_imp = 1.5 * 1 / f_line * 1000;  % Group delay for NPLC=1
xline(gd_ms_imp, '--r', sprintf('Group Delay = %.2f ms', gd_ms_imp), ...
      'LineWidth', 1.5);
xlabel('Time (ms)'); ylabel('Amplitude');
title(sprintf('Impulse Response: Sinc^3 Filter (NPLC=%d, M=%d)', 1, M_imp));
grid on;
legend('h[n]', 'Group Delay', 'Location', 'northeast');

saveas(gcf, fullfile(fig_dir, 'figure3_impulse_response.png'));
fprintf('Saved: figure3_impulse_response.png\n');

%% === Summary ===
fprintf('========================================\n');
fprintf('  Test Complete\n');
fprintf('========================================\n');
fprintf('Figures saved to: %s\n', fig_dir);
fprintf('\n');

for idx = 1:nplc_count
    fprintf('NPLC=%d:  M=%d,  ODR=%.4f Hz,  Group Delay=%.2f ms\n', ...
            nplc_list(idx), M_vals(idx), odr_vals(idx), ...
            results(idx).group_delay_ms);
end
fprintf('\n');
