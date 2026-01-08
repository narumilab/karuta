function mfcc_matrix = extract_single_mfcc_delta(y, Fs)
    % extract_single_mfcc: 単一の音声信号からMFCC、Δ、ΔΔを自前計算で抽出
    
    % -------- 1. MFCCの抽出（Audio Toolbox） --------
    coeffs = mfcc(y, Fs);   % (numFrames × numCoeffs)
    
    numFrames = size(coeffs, 1);
    numCoeffs = size(coeffs, 2);

    % 事前確保
    delta = zeros(numFrames, numCoeffs);
    deltaDelta = zeros(numFrames, numCoeffs);

    % 前フレームの初期化
    prev_coeff = zeros(1, numCoeffs);
    prev_delta = zeros(1, numCoeffs);

    % -------- 2. Δ と ΔΔ の自前計算 --------
    for t = 1:numFrames
        curr = coeffs(t, :);

        % Δ = 現MFCC − 前MFCC
        delta(t, :) = curr - prev_coeff;

        % ΔΔ = 現Δ − 前Δ
        deltaDelta(t, :) = delta(t, :) - prev_delta;

        % 更新
        prev_coeff = curr;
        prev_delta = delta(t, :);
    end

    % -------- 3. MFCC + Δ + ΔΔ を結合 --------
    mfcc_matrix = [coeffs, delta, deltaDelta];
end
