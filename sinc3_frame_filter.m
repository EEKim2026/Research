function y = sinc3_frame_filter(u)
%SINC3_FRAME_FILTER Streaming sinc^3 filter with persistent buffer.
%   u = Mx1 frame of new ADC samples
%   y = decimated output (1 sample per M inputs)
%
%   Maintains a 3M-sample history buffer internally so that the
%   3-stage moving average has enough context across frame boundaries.
%   Result matches sinc3_nplc_filter(u_full, fs, 1, f_line) exactly.

persistent buf

M = length(u);
v = u(:);

if isempty(buf)
    buf = zeros(3*M, 1);  % circular history buffer
end

% Shift: discard oldest M samples, append the M new samples
buf = [buf(M+1:end); v];  % now length = 3M

% Three cascaded moving averages over the full 3M-sample buffer
% (same cumsum-diff method as sinc3_nplc_filter.m)
cs1 = cumsum([zeros(M,1); buf]);
s1 = (cs1(M+1:end) - cs1(1:end-M)) / M;   % length = 3M

cs2 = cumsum([zeros(M,1); s1]);
s2 = (cs2(M+1:end) - cs2(1:end-M)) / M;   % length = 3M

cs3 = cumsum([zeros(M,1); s2]);
s3 = (cs3(M+1:end) - cs3(1:end-M)) / M;   % length = 3M

% Output = last point = fully settled result for the new M samples
y = s3(end);

end
