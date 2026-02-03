% karuta_HMM_recog_test.m
% 複数の音声ファイルに対してHMM認識を実行し、認識率と決まり字確定時間をExcelに保存するスクリプト

addpath('Lee_HMM');
% [mfccs_train,fudas_train] = wav_to_mfcc('./aihara_train');
% karuta_HMM_train(mfccs_train,30,10);

% --- 設定 ---
test_numbers = [6:10]; % ファイル番号 (data11〜data15)
num_files = length(test_numbers);
num_trials = 3;         % 3回ずつ試行
model_path = 'models_state30/iter10.mat';
output_filename = 'Recognition_Results.xlsx';
% テストデータの読み込み
[mfccs_test, fudas_test] = wav_to_mfcc_cross('./aihara', test_numbers);
nfuda = length(mfccs_test);

% --- テーブル初期化 ---
% 1列目は札名、2〜6列目はデータ(0で初期化)
T_col_names = strcat("data", string(1:num_files));
T_rate = array2table(zeros(nfuda * num_trials, num_files), 'VariableNames', T_col_names);
T_time = array2table(zeros(nfuda * num_trials, num_files), 'VariableNames', T_col_names);

row_names = strings(nfuda * num_trials, 1);

% --- メインループ ---
for i = 1:nfuda
    fuda_name = fudas_test{i};
    nmfcc = length(mfccs_test{i}); % 読み込まれたwavファイル数
    
    for j = 1:nmfcc
        % 現在のファイルが何列目か (相対位置)
        current_col = j; 
        
        for t = 1:num_trials
            % 行番号の計算
            row = (i-1)*num_trials + t;
            if t == 1, row_names(row) = fuda_name; else, row_names(row) = ""; end
            
            % --- 1. 認識処理 ---
            [r_time, r_fuda, post] = karuta_HMM_recog(mfccs_test{i}{j}, model_path, 0.9999, 0.1);
            
            % --- 2. 認識成否(1 or 0)の格納 ---
            if r_fuda == i
                T_rate{row, current_col} = 1; % 正解
            else
                T_rate{row, current_col} = 0; % 不正解
            end
            
            % --- 3. 予測時間(決まり字)の取得と格納 ---
            [y, Fs, k_sec] = kimariji('./aihara_test', fuda_name, j, r_time);
            T_time{row, current_col} = k_sec;
            
            % 音声保存（必要に応じて）
            save_path = sprintf('./aihara_test_kimariji/%s/', fuda_name);
            if ~exist(save_path, 'dir'), mkdir(save_path); end
            audiowrite(sprintf('%s%s%d_trial%d_kimariji.wav', save_path, fuda_name, j, t), y, Fs);
        end
    end
    disp(['処理完了: ', fuda_name]);
end

% --- 1. 札ごとの平均認識率を計算 ---
% 札ごとに「全ファイル×全試行」の正解(1)の平均をとる
fuda_summary = strings(nfuda, 1);
fuda_avg_rate = zeros(nfuda, 1);

for i = 1:nfuda
    % その札に該当する行のインデックスを取得
    start_row = (i-1)*num_trials + 1;
    end_row   = i*num_trials;
    
    % その札の全データ(1~5列目)を抽出して平均を出す
    current_fuda_data = T_rate{start_row:end_row, :};
    fuda_avg_rate(i) = mean(current_fuda_data(:)) * 100; % 百分率
    fuda_summary(i)  = fudas_test{i};
end

% 2. 札ごとの認識率テーブルを作成
T_summary = table(fuda_summary, fuda_avg_rate, 'VariableNames', {'札名', '認識率_百分率'});

% --- 3. 既存テーブルの整形（札名の挿入とヘッダー更新） ---
actual_header = strcat("data", string(test_numbers));

% 試行ごとのテーブルに札名を追加
T_rate_final = addvars(T_rate, row_names, 'Before', 1, 'NewVariableNames', '札名');
T_time_final = addvars(T_time, row_names, 'Before', 1, 'NewVariableNames', '札名');

% ヘッダー書き換え（2列目以降）
T_rate_final.Properties.VariableNames(2:end) = cellstr(actual_header);
T_time_final.Properties.VariableNames(2:end) = cellstr(actual_header);

% --- 4. 保存 ---
writetable(T_summary,    output_filename, 'Sheet', 'Fuda_Summary'); % ← ここが各札ごとの認識率
writetable(T_rate_final, output_filename, 'Sheet', 'Trial_Recognition');
writetable(T_time_final, output_filename, 'Sheet', 'Trial_Time');

disp(['📊 結果を ', output_filename, ' に保存しました。']);