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
load(model_file, 'mean_vec_i_m', 'var_vec_i_m', 'a_i_j_m');
num_fuda = size(mean_vec_i_m, 3); % 札数 (K)
N = size(mean_vec_i_m, 2);      % 状態数 (N)
% ⭐ HMMの状態管理変数を初期化 ⭐
ll = zeros(num_fuda, 1);       % 累積尤度 (K x 1)
posterior = zeros(num_fuda,1);
filt = zeros(N, num_fuda); 
filt(1, :) = 1.0;
accumulated_frame_count = 0;          % 累積フレーム数
% ⭐ 札のインデックスを初期化 ⭐
recog_time = inf;
recog_fuda = 0;
fuda = 0;

% ⭐ 追加 3: 認識された札の確定インデックスの記録用リスト ⭐
recog_sequence_log = []; 
% ⭐ 変更 1: recog_locked フラグは不要になるか、処理を制御するために残す ⭐
recog_locked = false;                 % ファイル保存の重複防止用として維持
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

% ========================================
% ⭐ 追加 1: オーバーラン情報を記録するリストを初期化 ⭐
% [フレーム番号, 時刻 (s), 欠落サンプル数] を格納
overrun_log = {}; 
% ========================================

tic
while toc < 5 % 時間を30秒間に延長 (認識が継続するため)
    % 音声を取得 (10ms分)
    [audioRecorded, numOverrun] = deviceReader(); 
    
    % ========================================
    % ⭐ 変更 1: オーバーランの警告表示とログへの記録 ⭐
    current_frame_index = accumulated_frame_count + 1;
    current_time = toc;
    
    if numOverrun > 0
        fprintf('⚠️ 警告: フレーム %d (%.3f秒) で**オーバーラン**が発生しました。欠落サンプル数: %d\n', ...
            current_frame_index, current_time, numOverrun);
        % ログに情報を追加
        overrun_log{end+1} = [current_frame_index, current_time, numOverrun];
    end
    % ========================================
    
    
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
        disp('--- 2. HMM認識の実行 ---');
        
        for k=1:num_fuda
           
            l = 0;
            pred = filt(:,k)'*a_i_j_m(:,:,k);
            for i=2:N-1 
                emission_prob = exp(logDiagGaussian(mfcc_data,mean_vec_i_m(:,i,k),var_vec_i_m(:,i,k)));
                l = l + pred(i) * emission_prob;
                filt(i,k) = pred(i) * emission_prob;
            end
            ll(k) = ll(k)+log(l);
            filt(:,k) = filt(:,k)/sum(filt(:,k));
        end
        posterior = exp(w*(ll-max(ll)));
        posterior = posterior/sum(posterior);
        
        if max(posterior) > threshold
            %recog_time = t;
            [~,recog_fuda] = max(posterior);
        end
           
        % ⭐⭐⭐ 最新の事後確率を表示 ⭐⭐⭐
        disp('--- 最新の札別 潜在確率 (Posterior) ---');
        for k = 1:num_fuda
            fprintf('  札 %d: %.6f\n', k, posterior(k) * 100); 
        end
        
        % --- 結果表示 ---
        disp('--- 認識結果 ---');
        disp(['認識された札のインデックス: ', num2str(recog_fuda)]);
        disp(['決まり字確定フレームインデックス (累積): ', num2str(accumulated_frame_count)]);
        
        % ⭐⭐⭐ 決まり字確定時の音声ファイル保存ロジック ⭐⭐⭐
        % 変更 4: recog_locked フラグでファイル保存を一度だけ行う制御に変更
        if recog_fuda ~= fuda  
            fuda = recog_fuda;

            % ⭐ 追加 4: 確定した札のインデックスを記録 ⭐
            recog_sequence_log = [recog_sequence_log, recog_fuda];
            disp('*** 決まり字が確定しました！確定区間の音声をファイル保存します (状態は継続) ***');
            
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
                    [output_base_name '_idx' num2str(recog_fuda) '_' timestamp '.wav']);
                
                audiowrite(output_filename, audioToSave, Fs); 
                
                disp(['ファイル保存が完了しました。保存先: ', output_filename]);
                disp(['保存音声長: ', num2str(kimariji_second), ' 秒']);
                
            catch ME_save
                disp('ファイル保存エラーが発生しました。');
                disp(['エラーメッセージ: ' ME_save.message]);
            end
        end
    end
end
release(deviceReader);
disp('処理終了');



% ========================================
% ⭐ 追加 5: 決まり字シーケンスの最終出力 ⭐
% ========================================
disp('---');
disp('📜 **決まり字 最終認識シーケンス** 📜');
if isempty(recog_sequence_log)
    disp('認識された札はありませんでした。');
else
    % 記録されたインデックスの推移 (重複を含む)
    fprintf('Raw Sequence (重複あり): %s\n', num2str(recog_sequence_log));

    % 重複を排除し、推移の順序を保持 (MATLAB 2017a以降で利用可能)
    unique_sequence = unique(recog_sequence_log, 'stable'); 
    
    % シーケンスを '→' でつなぐ文字列を作成
    output_str = join(string(unique_sequence), ' → ');
    
    disp('**ユニークな決まり字の推移 (順番維持):**');
    disp(output_str{1});
end

% ========================================
% ⭐ 追加 2: オーバーラン情報の最終出力 ⭐
% ========================================
if isempty(overrun_log)
    disp('✅ 最終結果: 処理時間中に**オーバーランは一度も発生しませんでした**。');
else
    disp('🚨🚨🚨 最終結果: 処理時間中に**オーバーランが発生した全フレーム** 🚨🚨🚨');
    disp('------------------------------------------------------------------');
    fprintf('%-10s | %-12s | %s\n', 'フレーム #', '時刻 (秒)', '欠落サンプル数');
    disp('------------------------------------------------------------------');
    
    % セル配列の内容を整形して表示
    for i = 1:length(overrun_log)
        frame_num = overrun_log{i}(1);
        time_sec = overrun_log{i}(2);
        dropped_samples = overrun_log{i}(3);
        fprintf('%-10d | %-12.3f | %d\n', frame_num, time_sec, dropped_samples);
    end
    disp('------------------------------------------------------------------');
end



