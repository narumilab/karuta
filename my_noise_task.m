% my_noise_task.m
% 複数の音声ファイルに対してノイズを加えた音声を生成し保存するスクリプト

% --- 設定 ---
base_input_dir = './aihara_test';
base_output_dir = './aihara_noise';
folder_names = {'nageke', 'nageki', 'ooe', 'ooke', 'ooko', 'wasura', 'wasure', 'yamaga', 'yamaza'};
noise_amp = 0.01; % ノイズの強さ

fprintf('=== 処理を開始します ===\n');

% 1. 各フォルダをループで処理
for i = 1:length(folder_names)
    current_folder = folder_names{i};
    
    % 入力・出力用の子フォルダパスを作成
    in_subfolder = fullfile(base_input_dir, current_folder);
    out_subfolder = fullfile(base_output_dir, current_folder);
    
    % 保存先フォルダがなければ作成
    if ~exist(out_subfolder, 'dir')
        mkdir(out_subfolder);
        fprintf('フォルダ作成: %s\n', out_subfolder);
    end
    
    % 2. 各フォルダ内の5つのファイルをループで処理
    for j = 1:5
        % ファイル名の組み立て (例: nageke1.wav)
        file_name = sprintf('%s%d.wav', current_folder, j);
        input_full_path = fullfile(in_subfolder, file_name);
        
        % 保存用ファイル名の組み立て (例: nageke1_noise.wav)
        output_file_name = sprintf('%s%d_noise.wav', current_folder, j);
        output_full_path = fullfile(out_subfolder, output_file_name);
        
        % ファイルが存在するか確認して処理
        if exist(input_full_path, 'file')
            % 音声読み込み
            [y, fs] = audioread(input_full_path);
            
            % ノイズ生成と合成
            noise = noise_amp * randn(size(y));
            y_noisy = max(min(y + noise, 1.0), -1.0); % クリッピング防止
            
            % 保存
            audiowrite(output_full_path, y_noisy, fs);
            fprintf('  [保存完了] %s\n', output_file_name);
        else
            fprintf('  [スキップ] 見つかりません: %s\n', input_full_path);
        end
    end
end

fprintf('=== すべての処理が完了しました ===\n');