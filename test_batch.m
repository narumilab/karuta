% Karuta Batch Test to Excel (完全初期化版)

base_path = './aihara_test'; 
%folders = {'nageke', 'nageki', 'ooe', 'ooke', 'ooko', 'wasura', 'wasure', 'yamaga', 'yamaza'};
folders = {'nageki', 'ooe', 'ooke', 'ooko', 'wasura', 'wasure', 'yamaga', 'yamaza'};
num_files  = 5;  % data1 ~ data5
num_trials = 3;  % 各ファイル3回試行

Fs    = 44100;
l_buf = 0.01;
bufLen = round(l_buf * Fs);

% 結果格納
result_indices = cell(length(folders)*num_trials, num_files);
result_times   = cell(length(folders)*num_trials, num_files);
row_names      = cell(length(folders)*num_trials, 1);

for f = 1:length(folders)
    folder_name = folders{f};

    for t = 1:num_trials
        current_row = (f-1)*num_trials + t;
        row_names{current_row} = sprintf('%s_trial%d', folder_name, t);

        for d = 1:num_files
            wav_file = fullfile(base_path, folder_name, ...
                               [folder_name, num2str(d), '.wav']);

            if exist(wav_file, 'file')
                fprintf('\n=== Testing: %s (Trial %d) ===\n', wav_file, t);

                % ===== 🔥 完全初期化ゾーン =====
                clear karuta_realtime_test   % persistent / ringbuffer 初期化
                pause(0.2);                  % MATLAB内部解放待ち

                deviceReader = audioDeviceReader( ...
                    'SampleRate', Fs, ...
                    'SamplesPerFrame', bufLen);

                cleanupObj = onCleanup(@() release(deviceReader));
                % =================================

                % 実行
                [idx, sec] = karuta_realtime_test(wav_file, deviceReader);

                result_indices{current_row, d} = idx;
                result_times{current_row, d}   = sprintf('%.3fs', sec);

                % ===== デバイス完全終了 =====
                clear cleanupObj;
                release(deviceReader);
                clear deviceReader;
                pause(0.5);  % OS側デバイス安定待ち

            else
                result_indices{current_row, d} = 'Missing';
                result_times{current_row, d}   = 'N/A';
            end
        end
    end
end

% Table変換
col_names = {'data1','data2','data3','data4','data5'};
T_idx  = cell2table(result_indices, 'VariableNames', col_names, 'RowNames', row_names);
T_time = cell2table(result_times,   'VariableNames', col_names, 'RowNames', row_names);

% Excel保存
writetable(T_idx,  'Karuta_Results.xlsx', 'Sheet', 'Recognized_Index', 'WriteRowNames', true);
writetable(T_time, 'Karuta_Results.xlsx', 'Sheet', 'Execution_Time',  'WriteRowNames', true);

disp('✅ 完全初期化状態でのExcel出力が完了しました');
