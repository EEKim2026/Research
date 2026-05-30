%% run_sinc3_zdomain.m
% 运行 z-domain 流程图模型并验证
run('D:\matlab_filter_test\build_sinc3_zdomain.m')
out = sim('sinc3_zdomain');

filt = out.get('sim_filt_z');
adc = out.get('sim_adc_z');
tru = out.get('sim_true_z');

fs=2e6; M=40000; f_line=50;
[ref,~] = sinc3_nplc_filter(adc, fs, 1, f_line);
err = filt - ref(1:min(end,length(filt)));

fprintf('\n===== z-domain 流程图模型 验证 =====\n');
fprintf('RMS 差异: %.2e\n\n', rms(err));

t_out = (0:length(filt)-1)'*M/fs*1000;
fprintf('  # | 时间(ms) |  滤波输出  |  真实信号 |  误差\n');
for i = 1:min(length(filt),15)
    idx_t = round(i*M - 1.5*M);
    tv = tru(min(max(idx_t,1), length(tru)));
    if idx_t < 1, tv_str = '(瞬态)'; else tv_str = sprintf('%+.4f', tv); end
    fprintf('%3d | %8.3f | %+.6f | %s | %+.2e\n', ...
            i, t_out(i), filt(i), tv_str, err(i));
end

fprintf('\n打开模型: open_system(''sinc3_zdomain'')\n');
fprintf('双击 Scope 查看: 上=ADC输入+真实信号, 下=滤波输出\n');
