clear;
% HMM関数 karuta_HMM_recog_realtime がパス上にあることを前提とします。
addpath('Lee_HMM'); 

% === ユーザー設定部分 ===
model_file = 'models_state30/iter10.mat'; % HMM学習済みモデル
Fs = 48000;
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
frameLen = round(n * Fs);       % 30 ms 
frame_shift_sec = n - m;        % 10 ms 
shift    = round(frame_shift_sec * Fs); % 10 ms 
bufLen   = round(l * Fs);       % 10 ms 

% === 入力デバイス設定 ===
deviceReader = audioDeviceReader('Device', 'ステレオ ミキサー (Realtek(R) Audio)', ...
    'SampleRate', Fs, ...
    'SamplesPerFrame', bufLen);
disp('Listening... (waiting for non-silent input)');

% --- リアルタイム処理バッファの初期化 ---
ringBuffer = [];
fullAudioBuffer = []; % ファイル保存のために全音声データを累積
started = false;
silenceThresh = 0.01; 
tic
while toc < 5 % 30秒間に延長
    audioRecorded = deviceReader(); % 音声を取得 (10ms分)
    
    % --- 無音検出 ---
    rmsVal = sqrt(mean(audioRecorded.^2));
    if ~started
        if rmsVal > silenceThresh
            started = true;
            disp("Sound detected! Starting MFCC processing...");
        else
            continue; % 無音なのでスキップ
        end
    end
    
    ringBuffer = [ringBuffer; audioRecorded]; 
    fullAudioBuffer = [fullAudioBuffer; audioRecorded]; % ファイル保存のため累積
    
    % --- MFCC処理 ---
    if length(ringBuffer) >= frameLen
        frame = ringBuffer(1:frameLen);
        [coeffs, delta, deltaDelta] = mfcc(frame, Fs);
        
        mfcc_matrix_current_block = [coeffs, delta, deltaDelta];
        
        % ⭐ 修正 1: HMMには最新の1フレームのみを渡す (次元数 x 1 に転置)
        mfcc_data = mfcc_matrix_current_block'; 
        
        % 累積フレーム数をカウント
        accumulated_frame_count = accumulated_frame_count + 1;
        
        fprintf("MFCC computed at %.3f sec. Total frames: %d\n", toc, accumulated_frame_count);
        
        ringBuffer(1:shift) = []; % 窓長 (30ms) からシフト量 (10ms) 分を削除

        % --- HMM認識処理 ---
        if ~recog_locked % 認識確定後の処理を避ける
            disp('--- 2. HMM認識の実行 ---');
            
            % ⭐ 修正 2: 状態変数を渡し、結果を受け取る (6引数 5戻り値) ⭐
            [recog_time_relative, recog_fuda_index, posterior_result, current_ll_matrix, current_filt] = ...
                karuta_HMM_recog_realtime(mfcc_data, model_file, threshold, w, before_ll, before_filt);
            % ⭐⭐⭐ 追加: 最新の事後確率を表示 ⭐⭐⭐
            disp('--- 最新の札別 潜在確率 (Posterior) ---');
            
            % posterior_result は num_fuda x 1 の行列であり、t=1 の結果を含む
            for k = 1:num_fuda
                % 確率をパーセンテージ形式で表示
                fprintf('  札 %d: %.6f\n', k, posterior_result(k, end) * 100); 
            end
            
            % ⭐ 修正 3: 状態変数を更新し、次のステップへ引き継ぐ ⭐
            % HMM関数は1フレームのみを処理するので、llの最終列とfilt全体が次の状態
            before_ll = current_ll_matrix(:, end) ;
            before_filt = current_filt;            

            % --- 結果表示 ---
            disp('--- 認識結果 ---');
            disp(['認識された札のインデックス: ', num2str(recog_fuda_index)]);
            % recog_time_relative は常に 1 (認識が確定した場合のみ)
            disp(['決まり字確定フレームインデックス (累積): ', num2str(accumulated_frame_count)]);
            
            % ⭐⭐⭐ 決まり字確定時の音声ファイル保存ロジック ⭐⭐⭐
            if recog_fuda_index > 0
                recog_locked = true; % 認識を確定 (重複実行防止)
                
                disp('*** 決まり字が確定しました！確定区間の音声をファイル保存します ***');
                
                % ⭐ 修正 4: 確定フレーム数は累積カウントを使用 ⭐
                total_recog_frame = accumulated_frame_count; 
                
                % 確定時点までの秒数を計算 (frame_shift_sec は 10ms)
                kimariji_second = frame_shift_sec * (total_recog_frame - 1) + n; 
                
                % 全体の音声バッファから、その秒数に対応するサンプル数を切り出す
                kimariji_samples = ceil(kimariji_second * Fs); 
                
                if kimariji_samples > length(fullAudioBuffer)
                    kimariji_samples = length(fullAudioBuffer);
                    disp('警告: 計算されたサンプル数が現在のバッファ長を超過したため、バッファ全体を保存します。');
                end
                
                audioToSave = fullAudioBuffer(1:kimariji_samples); 
                
                try
                    if ~exist(output_dir, 'dir')
                        mkdir(output_dir);
                    end
                    timestamp = datestr(now, 'yyyymmddHHMMSSFFF');
                    output_filename = fullfile(output_dir, ...
                        [output_base_name '_idx' num2str(recog_fuda_index) '_' timestamp '.wav']);
                    
                    audiowrite(output_filename, audioToSave, Fs); 
                    
                    disp(['ファイル保存が完了しました。保存先: ', output_filename]);
                    disp(['保存音声長: ', num2str(kimariji_second), ' 秒']);
                    
                catch ME_save
                    disp('ファイル保存エラーが発生しました。');
                    disp(['エラーメッセージ: ' ME_save.message]);
                end
                
               % ⭐⭐⭐ 認識確定に伴う状態リセット処理を追加する ⭐⭐⭐
                disp('*** 認識確定に伴い、すべての状態をリセットします ***');
                started = false;
                fullAudioBuffer = [];
                ringBuffer = [];
                before_ll = zeros(num_fuda, 1);
                before_filt = zeros(N, num_fuda);
                accumulated_frame_count = 0; 
                recog_locked = false; % ロックを解除
            end
        end
    end
end
release(deviceReader);
disp('処理終了');