function [filtered_data, odr] = sinc3_nplc_filter(raw_data, fs, nplc, f_line)
%SINC3_NPLC_FILTER Apply sinc^3 digital filter for NPLC power line rejection.
%   [filtered_data, odr] = sinc3_nplc_filter(raw_data, fs, nplc, f_line)
%
%   Three cascaded moving-average filters (sinc^3) suppress power line
%   frequency content, then decimate by M.
%
%   Inputs:
%     raw_data - Input signal vector (double)
%     fs       - Sample rate in Hz (default: 2e6)
%     nplc     - Number of power line cycles (default: 1)
%     f_line   - Power line frequency in Hz (default: 50)
%
%   Outputs:
%     filtered_data - Decimated filtered output
%     odr           - Output data rate in Hz

    if nargin < 2 || isempty(fs),     fs     = 2e6; end
    if nargin < 3 || isempty(nplc),   nplc   = 1;   end
    if nargin < 4 || isempty(f_line), f_line = 50;  end

    M = round(nplc * fs / f_line);
    data = raw_data(:);
    N = length(data);

    if N < 3 * M
        warning('Input length (%d) < 3*M (%d). Output may be truncated.', N, 3*M);
    end

    % --- Stage 1: causal moving average of length M ---
    %   y[n] = (1/M) * sum_{k=0}^{M-1} x[n-k]
    %   Using cumsum-diff trick with M initial zeros for O(N) complexity.
    cs = cumsum([zeros(M, 1); data]);
    s1 = (cs(M+1:end) - cs(1:end-M)) / M;

    % --- Stage 2 ---
    cs = cumsum([zeros(M, 1); s1]);
    s2 = (cs(M+1:end) - cs(1:end-M)) / M;

    % --- Stage 3 ---
    cs = cumsum([zeros(M, 1); s2]);
    s3 = (cs(M+1:end) - cs(1:end-M)) / M;

    % --- Decimate by M ---
    filtered_data = s3(1:M:end);
    odr = fs / M;

end
