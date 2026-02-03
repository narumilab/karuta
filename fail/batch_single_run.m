% ===== 完全初期化 =====
clear; clc; close all;
audiodevreset;
rng('default');

% ★ このファイル自身のあるフォルダに移動
thisFile = mfilename('fullpath');
[thisDir,~,~] = fileparts(thisFile);
cd(thisDir);

% ★ ここで load
load('trial_config.mat');
pause(0.5);   % audioDeviceReader 安定待ち

Fs = 44100;
l_buf = 0.01;
bufLen = round(l_buf * Fs);

deviceReader = audioDeviceReader( ...
    'SampleRate', Fs, ...
    'SamplesPerFrame', bufLen);
pause(0.2);
cleanupObj = onCleanup(@() release(deviceReader));

% ===== 今回の試行番号を取得（環境変数）=====
trial_id = str2double(getenv('TRIAL_ID'));
folder_id = str2double(getenv('FOLDER_ID'));
file_id   = str2double(getenv('FILE_ID'));

folder = folders{folder_id};
wav_file = fullfile(base_path, folder, ...
    [folder num2str(file_id) '.wav']);

fprintf('[Trial %d] %s\n', trial_id, wav_file);

% ===== 実行 =====
try
    [idx, sec] = karuta_realtime_test(wav_file, deviceReader);
catch ME
    idx = 'ERROR';
    sec = NaN;
end

% ===== 結果保存（Excel追記）=====
rowName = sprintf('%s_trial%d', folder, trial_id);
colName = sprintf('data%d', file_id);

T = table({idx},{sprintf('%.3fs',sec)}, ...
    'VariableNames',{[colName '_idx'],[colName '_time']}, ...
    'RowNames',{rowName});

if isfile('Karuta_Results.xlsx')
    writetable(T,'Karuta_Results.xlsx', ...
        'WriteMode','append', ...
        'WriteRowNames',true);
else
    writetable(T,'Karuta_Results.xlsx', ...
        'WriteRowNames',true);
end

exit;
