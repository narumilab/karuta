% example: [mfccs, fudas] = wav_to_mfcc('./aihara_wav')
function [mfccs, fudas] = wav_to_mfcc(wav_dir)

    entries = dir(wav_dir);
    isSubfolder = [entries.isdir] & ~ismember({entries.name}, {'.', '..'});
    subfolders = fullfile(wav_dir, {entries(isSubfolder).name});
    folderNames = cellfun(@(p) split(p, filesep), subfolders, 'UniformOutput', false);
    fudas = cellfun(@(parts) parts{end}, folderNames, 'UniformOutput', false);

    mfccs = cell(1, length(subfolders));

    for i = 1:length(subfolders)
        files = dir(fullfile(subfolders{i}, '*.wav'));
        mfcc_cell = cell(1, length(files));

        for j = 1:length(files)

            [y, Fs] = audioread(fullfile(subfolders{i}, files(j).name));
            coeffs = mfcc(y, Fs);   % (numFrames × numCoeffs)

            numFrames = size(coeffs, 1);
            numCoeffs = size(coeffs, 2);

            delta = zeros(numFrames, numCoeffs);
            deltaDelta = zeros(numFrames, numCoeffs);

            % 前フレーム値の初期化
            prev_coeff = zeros(1, numCoeffs);
            prev_delta = zeros(1, numCoeffs);

            for t = 1:numFrames
                curr = coeffs(t, :);

                % Δ = 現在 − 前フレーム
                delta(t, :) = curr - prev_coeff;

                % ΔΔ = Δ − 前Δ
                deltaDelta(t, :) = delta(t, :) - prev_delta;

                % 更新
                prev_coeff = curr;
                prev_delta = delta(t, :);
            end

            % MFCC, Δ, ΔΔ を縦方向に連結 → (numFrames × (3*numCoeffs))
            mfcc_cell{j} = [coeffs, delta, deltaDelta];
        end

        mfccs{i} = mfcc_cell;
    end
end
