%% build_sinc3_zdomain.m
% sinc^3 NPLC 滤波器 — z-domain 延迟单元流程图 (整齐版)
% 每级 MA: y[n]=y[n-1]+(x[n]-x[n-M])/M, 用 z⁻¹+z⁻ᴹ 显式搭建
%
% 布局:
%   信号源(左) → 三级MA(中) → 抽取M(右) → 输出+Scope(右)
%   每级: [zM]在上, [Sub-G-Acc]在中, [Uz]在下, 反馈为竖直走线

clear; close all; clc;

fs = 2e6; f_line = 50; nplc = 1;
M_val = round(nplc * fs / f_line);
Ts = 1/fs; T_sim = 0.5;
Ts_str = num2str(Ts); M_str = num2str(M_val);

%% 创建模型
model = 'sinc3_zdomain';
if bdIsLoaded(model), close_system(model, 0); end
if exist([model '.slx'], 'file'), delete([model '.slx']); end
new_system(model); open_system(model);
set_param(model, 'StopTime', num2str(T_sim));
set_param(model, 'Solver', 'FixedStepDiscrete', 'FixedStep', Ts_str);

%% ===================== 1. 信号源 (左列) =====================
% --- 干扰 (Y=70~250) ---
add_block('simulink/Sources/Sine Wave',  [model '/F50'], ...
    'Position', [30, 70, 80, 100], ...
    'Amplitude', '1.0', 'Frequency', '2*pi*50', 'SampleTime', Ts_str);
add_block('simulink/Sources/Sine Wave',  [model '/F100'], ...
    'Position', [30, 120, 80, 150], ...
    'Amplitude', '0.3', 'Frequency', '2*pi*100', 'SampleTime', Ts_str);
add_block('simulink/Sources/Sine Wave',  [model '/F150'], ...
    'Position', [30, 170, 80, 200], ...
    'Amplitude', '0.1', 'Frequency', '2*pi*150', 'SampleTime', Ts_str);
add_block('simulink/Sources/Random Number', [model '/Noise'], ...
    'Position', [30, 220, 80, 250], ...
    'Variance', '0.0004', 'SampleTime', Ts_str);

% --- 真实信号 (Y=370~460) ---
add_block('simulink/Sources/Constant',  [model '/DC'], ...
    'Position', [30, 430, 80, 460], 'Value', '0.5', 'SampleTime', Ts_str);
add_block('simulink/Sources/Sine Wave', [model '/Slow'], ...
    'Position', [30, 380, 80, 410], ...
    'Amplitude', '0.05', 'Frequency', '2*pi*3', 'SampleTime', Ts_str);

% --- 求和 ---
add_block('simulink/Math Operations/Add', [model '/SumNoise'], ...
    'Position', [140, 100, 190, 170], 'Inputs', '+++');
add_line(model, 'F50/1',  'SumNoise/1');
add_line(model, 'F100/1', 'SumNoise/2');
add_line(model, 'F150/1', 'SumNoise/3');

add_block('simulink/Math Operations/Add', [model '/TrueSig'], ...
    'Position', [140, 395, 190, 445], 'Inputs', '++');
add_line(model, 'DC/1',   'TrueSig/1');
add_line(model, 'Slow/1', 'TrueSig/2');

add_block('simulink/Math Operations/Add', [model '/SumAll'], ...
    'Position', [255, 120, 305, 190], 'Inputs', '+++');
add_line(model, 'TrueSig/1','SumAll/1');
add_line(model, 'SumNoise/1','SumAll/2');
add_line(model, 'Noise/1',   'SumAll/3');

% 24-bit 量化
add_block('simulink/Discontinuities/Quantizer', [model '/Quant'], ...
    'Position', [355, 120, 405, 170], 'QuantizationInterval', '2/2^24');
add_line(model, 'SumAll/1', 'Quant/1');

%% ============= 2. 三级 MA — z-domain 流程图 =============
% 每级布局:
%      X+0 ~ X+35:    zM  (Delay M)  — 靠上
%      X+70~X+105:    Sub (Add +-)    — 主路径
%      X+145~X+185:   G   (Gain 1/M) — 主路径
%      X+220~X+255:   Acc (Add ++)    — 主路径
%      X+220~X+250:   Uz  (Unit Delay) — 靠下, Acc正下方
%
% 连线:
%   input ──┬──→ zM(in)
%           └──→ Sub(+)
%   zM(out) ──→ Sub(-)
%   Sub → G → Acc(+)
%   Acc ──┬──→ Uz(in) [竖直向下]
%         │   Uz(out) → Acc(+) [竖直向上, 反馈]
%         └──→ 下一级 input

X0 = 460;      % Stage 1 X起点
DX = 270;      % 级间距
YM = 130;      % 主路径 Y
YB = YM + 70;  % 反馈 Uz Y (Acc正下方)

for s = 1:3
    X = X0 + (s-1)*DX;
    S = num2str(s);

    % --- 创建块 ---
    % z⁻ᴹ: Delay(M) — 左上
    add_block('simulink/Discrete/Delay', [model '/zM' S], ...
        'Position', [X-10, YM-50, X+25, YM-25], ...
        'DelayLength', M_str, 'SampleTime', Ts_str);

    % Σ(+/-) — 主路径
    add_block('simulink/Math Operations/Add', [model '/Sub' S], ...
        'Position', [X+65, YM-5, X+100, YM+35], 'Inputs', '|+-');

    % ×1/M — 主路径
    add_block('simulink/Math Operations/Gain', [model '/G' S], ...
        'Position', [X+145, YM, X+185, YM+30], 'Gain', ['1/' M_str]);

    % Σ(++) — 主路径
    add_block('simulink/Math Operations/Add', [model '/Acc' S], ...
        'Position', [X+220, YM-5, X+255, YM+35], 'Inputs', '++');

    % z⁻¹: Unit Delay — Acc 正下方 (竖直反馈)
    add_block('simulink/Discrete/Unit Delay', [model '/Uz' S], ...
        'Position', [X+220, YB, X+250, YB+30], 'SampleTime', Ts_str);

    % --- 连线 (块名相对 model) ---
    % input → zM(in) AND Sub(+)
    if s == 1
        src = 'Quant/1';
    else
        src = ['Acc' num2str(s-1) '/1'];
    end
    add_line(model, src, ['zM' S '/1']);
    add_line(model, src, ['Sub' S '/1']);

    % zM(out) → Sub(-)
    add_line(model, ['zM' S '/1'], ['Sub' S '/2']);

    % Sub → G → Acc
    add_line(model, ['Sub' S '/1'], ['G' S '/1']);
    add_line(model, ['G' S '/1'], ['Acc' S '/2']);

    % Acc → Uz (竖直向下)
    add_line(model, ['Acc' S '/1'], ['Uz' S '/1']);

    % Uz → Acc (竖直向上, 反馈)
    add_line(model, ['Uz' S '/1'], ['Acc' S '/1']);
end

%% ============= 3. 抽取 + 输出 =============
X3 = X0 + 2*DX;  % Stage 3位置

% Rate Transition: 2MHz → 50Hz
add_block('simulink/Signal Attributes/Rate Transition', [model '/RT'], ...
    'Position', [X3+300, YM, X3+350, YM+30], ...
    'OutPortSampleTimeOpt', 'Specify', ...
    'OutPortSampleTime', num2str(M_val*Ts));
add_line(model, 'Acc3/1', 'RT/1');

% To Workspace
add_block('simulink/Sinks/To Workspace', [model '/T_Filt'], ...
    'Position', [X3+400, YM-5, X3+460, YM+35], ...
    'VariableName', 'sim_filt_z', 'SaveFormat', 'Array');
add_line(model, 'RT/1', 'T_Filt/1');

add_block('simulink/Sinks/To Workspace', [model '/T_ADC'], ...
    'Position', [460, 50, 520, 90], ...
    'VariableName', 'sim_adc_z', 'SaveFormat', 'Array');
add_line(model, 'Quant/1', 'T_ADC/1');

add_block('simulink/Sinks/To Workspace', [model '/T_True'], ...
    'Position', [240, 310, 300, 350], ...
    'VariableName', 'sim_true_z', 'SaveFormat', 'Array');
add_line(model, 'TrueSig/1', 'T_True/1');

%% ============= 4. Scope =============
add_block('simulink/Sinks/Scope', [model '/Scope'], ...
    'Position', [850, 260, 1050, 480], ...
    'NumInputPorts', '2', 'LayoutDimensionsString', '[2,1]');

add_block('simulink/Signal Routing/Mux', [model '/Mux'], ...
    'Position', [610, 280, 640, 315], 'Inputs', '2');
add_line(model, 'Quant/1', 'Mux/1');
add_line(model, 'TrueSig/1', 'Mux/2');
add_line(model, 'Mux/1', 'Scope/1');
add_line(model, 'RT/1', 'Scope/2');

%% ============= 5. 保存 =============
save_system(model);
fprintf('✅ 模型已保存: %s.slx\n', model);
fprintf('\n');
fprintf('每级 MA 流程图:\n');
fprintf('   input ──┬──→ [z⁻%d] ──→ [Σ(+/-)] ──→ [×1/M] ──→ [Σ(++)] ──→ output\n', M_val);
fprintf('           │       ↑         ↑\n');
fprintf('           └───────┘         │\n');
fprintf('                              ↑\n');
fprintf('                            [z⁻¹]  ←──┘ (反馈环路)\n');
fprintf('\n');
fprintf('仿真: sim(''%s'');  Scope查看波形\n', model);
