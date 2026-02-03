% example: [mfccs,fudas]=wav_to_mfcc('./aihara_wav')
% 指定ディレクトリ内のサブフォルダごとにWAVファイルを読み込み、MFCC特徴量を抽出する関数
% 戻り値:
% mfccs: {{MFCC行列}} の形式で返す

function [mfccs,fudas]=wav_to_mfcc(wav_dir)
    entries = dir(wav_dir);
    isSubfolder = [entries.isdir] & ~ismember({entries.name}, {'.', '..'});
    subfolders = fullfile(wav_dir, {entries(isSubfolder).name});
    folderNames = cellfun(@(p) split(p, filesep), subfolders, 'UniformOutput', false);
    fudas = cellfun(@(parts) parts{end}, folderNames, 'UniformOutput', false);
    mfccs = cell(1,length(subfolders));
    for i=1:length(subfolders)
        files = dir(fullfile(subfolders{i}, '*.wav'));
        mfccs{i} = cell(1,length(files));
        for j=1:length(files)
            [y,Fs] = audioread(fullfile(subfolders{i},files(j).name));
            mfccs{i}{j} = mfcc(y,Fs);
            [coeffs,delta,deltaDelta] = mfcc(y,Fs);
            mfccs{i}{j} = [coeffs delta deltaDelta];
            %[coeffs] = mfcc(y,Fs);
            %mfccs{i}{j} = coeffs;
        end
    end
end
