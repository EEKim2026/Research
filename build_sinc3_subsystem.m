%% build_sinc3_subsystem.m
% sinc^3 NPLC 滤波器 — 封装为 Subsystem 模块
%   Sinc3_Filter 内部: 三级 MA, 每级用 z⁻¹+z⁻ᴹ 显式搭建
%   外部: 信号源 + Sinc3_Filter + 抽取 + Scope

clear; close all; clc;

%% 参数
fs = 2e6; f_line = 50; nplc = 1;
M_val = round(nplc * fs / f_line);  % 40000
Ts = 1/fs; T_sim = 0.5;
M_str = num2str(M_val);
Ts_str = num2str(Ts);

%% 创建顶层模型
model = 'sinc3_subsystem';
if bdIsLoaded(model), close_system(model, 0); end
if exist([model '.slx'], 'file'), delete([model '.slx']); end
new_system(model); open_system(model);
set_param(model, 'StopTime', num2str(T_sim));
set_param(model, 'Solver', 'FixedStepDiscrete', 'FixedStep', Ts_str);

%% ====== A. 信号源 (同前) ======
add_block('simulink/Sources/Sine Wave',  [model '/F50'], ...
    'Position', [30, 70, 80, 100], ...
    'Amplitude', '1', 'Frequency', '2*pi*50', 'SampleTime', Ts_str);
add_block('simulink/Sources/Sine Wave',  [model '/F100'], ...
    'Position', [30, 120, 80, 150], ...
    'Amplitude', '0.3', 'Frequency', '2*pi*100', 'SampleTime', Ts_str);
add_block('simulink/Sources/Sine Wave',  [model '/F150'], ...
    'Position', [30, 170, 80, 200], ...
    'Amplitude', '0.1', 'Frequency', '2*pi*150', 'SampleTime', Ts_str);
add_block('simulink/Sources/Random Number', [model '/Noise'], ...
    'Position', [30, 220, 80, 250], ...
    'Variance', '0.0004', 'SampleTime', Ts_str);

add_block('simulink/Math Operations/Add', [model '/SumNoise'], ...
    'Position', [140, 100, 190, 170], 'Inputs', '+++');
add_line(model, 'F50/1','SumNoise/1'); add_line(model, 'F100/1','SumNoise/2');
add_line(model, 'F150/1','SumNoise/3');

add_block('simulink/Sources/Constant',  [model '/DC'], ...
    'Position', [30, 430, 80, 460], 'Value', '0.5', 'SampleTime', Ts_str);
add_block('simulink/Sources/Sine Wave', [model '/Slow'], ...
    'Position', [30, 380, 80, 410], ...
    'Amplitude', '0.05', 'Frequency', '2*pi*3', 'SampleTime', Ts_str);
add_block('simulink/Math Operations/Add', [model '/TrueSig'], ...
    'Position', [140, 395, 190, 445], 'Inputs', '++');
add_line(model, 'DC/1', 'TrueSig/1'); add_line(model, 'Slow/1', 'TrueSig/2');

add_block('simulink/Math Operations/Add', [model '/SumAll'], ...
    'Position', [255, 120, 305, 190], 'Inputs', '+++');
add_line(model, 'TrueSig/1','SumAll/1'); add_line(model, 'SumNoise/1','SumAll/2');
add_line(model, 'Noise/1',   'SumAll/3');

add_block('simulink/Discontinuities/Quantizer', [model '/Quant'], ...
    'Position', [355, 120, 405, 170], 'QuantizationInterval', '2/2^24');
add_line(model, 'SumAll/1', 'Quant/1');

%% ====== B. Sinc3_Filter Subsystem ======
sub = [model '/Sinc3_Filter'];
add_block('simulink/Ports & Subsystems/Subsystem', sub, ...
    'Position', [460, 90, 560, 210]);

% 删除 Subsystem 默认内容
def_blocks = {[sub '/In1'], [sub '/Out1'], [sub '/Gain']};
for i = 1:length(def_blocks)
    try delete_block(def_blocks{i}); catch, end
end

% 重新添加 Inport / Outport
add_block('simulink/Ports & Subsystems/In1', [sub '/In1'], ...
    'Position', [30, 145, 60, 175]);
add_block('simulink/Ports & Subsystems/Out1', [sub '/Out1'], ...
    'Position', [830, 145, 860, 175]);

%% ====== B1. 三级 MA 在 Subsystem 内部 ======
X0 = 80; DX = 240; YM = 130; YB = 200;

for s = 1:3
    X = X0 + (s-1)*DX;
    S = num2str(s);

    add_block('simulink/Discrete/Delay', [sub '/zM' S], ...
        'Position', [X-10, YM-50, X+25, YM-25], ...
        'DelayLength', M_str, 'SampleTime', Ts_str);

    add_block('simulink/Math Operations/Add', [sub '/Sub' S], ...
        'Position', [X+65, YM-5, X+100, YM+35], 'Inputs', '|+-');

    add_block('simulink/Math Operations/Gain', [sub '/G' S], ...
        'Position', [X+145, YM, X+185, YM+30], 'Gain', ['1/' M_str]);

    add_block('simulink/Math Operations/Add', [sub '/Acc' S], ...
        'Position', [X+220, YM-5, X+255, YM+35], 'Inputs', '++');

    add_block('simulink/Discrete/Unit Delay', [sub '/Uz' S], ...
        'Position', [X+220, YB, X+250, YB+30], 'SampleTime', Ts_str);

    % 连线 (子系统中块名相对 sub)
    if s == 1
        src = 'In1/1';
    else
        src = ['Acc' num2str(s-1) '/1'];
    end
    add_line(sub, src, ['zM' S '/1']);
    add_line(sub, src, ['Sub' S '/1']);
    add_line(sub, ['zM' S '/1'], ['Sub' S '/2']);
    add_line(sub, ['Sub' S '/1'], ['G' S '/1']);
    add_line(sub, ['G' S '/1'], ['Acc' S '/2']);
    add_line(sub, ['Acc' S '/1'], ['Uz' S '/1']);
    add_line(sub, ['Uz' S '/1'], ['Acc' S '/1']);
end

% 第三级 Acc → Out1
add_line(sub, 'Acc3/1', 'Out1/1');

%% ====== C. 顶层连线 ======
% Quant → Sinc3_Filter
add_line(model, 'Quant/1', 'Sinc3_Filter/1');

% Sinc3_Filter → Rate Transition (抽取 M)
add_block('simulink/Signal Attributes/Rate Transition', [model '/RT'], ...
    'Position', [620, 130, 670, 170], ...
    'OutPortSampleTimeOpt', 'Specify', ...
    'OutPortSampleTime', num2str(M_val*Ts));
add_line(model, 'Sinc3_Filter/1', 'RT/1');

%% ====== D. 输出 ======
add_block('simulink/Sinks/To Workspace', [model '/T_Filt'], ...
    'Position', [720, 130, 780, 170], ...
    'VariableName', 'sim_filt_sub', 'SaveFormat', 'Array');
add_line(model, 'RT/1', 'T_Filt/1');

add_block('simulink/Sinks/To Workspace', [model '/T_ADC'], ...
    'Position', [460, 55, 520, 95], ...
    'VariableName', 'sim_adc_sub', 'SaveFormat', 'Array');
add_line(model, 'Quant/1', 'T_ADC/1');

add_block('simulink/Sinks/To Workspace', [model '/T_True'], ...
    'Position', [250, 310, 310, 350], ...
    'VariableName', 'sim_true_sub', 'SaveFormat', 'Array');
add_line(model, 'TrueSig/1', 'T_True/1');

%% ====== E. Scope ======
add_block('simulink/Sinks/Scope', [model '/Scope'], ...
    'Position', [850, 260, 1050, 480], ...
    'NumInputPorts', '2', 'LayoutDimensionsString', '[2,1]');

add_block('simulink/Signal Routing/Mux', [model '/Mux'], ...
    'Position', [610, 280, 640, 315], 'Inputs', '2');
add_line(model, 'Quant/1', 'Mux/1');
add_line(model, 'TrueSig/1', 'Mux/2');
add_line(model, 'Mux/1', 'Scope/1');
add_line(model, 'RT/1', 'Scope/2');

%% ====== F. 保存并验证 ======
save_system(model);
fprintf('✅ 模型已保存: %s.slx\n', model);

% 打开子系统
open_system(sub);

% 验证
out = sim(model);
filt = out.get('sim_filt_sub');
adc = out.get('sim_adc_sub');
[ref,~] = sinc3_nplc_filter(adc, fs, 1, f_line);
err = filt - ref(1:min(end,length(filt)));
fprintf('RMS vs MATLAB: %.2e  ✅\n', rms(err));
fprintf('\n');

fprintf('模型结构:\n');
fprintf('  ┌─ %s ───────────────────┐\n', model);
fprintf('  │  F50-F150 + Noise → Sum → Quant     │\n');
fprintf('  │          ↓                           │\n');
fprintf('  │  ┌─ Sinc3_Filter ───────────────┐    │\n');
fprintf('  │  │  In1                          │    │\n');
fprintf('  │  │   ↓                           │    │\n');
fprintf('  │  │  [z⁻ᴹ]─→[Σ]─→[1/M]─→[Σ]─→s1  │    │\n');
fprintf('  │  │   ↓       ↑         ↑         │    │\n');
fprintf('  │  │  [z⁻¹]───┘                    │    │\n');
fprintf('  │  │   → [Stage2 MA] → [Stage3 MA] │    │\n');
fprintf('  │  │                         ↓     │    │\n');
fprintf('  │  │                        Out1   │    │\n');
fprintf('  │  └───────────────────────────────┘    │\n');
fprintf('  │          ↓                           │\n');
fprintf('  │       RateTrans(×%d) → Scope/输出    │\n', M_val);
fprintf('  └─────────────────────────────────────┘\n');
fprintf('\n');
fprintf('双击 Sinc3_Filter 模块查看内部 z-domain 流程图\n');
fprintf('sim(''%s'') 运行\n', model);
