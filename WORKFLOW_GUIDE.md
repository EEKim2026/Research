# MATLAB 项目工作流指导书

> 使用 MATLAB + Simulink 做数字信号处理设计时的标准化工作流  
> 适用: MATLAB R2026a | DSP System Toolbox | Simulink  
> 版本: 1.0 | 2026-05-30

---

## 目录

1. [工作流概览](#1-工作流概览)
2. [阶段一: 算法设计与验证](#2-阶段一-算法设计与验证)
3. [阶段二: Simulink 建模](#3-阶段二-simulink-建模)
4. [阶段三: 仿真与验证](#4-阶段三-仿真与验证)
5. [阶段四: 打包与报告](#5-阶段四-打包与报告)
6. [最佳实践与模板](#6-最佳实践与模板)

---

## 1. 工作流概览

```
┌──────────────────────────────────────────────────────┐
│           MATLAB 项目标准工作流                        │
├──────────────────────────────────────────────────────┤
│                                                        │
│  [阶段一] 算法设计与验证                                 │
│  ┌────────────────────────────────────────────────┐   │
│  │  1. 编写核心算法函数 (.m)                       │   │
│  │  2. 编写数值测试脚本                            │   │
│  │  3. 运行验证: 代码分析 + 数值对比               │   │
│  └──────────────────┬─────────────────────────────┘   │
│                      ↓                                 │
│  [阶段二] Simulink 建模                                │
│  ┌────────────────────────────────────────────────┐   │
│  │  1. 选择实现方式 (z-domain / CIC / MATLAB Fcn)  │   │
│  │  2. 编写构建脚本 build_*.m                      │   │
│  │  3. 运行构建生成 .slx 文件                      │   │
│  └──────────────────┬─────────────────────────────┘   │
│                      ↓                                 │
│  [阶段三] 仿真与验证                                   │
│  ┌────────────────────────────────────────────────┐   │
│  │  1. 运行 Simulink 仿真                          │   │
│  │  2. 对比 MATLAB 函数输出 (RMS误差 < 1e-6)       │   │
│  │  3. Scope 观察波形, 截图保存                    │   │
│  └──────────────────┬─────────────────────────────┘   │
│                      ↓                                 │
│  [阶段四] 打包与报告                                   │
│  ┌────────────────────────────────────────────────┐   │
│  │  1. 整理源码到项目文件夹                        │   │
│  │  2. 保存仿真截图                                │   │
│  │  3. 生成 REPORT.md + WORKFLOW_GUIDE.md          │   │
│  └──────────────────┬─────────────────────────────┘   │
│                      ↓                                 │
│               ✅ 项目完成                               │
└──────────────────────────────────────────────────────┘
```

---

## 2. 阶段一: 算法设计与验证

### 2.1 目录结构规范

```
project_root/
├── *.m              ← 核心算法函数
├── test_*.m         ← 测试脚本
├── figures/         ← 测试生成的图片
├── matlab_project/  ← 打包后的交付目录
│   ├── REPORT.md
│   ├── WORKFLOW_GUIDE.md
│   ├── *.m
│   └── figures/
└── *.slx            ← Simulink 模型
```

### 2.2 编写核心算法

**规范**:

```matlab
function [out1, out2] = my_filter(input_data, param1, param2)
%MY_FILTER 一行简要描述函数功能
%   [out1, out2] = MY_FILTER(input_data, param1, param2)
%
%   详细的功能描述, 算法说明
%
%   输入:
%     input_data - 说明 (维度, 单位)
%     param1     - 说明 (默认值)
%     param2     - 说明 (默认值)
%
%   输出:
%     out1 - 说明
%     out2 - 说明

    % 参数默认值
    if nargin < 2 || isempty(param1), param1 = default_val; end

    % 算法主体 (带注释)
    % ...

end
```

**关键原则**:
- 每行一个 `%` 注释说明
- 使用 O(N) 算法, 避免嵌套循环
- 输入参数带默认值检查
- 函数单一职责

### 2.3 编写测试脚本

```matlab
%% test_my_filter.m
% 测试脚本: 验证 + 对比 + 绘图

clear; close all; clc;

%% 1. 参数设置
fs = 2e6;
% ...

%% 2. 生成测试信号
t = (0:N-1)' / fs;
signal = ...    % 包含已知参考值

%% 3. 运行滤波
[filtered, odr] = my_filter(signal, fs, ...);

%% 4. 数值验证
% 与理论值比较
expected = ...;
assert(max(abs(filtered - expected)) < tolerance, ...
    '测试失败: 误差超出范围');

%% 5. 绘图 (保存到 figures/)
figure;
plot(...);
saveas(gcf, fullfile('figures', 'result.png'));

%% 6. 打印结果
fprintf('ODR = %.2f Hz\n', odr);
```

### 2.4 代码质量检查

```matlab
% 使用 MATLAB Code Analyzer (MCP Server tool)
% 命令: check_matlab_code('path/to/file.m')

% 手动检查项:
% ✅ 无未使用的变量
% ✅ 所有路径使用 fullfile() 构建
% ✅ 无硬编码路径 (使用相对路径或参数)
% ✅ 函数有完整的 help 文档
```

---

## 3. 阶段二: Simulink 建模

### 3.1 三种实现方式选择

| 方式 | 适用场景 | 优点 | 缺点 |
|------|---------|------|------|
| **MATLAB Function** | 快速原型 | 代码复用, 调试方便 | 运行速度慢 |
| **z-domain 流程图** | 教学/文档 | 结构清晰, 无黑盒 | 搭模工作量大 |
| **DSP Block (CIC等)** | 产品级 | 效率最高 | 需了解专用 block |

### 3.2 构建脚本模板

```matlab
%% build_my_model.m
% 构建 Simulink 模型
% 使用 add_block / add_line 编程式搭模

clear; close all; clc;

%% 参数区 (所有参数集中在此)
fs = 2e6;
Ts = 1/fs;
model = 'my_model';

%% 创建模型
if bdIsLoaded(model), close_system(model, 0); end
if exist([model '.slx'], 'file'), delete([model '.slx']); end
new_system(model); open_system(model);

set_param(model, 'StopTime', '0.5');
set_param(model, 'Solver', 'FixedStepDiscrete');
set_param(model, 'FixedStep', num2str(Ts));

%% 添加块
% 注意: add_line(model, 'src_blk/port', 'dst_blk/port')
%       块名相对 model, 不加 model 前缀!

add_block('simulink/Sources/Sine Wave', [model '/Sine'], ...
    'Position', [50, 100, 100, 130], ...
    'Amplitude', '1', 'Frequency', '2*pi*50', ...
    'SampleTime', num2str(Ts));

add_block('simulink/Sinks/Scope', [model '/Scope'], ...
    'Position', [200, 100, 350, 200], ...
    'NumInputPorts', '2', 'LayoutDimensionsString', '[2,1]');

%% 连线
add_line(model, 'Sine/1', 'Scope/1');

%% 保存
save_system(model);
fprintf('✅ 模型已保存: %s.slx\n', model);
```

### 3.3 关键技巧

**块路径**:
```matlab
% Simulink 块路径:R2026a 常用路径
% 信号源:   simulink/Sources/Sine Wave
% 数学运算:  simulink/Math Operations/Add, Gain
% 离散:      simulink/Discrete/Unit Delay, Delay
% 信号属性:  simulink/Signal Attributes/Rate Transition
% 端口:      simulink/Ports & Subsystems/Subsystem, In1, Out1
% 接收器:    simulink/Sinks/Scope, To Workspace
% 信号路由:  simulink/Signal Routing/Mux, Goto, From
% DSP:       dspobslib/CIC Decimation
% Buffer:    dspbuff3/Buffer
```

**add_line 注意事项**:
```matlab
% ✅ 正确: 块名相对 model
add_line(model, 'BlkA/1', 'BlkB/1');

% ❌ 错误: 块名含 model 前缀
add_line(model, 'MyModel/BlkA/1', 'MyModel/BlkB/1');
```

**Subsystem 封装**:
```matlab
% 创建子系统
sub = [model '/MySub'];
add_block('simulink/Ports & Subsystems/Subsystem', sub, ...
    'Position', [200, 100, 300, 200]);

% 删除默认块
try delete_block([sub '/In1']); catch, end
try delete_block([sub '/Out1']); catch, end
try delete_block([sub '/Gain']); catch, end

% 添加输入输出端口
add_block('simulink/Ports & Subsystems/In1', [sub '/In1'], ...
    'Position', [30, 145, 60, 175]);
add_block('simulink/Ports & Subsystems/Out1', [sub '/Out1'], ...
    'Position', [200, 145, 230, 175]);

% 在子系统内添加块 (路径: [sub '/内部块名'])
add_block('simulink/Discrete/Unit Delay', [sub '/Uz'], ...);

% 子系统内连线
add_line(sub, 'In1/1', 'Uz/1');
add_line(sub, 'Uz/1', 'Out1/1');
```

---

## 4. 阶段三: 仿真与验证

### 4.1 运行仿真

```matlab
% 方法 1: 直接 sim
sim('my_model');

% 方法 2: 获取输出
out = sim('my_model');
data = out.get('VariableName');  % To Workspace 数据

% 方法 3: 从输出提取
if isa(data, 'Simulink.SimulationData.Signal')
    values = data.Values.Data;  % 提取数值数组
end
```

### 4.2 验证方法

```matlab
%% 对比 Simulink 与 MATLAB 函数
sim_out = out.get('sim_filtered');
ref_out = my_filter(sim_adc, fs, ...);

err = sim_out - ref_out(1:length(sim_out));
rms_err = rms(err);
fprintf('RMS difference: %.2e\n', rms_err);
assert(rms_err < 1e-6, '差异过大!');
```

### 4.3 Scope 截图

```matlab
% 方法: 使用工作区数据绘图代替 Scope 截图
figure('Visible', 'off');
subplot(2,1,1);
plot(t, input_signal); title('Input');
subplot(2,1,2);
plot(t_out, filtered); title('Output');
saveas(gcf, 'figures/scope_result.png');
```

---

## 5. 阶段四: 打包与报告

### 5.1 打包脚本模板

```matlab
%% package_project.m
% 打包项目文件 + 生成报告

% 1. 创建目标文件夹
SRC = pwd;
DST = fullfile(SRC, 'matlab_project');
mkdir(DST);

% 2. 复制文件
files = {'core_filter.m', 'test_script.m', 'model.slx'};
for i = 1:length(files)
    copyfile(fullfile(SRC, files{i}), fullfile(DST, files{i}));
end

% 3. 生成截图
run(fullfile(SRC, 'test_script.m'));  % 先生成图
mkdir(fullfile(DST, 'figures'));
copyfile(fullfile(SRC, 'figures', '*'), fullfile(DST, 'figures'));

fprintf('✅ 打包完成: %s\n', DST);
```

### 5.2 报告模板 (REPORT.md)

报告应包含以下章节:

```markdown
# 项目名称设计报告

> 项目简介 | 日期 | 环境

---

## 1. 设计概述
- 设计目标
- 规格参数
- 工作原理

## 2. 算法原理
- 数学推导
- 传递函数
- 参数设计

## 3. MATLAB 实现
- 核心函数说明
- 测试脚本说明
- 关键代码段

## 4. Simulink 实现
- 模型结构框图
- 关键模块说明
- z-domain 流程图 (如适用)

## 5. 仿真结果与分析
- MATLAB 测试结果 (含截图)
- Simulink 仿真结果 (含 Scope 截图)
- 数值对比表
- 性能指标

## 6. 文件清单
- 所有文件及说明
```

### 5.3 最终交付物检查清单

| 检查项 | 要求 |
|-------|------|
| ✅ 核心算法 | 完整可运行的 .m 文件 |
| ✅ 测试脚本 | 可重复执行的测试 |
| ✅ Simulink 模型 | 可打开的 .slx 文件 |
| ✅ 构建脚本 | 可重新生成 .slx |
| ✅ 仿真截图 | 关键结果的图像 |
| ✅ 设计报告 | REPORT.md |
| ✅ 工作流指导 | WORKFLOW_GUIDE.md |

---

## 6. 最佳实践与模板

### 6.1 通用模板: 完整的项目脚手架

每次启动新 MATLAB 项目时, 创建以下文件:

```
project_name/
├── core_algorithm.m           ← 核心算法 (手动编写)
├── test_core_algorithm.m      ← 测试脚本 (手动编写)
├── build_simulink_model.m     ← 构建脚本 (手动编写)
├── run_and_verify.m           ← 运行+验证 (手动编写)
├── package_project.m          ← 打包脚本 (复用此模板)
├── REPORT.md                  ← 报告 (自动生成)
├── WORKFLOW_GUIDE.md          ← 指导书 (复用此文件)
└── figures/                   ← 截图目录 (自动生成)
```

### 6.2 常用 Simulink 块路径速查 (R2026a)

```
信号源
  Sine Wave:       simulink/Sources/Sine Wave
  Constant:        simulink/Sources/Constant
  Random Number:   simulink/Sources/Random Number

数学运算
  Add:             simulink/Math Operations/Add
  Gain:            simulink/Math Operations/Gain
  Mux:             simulink/Signal Routing/Mux

离散系统
  Unit Delay:      simulink/Discrete/Unit Delay
  Delay:           simulink/Discrete/Delay
  Quantizer:       simulink/Discontinuities/Quantizer

信号属性
  Rate Transition: simulink/Signal Attributes/Rate Transition
  Data Type Conv:  simulink/Commonly Used Blocks/Data Type Conversion

子系统
  Subsystem:       simulink/Ports & Subsystems/Subsystem
  Inport:          simulink/Ports & Subsystems/In1
  Outport:         simulink/Ports & Subsystems/Out1

接收器
  Scope:           simulink/Sinks/Scope
  To Workspace:    simulink/Sinks/To Workspace

DSP (老版)
  CIC Decimation:  dspobslib/CIC Decimation
  Buffer:          dspbuff3/Buffer
```

### 6.3 常见问题排查

| 问题 | 原因 | 解决 |
|------|------|------|
| `add_line` 报 "对象名称无效" | 块路径含 model 前缀 | 使用相对路径 |
| To Workspace 变量读不到 | 需用 `out.get('VarName')` | 见 4.1 节 |
| Simulink 仿真速度慢 | 步长太小或 M 太大 | 减少 T_sim 或增大 decimation |
| Scope 看不到波形 | 时间轴不对或数据点太多 | 用 Rate Transition 降采样 |
| CIC 报 "frame 错误" | 需 Buffer 或 frame 模式 | 改用 MATLAB Function 或手动搭 MA |

---

> **版本记录**  
> v1.0 - 2026-05-30 - 初始版本, 基于 sinc³ NPLC 滤波器项目经验总结
