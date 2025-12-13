clear;
% HMM関数 karuta_HMM_recog_realtime がパス上にあることを前提とします。
addpath('Lee_HMM'); 

% === ユーザー設定部分 ===
model_file = 'models_state30/iter10.mat'; % HMM学習済みモデル
input_wav_path = './aihara_test/nageke/nageke2.wav'; % オフライン入力
% 学習時の特徴抽出に合わせてサンプルレートを固定（学習データは44.1kHz）
Fs_target = 44100;
n = 0.03; % 窓長 (30 ms)
m = 0.02; % オーバーラップ (20 ms)
l = 0.01; % バッファ取得時間 (10 ms)
threshold = 0.9999;
w = 0.1;

% ⭐ ファイル保存設定 ⭐
output_dir = './kimariji_outputs';     
output_base_name = 'recog_kimariji'; 

% === HMM状態の初期化 ===
load(model_file, 'mean_vec_i_m');
num_fuda = size(mean_vec_i_m, 3); % 札数 (K)
N = size(mean_vec_i_m, 2);      % 状態数 (N)

% ⭐ HMMの状態管理変数を初期化 ⭐
before_ll = zeros(num_fuda, 1);       % 累積尤度 (K x 1)
before_filt = zeros(N, num_fuda);     % 前方確率 (N x K)
accumulated_frame_count = 0;          % 累積フレーム数
recog_locked = false;                 % 認識確定フラグ (重複実行防止用)

% === 変数の計算 ===
frameLen = round(n * Fs_target);       % 30 ms 
frame_shift_sec = n - m;        % 10 ms 
shift    = round(frame_shift_sec * Fs_target); % 10 ms 

% === リアルタイム入力 (マイク) ===
deviceReader = audioDeviceReader(...
    'SampleRate', Fs_target, ...
    'SamplesPerFrame', round(l * Fs_target)); % 10ms ごとに取得

% HMM認識に渡すための音声バッファ
audio_buffer_for_hmm = [];
% 認識確定後に保存するための全長バッファ
fullAudioBuffer = []; 

% HMM認識をトリガーするバッファ長 (秒)
buffer_trigger_duration = 0.5; % 500ms
buffer_trigger_samples = round(buffer_trigger_duration * Fs_target);

disp('リアルタイム認識を開始します。マイクに向かって話してください...');
tic;

while ~recog_locked
    % オーディオフレームを取得
    acquiredAudio = deviceReader();
    
    % バッファに追加
    audio_buffer_for_hmm = [audio_buffer_for_hmm; acquiredAudio];
    fullAudioBuffer = [fullAudioBuffer; acquiredAudio];
    
    % バッファがトリガーサイズに達したらHMM認識を実行
    if length(audio_buffer_for_hmm) >= buffer_trigger_samples
        disp('--- 特徴量を計算してHMM認識を実行 ---');
        
        % --- 特徴抽出 ---
        [coeffs, delta, deltaDelta] = mfcc(audio_buffer_for_hmm, Fs_target);
        mfcc_matrix = [coeffs, delta, deltaDelta];
        mfcc_data = mfcc_matrix';
        fprintf('  - MFCC matrix size: %d x %d\n', size(mfcc_matrix, 1), size(mfcc_matrix, 2));

        % --- HMM認識処理 ---
        % 前回の状態を引き継いで実行
        [~, recog_fuda_index, posterior_result, current_ll_matrix, current_filt] = ...
            karuta_HMM_recog_realtime(mfcc_data, model_file, threshold, w, before_ll, before_filt);
        
        % 状態を次のループのために更新
        before_ll = current_ll_matrix(:, end);
        before_filt = current_filt;
        
        % 認識結果の表示
        [max_posterior, latest_recog_idx] = max(posterior_result(:, end));
        fprintf('  - Latest recognition index: %d (Posterior: %.4f)\n', latest_recog_idx, max_posterior);
        
        if recog_fuda_index > 0
            recog_locked = true; % 認識を確定
            disp(['認識された札のインデックス: ', num2str(recog_fuda_index)]);
            
        else
            % 認識が確定しなかった場合、バッファの先頭部分を少し削除して
            % 次のフレームで新しい音声が追加されるようにする (スライディングウィンドウ)
            slide_amount_sec = 0.1; % 100ms
            slide_amount_samples = round(slide_amount_sec * Fs_target);
            
            if length(audio_buffer_for_hmm) > slide_amount_samples
                audio_buffer_for_hmm = audio_buffer_for_hmm(slide_amount_samples+1:end);
            else
                audio_buffer_for_hmm = []; % バッファがスライド量より小さい場合はクリア
            end
        end
    end
    
    % タイムアウト処理 (例: 30秒)
    if toc > 30
        disp('タイムアウトしました。');
        break;
    end
end

release(deviceReader); % デバイスを解放
disp('リアルタイム認識を終了します。');

% === 認識確定後のファイル保存処理 ===
if recog_fuda_index > 0 && recog_locked
    disp('*** 決まり字が確定しました！確定区間の音声をファイル保存します ***');
    
    % 簡単化のため、認識確定までの全音声を保存する
    audioToSave = fullAudioBuffer;
    kimariji_second = length(audioToSave) / Fs_target;
    
    try
        if ~exist(output_dir, 'dir')
            mkdir(output_dir);
        end
        timestamp = datestr(now, 'yyyymmddHHMMSSFFF');
        output_filename = fullfile(output_dir, ...
            [output_base_name '_idx' num2str(recog_fuda_index) '_' timestamp '.wav']);
        
        audiowrite(output_filename, audioToSave, Fs_target);
        
        disp(['ファイル保存が完了しました。保存先: ', output_filename]);
        disp(['保存音声長: ', num2str(kimariji_second), ' 秒']);
        
    catch ME_save
        disp('ファイル保存エラーが発生しました。');
        disp(['エラーメッセージ: ' ME_save.message]);
    end
end