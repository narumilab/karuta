% 指定ディレクトリ内のサブフォルダごとにWAVファイルを読み込み、MFCC特徴量を抽出する関数
% 戻り値:
% mfccs: {{MFCC行列}} の形式で返す

function [mfccs,fudas] = wav_to_mfcc(wav_dir, target_indices)
    % target_indices: 学習に使用したい番号の配列 (例: 1:40)
    
    entries = dir(wav_dir);
    isSubfolder = [entries.isdir] & ~ismember({entries.name}, {'.', '..'});
    subfolders = fullfile(wav_dir, {entries(isSubfolder).name});
    folderNames = cellfun(@(p) split(p, filesep), subfolders, 'UniformOutput', false);
    fudas = cellfun(@(parts) parts{end}, folderNames, 'UniformOutput', false);
    
    mfccs = cell(1, length(subfolders));
    
    for i = 1:length(subfolders)
        files = dir(fullfile(subfolders{i}, '*.wav'));
        temp_mfccs = {}; % 条件に合うものだけ入れる一時セル
        
        for j = 1:length(files)
            filename = files(j).name;
            
            % --- ファイル名から番号を抽出 ---
            % 例: "nageke50.wav" から "50" を取り出す
            tokens = regexp(filename, '(\d+)\.wav$', 'tokens');
            
            if ~isempty(tokens)
                file_num = str2double(tokens{1}{1});
                
                % 指定した番号リストに含まれているかチェック
                if ismember(file_num, target_indices)
                    [y, Fs] = audioread(fullfile(subfolders{i}, filename));
                    
                    % 特徴量抽出 (Delta, Delta-Delta 含む)
                    [coeffs, delta, deltaDelta] = mfcc(y, Fs);
                    temp_mfccs{end+1} = [coeffs, delta, deltaDelta]; 
                end
            end
        end
        mfccs{i} = temp_mfccs;
        fprintf('フォルダ [%s]: %d 個のファイルを学習用として読み込みました\n', fudas{i}, length(temp_mfccs));
    end
end