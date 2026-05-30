---
name: matlab-workflow
description: MATLAB + Simulink 数字信号处理项目标准化工作流 — 算法设计、建模、仿真、打包全流程
---

# MATLAB + Simulink 数字信号处理 — 标准化工作流

## 工作流概览

```
算法设计(.m) → Simulink 建模(.slx) → 仿真验证 → 打包报告
```

## 阶段一: 算法设计与验证

### 目录结构规范

```
project_root/
├── *.m                  ← 核心算法函数
├── test_*.m             ← 测试脚本
├── figures/             ← 测试生成的图片
├── matlab_project/      ← 打包后的交付目录
│   ├── REPORT.md
│   ├── *.m
│   └── figures/
├── *.slx                ← Simulink 模型
├── build_*.m            ← 构建脚本
└── run_*.m              ← 运行/验证脚本
```

### 核心算法函数规范

```matlab
function [out1, out2] = my_filter(input_data, param1, param2)
%MY_FILTER 一行描述
%   [out1, out2] = MY_FILTER(input_data, param1, param2)
%   输入/输出说明, 算法描述
    if nargin < 2 || isempty(param1), param1 = default; end
    % O(N) 算法主体, 避免嵌套循环
end
```

### 测试脚本模板

```matlab
%% test_my_filter.m
clear; close all; clc;
%% 1. 参数设置
%% 2. 生成测试信号 (含已知参考值)
%% 3. 运行滤波
%% 4. 数值验证 (assert 与理论值比较)
%% 5. 绘图保存到 figures/
%% 6. 打印结果
```

**代码质量** — 用 `check_matlab_code` 检查: 无未用变量、无硬编码路径、函数有完整 help。

## 阶段二: Simulink 建模

### 三种实现方式

| 方式 | 适用 | 优点 | 缺点 |
|------|------|------|------|
| **MATLAB Function** | 快速原型 | 代码复用 | 运行慢 |
| **z-domain 流程图** | 教学/文档 | 结构清晰 | 搭模工作量大 |
| **DSP Block** | 产品级 | 效率最高 | 需了解专用 block |

### 构建脚本核心模式

```matlab
model = 'my_model';
if bdIsLoaded(model), close_system(model, 0); end
if exist([model '.slx'], 'file'), delete([model '.slx']); end
new_system(model); open_system(model);
set_param(model, 'StopTime', '0.5', 'Solver', 'FixedStepDiscrete', 'FixedStep', '5e-7');

% 添加块: add_block('库路径', [model '/块名'], 'Position', [x,y,w,h], ...)
% 连线:   add_line(model, 'SrcBlk/端口', 'DstBlk/端口')
%         注意块名相对 model, 不加 model 前缀!

save_system(model);
```

**Subsystem 封装**:
```matlab
sub = [model '/MySub'];
add_block('simulink/Ports & Subsystems/Subsystem', sub, ...);
% 删除默认块, 重加 In1/Out1
% 子系统内连线用 add_line(sub, 'In1/1', ...)
```

### 常用块路径 (R2026a)

- 信号源: `simulink/Sources/Sine Wave`, `Constant`, `Random Number`
- 数学: `simulink/Math Operations/Add`, `Gain`
- 离散: `simulink/Discrete/Unit Delay`, `Delay`, `Quantizer`
- 信号属性: `simulink/Signal Attributes/Rate Transition`
- 子系统: `simulink/Ports & Subsystems/Subsystem`, `In1`, `Out1`
- 接收器: `simulink/Sinks/Scope`, `To Workspace`
- 路由: `simulink/Signal Routing/Mux`
- DSP: `dspobslib/CIC Decimation`, `dspbuff3/Buffer`

## 阶段三: 仿真与验证

```matlab
out = sim('my_model');
data = out.get('VariableName');  % To Workspace 数据

% 对比 MATLAB 参考
err = sim_out - ref_out(1:length(sim_out));
fprintf('RMS diff: %.2e\n', rms(err));
assert(rms(err) < 1e-6, '差异过大!');
```

Scope 截图: 用 To Workspace 数据 + MATLAB plot, 不用 print Scope。

## 阶段四: 打包与报告

### 打包脚本

- 创建 `matlab_project/` 目标文件夹
- 复制核心文件 (.m, .slx, figures/)
- 生成 REPORT.md

### REPORT.md 章节

1. 设计概述 (目标、规格、原理)
2. 算法原理 (数学推导、传递函数、参数)
3. MATLAB 实现 (核心函数、测试)
4. Simulink 实现 (模型结构、模块说明、三种方式对比)
5. 仿真结果与分析 (时域/频域图、数值表、性能指标、交叉验证)
6. 文件清单

### 最终检查清单

- [ ] 核心算法 .m 可运行
- [ ] 测试脚本可重复执行
- [ ] .slx 可打开
- [ ] 构建脚本可重新生成 .slx
- [ ] 关键结果有截图
- [ ] REPORT.md 完整

## 常见问题

| 问题 | 原因 | 解决 |
|------|------|------|
| `add_line` 报错 | 块路径含 model 前缀 | 用相对路径 |
| To Workspace 变量读不到 | 需 `out.get('VarName')` | 用 get 方法 |
| 仿真慢 | 步长太小/M 太大 | 减 T_sim/增 decimation |
| Scope 看不到波形 | 时间轴不对/点太多 | 用 Rate Transition 降采样 |
