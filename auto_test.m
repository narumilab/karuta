%% 決定版：auto_test.m（修正完了版）
%% 複数の音声ファイルに対してリアルタイムHMM認識を実行し、
%% 結果をExcelに保存するスクリプト

clear; clc;

% --- 設定 ---
original_script = 'realtime_delta_original_success.m'; 
base_path = 'C:\Lab\karuta\success\karuta_HMM_realtime\aihara'; 
save_base_path = 'C:\Lab\karuta\success\karuta_HMM_realtime\kimariji_soturon'; 
if ~exist(save_base_path, 'dir'), mkdir(save_base_path); end

folders = {'nageke','nageki', 'ooe', 'ooke', 'ooko', 'wasura', 'wasure', 'yamaga', 'yamaza'};
%folders = {'nageke'}; % テスト対象
num_files  = 5;
start_files = 46;
num_trials = 3;

% --- 初期化 ---
raw_lines = splitlines(fileread(original_script));
num_songs  = length(folders);
row_names = strings(num_songs * num_trials, 1);

% 常に1〜5番目としてテーブルを作成 (初期値は0)
T_col_names = strcat("data", string(1:num_files)); 
T_time = array2table(zeros(num_songs*num_trials, num_files), 'VariableNames', T_col_names);
T_recog = array2table(zeros(num_songs*num_trials, num_files), 'VariableNames', T_col_names);

% ===== ループ開始 =====
for f = 1:length(folders)
    folder_name = folders{f};    
    target_folder = fullfile(base_path, folder_name);
    if ~exist(target_folder, 'dir'), continue; end
    
    save_folder = fullfile(save_base_path, folder_name);
    if ~exist(save_folder, 'dir'), mkdir(save_folder); end
    
    for f_idx = start_files : start_files + num_files - 1
        % 相対的な列番号 (1〜5)
        current_col = f_idx - start_files + 1;
        
        wav_filename = sprintf('%s%d.wav', folder_name, f_idx);
        full_wav_path = fullfile(target_folder, wav_filename);
        if ~exist(full_wav_path, 'file'), continue; end
        
        for t = 1:num_trials
            row = (f-1)*num_trials + t;
            fprintf('\n🚀 実行: %s (試行 %d/%d)\n', wav_filename, t, num_trials);
            
            % --- 札名の代入 (最初の試行のみ) ---
            if t == 1, row_names(row) = folder_name; else, row_names(row) = ""; end

            % (temp_lines の作成・同期再生コード注入処理は現状を維持)
            % ... [中略：提示された temp_lines への注入処理をここに配置] ...
            temp_lines = raw_lines;
            temp_lines{1} = ['% ', temp_lines{1}];
            listen_idx = find(cellfun(@(x) contains(x, 'lock_counter = 0;'), temp_lines), 1);
            sync_play_code = {
                sprintf('[y_sync, fs_sync] = audioread(''%s'');', strrep(full_wav_path, '\', '/'));
                'sound(y_sync, fs_sync);'; 
                'tic;'; 
            };
            temp_lines = [temp_lines(1:listen_idx); sync_play_code; temp_lines(listen_idx+1:end)];
            write_idx = find(cellfun(@(x) contains(x, 'audiowrite(output_filename'), temp_lines));
            if ~isempty(write_idx)
                temp_lines{write_idx} = sprintf("audiowrite('%s', audioToSave, Fs);", strrep(fullfile(save_folder, sprintf('%s%d_trial%d_result.wav', folder_name, f_idx, t)), '\', '/'));
            end

            % ファイル保存
            fid = fopen('temp_runner.m', 'w', 'n', 'UTF-8');
            fprintf(fid, '%s\n', temp_lines{:});
            fclose(fid);

            try
                % ★ 実行前に結果変数をクリアして誤入力を防ぐ
                if exist('recog_timestamp_log','var'), clear recog_timestamp_log; end
                
                run('temp_runner.m'); 
                pause(1);

                % ★ 結果の代入 (シンプルに整理)
                if exist('recog_timestamp_log','var') && ~isempty(recog_timestamp_log)
                    T_time{row, current_col}  = recog_timestamp_log(1,2);
                    T_recog{row, current_col} = recog_timestamp_log(1,1);
                else
                    % 認識失敗時は0
                    T_time{row, current_col}  = 0;
                    T_recog{row, current_col} = 0;
                    warning('認識未確定につき0を代入');
                end
            catch ME
                T_time{row, current_col}  = 0;
                T_recog{row, current_col} = 0;
                fprintf('❌ 実行エラー: %s\n', ME.message);
            end
            clear sound; pause(2); 
        end
    end
end

% --- Excel保存処理 (ここが重要) ---
% 実際のファイル名に合わせて見出しを data6〜10 などに更新
actual_header = strcat("data", string(start_files : start_files + num_files - 1));
T_time.Properties.VariableNames = cellstr(actual_header);
T_recog.Properties.VariableNames = cellstr(actual_header);

% 札名を一番左の列に追加
T_time = addvars(T_time, row_names, 'Before', 1, 'NewVariableNames', '予測時間_本研究');
T_recog = addvars(T_recog, row_names, 'Before', 1, 'NewVariableNames', '予測札番号');

excel_file = fullfile(save_base_path, 'result_summary.xlsx');
writetable(T_time,  excel_file, 'Sheet', 'time');
writetable(T_recog, excel_file, 'Sheet', 'recog');
disp(['📊 保存完了: ', excel_file]);