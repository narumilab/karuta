clear;
% HMM関数 karuta_HMM_recog_realtime がパス上にあることを前提とします。
addpath('Lee_HMM'); 
% === ユーザー設定部分 ===
model_file = 'models_state30/iter10.mat'; % HMM学習済みモデル 

input_wav_path = './aihara_test/ooke/ooke2.wav'; 
%[y, Fs] = audioread(input_wav_path);
%Fs = 48000;
Fs = 44100;
n = 0.03; % 窓長 (30 ms)
m = 0.02; % オーバーラップ (20 ms)
l_buf = 0.01; % バッファ取得時間 (10 ms)
threshold = 0.9999;
w = 0.1;
% ⭐ ファイル保存設定 ⭐
output_dir = './kimariji_outputs';     
output_base_name = 'recog_kimariji'; 
% === HMM状態の初期化 ===
load(model_file, 'mean_vec_i_m', 'var_vec_i_m', 'a_i_j_m');
num_fuda = size(mean_vec_i_m, 3); % 札数 (K)
N = size(mean_vec_i_m, 2) ;   % 状態数 (N)
% ⭐ HMMの状態管理変数を初期化 ⭐
ll = zeros(num_fuda, 1);       % 累積尤度 (K x 1)
posterior = zeros(num_fuda,1);
filt = zeros(N, num_fuda); 
%filt(1, :) = 1.0;
filt(1:N, :) = 1/N;
accumulated_frame_count = 0;% 累積フレーム数
frame_count = 0;          
accumulated_frame = 0; 
% ⭐ 追加: MFCCフレームの累積インデックス (30msフレーム単位)
mfcc_frame_index = 0; 

% ⭐ 札のインデックスを初期化 ⭐
recog_time = inf;
recog_fuda = 0;
fuda = 0;
% ⭐ 追加 3: 認識された札の確定インデックスの記録用リスト ⭐
recog_sequence_log = []; 
recog_timestamp_log = [];  % 確定時刻を記録するリスト

shift_fix = 0;
shift_error = 0;
shift_error = 0;

% === HMM状態の初期化 ===


% ⭐ 変更 1: recog_locked フラグは不要になるか、処理を制御するために残す ⭐
recog_locked = false; % ファイル保存の重複防止用として維持

% === 変数の計算 ===
x=3;
%frameLen = round(n * x * Fs);       % 30 ms 
frameLen = round(0.19* Fs); 
shift_check = round(m * Fs);
frame_shift_sec = n - m;        % 10 ms 
shift    = round(frame_shift_sec * Fs); % 10 ms 
bufLen   = round(l_buf * Fs);       % 10 ms 

% === 入力デバイス設定 ===
deviceReader = audioDeviceReader('Device', 'ステレオ ミキサー (Realtek(R) Audio)', ...
    'SampleRate', Fs, ...
    'SamplesPerFrame', bufLen);
disp('Listening... (waiting for non-silent input)')



% ⭐=== カウントダウンと音声再生ロジックの追加 ===⭐
%try
    %[y_play, Fs_play] = audioread(input_wav_path);
    % 振幅を正規化し、音が大きすぎないように調整 (0.8倍)
    %y_play = y_play / max(abs(y_play)) * 0.8;
    %if ~isempty(y_play)
    %y_play = y_play / max(abs(y_play)); 
    %end 
    
    %disp('--- 自動テスト開始 ---');
    %disp('3秒後にPCから音声を再生し、同時にマイクで聞き取ります...');
    %pause(1); disp('2...');
    %pause(1); disp('1...');
    
    % ⭐ 音声再生開始 ⭐
    %disp('>>> NOW PLAYING AUDIO >>>');
    %sound(y_play, Fs_play); 
    %played_flag = true; % 再生フラグを設定 (このコードでは不要ですが、最初の例に合わせて追加)
    
%catch ME_audio
    %disp(['⚠️ 警告: 音声ファイルの読み込みまたは再生に失敗しました。', ME_audio.message]);
    %played_flag = false;
%end
% ⭐==========================================⭐


% --- リアルタイム処理バッファの初期化 ---
ringBuffer = [];
fullAudioBuffer = []; % ファイル保存のために全音声データを累積
fullmfcc = [];
full_current_power =[];
started = false;
audio_started = false;
%silenceThresh = 0.0007; 
%silenceThresh = 0.0001470000014;
%silenceThresh = -9.5;  
%silenceThresh = y_play(1)
%silenceThresh = 0.02; 

input_gain = 2.0;       % 2.0倍に増幅（必要に応じて 5.0 や 10.0 に調整）
silenceThresh = 0.05;   % 増幅後の音量に合わせた無音閾値（コード2の設定を参考）

power_over=0;
power=[];


% ⭐ 追加 1: オーバーラン情報を記録するリストを初期化 ⭐
% [フレーム番号, 時刻 (s), 欠落サンプル数] を格納
overrun_log = {};

lock_counter = 0;
mfcc_count=0;

tic
while toc < 5 % 時間を30秒間に延長 (認識が継続するため)
 
    [audioRecorded, numOverrun] = deviceReader(); % 音声を取得 (10ms分)
    audioRecorded = audioRecorded * input_gain;
    if numOverrun > 0

        fprintf('⚠️ 警告: フレーム %d (%.3f秒) で**オーバーラン**が発生しました。欠落サンプル数: %d\n', ...
            accumulated_frame_count + 1, toc, numOverrun);
        % 2. ここで overrun_log にデータを追加する
        overrun_log{end+1} = [accumulated_frame_count + 1, toc, numOverrun];
    end
    
    % --- モノラル化の追加（もし入力がステレオの場合の安全策） ---
    if size(audioRecorded, 2) > 1
        audioRecorded = mean(audioRecorded, 2);
    end
    
    % ⭐ 変更：バッファは「常に」更新し続ける (started の判定前に行う)
    ringBuffer = [ringBuffer; audioRecorded];
    if length(ringBuffer) > frameLen
        ringBuffer(1 : length(ringBuffer)-frameLen) = [];
    end

    % --- 無音検出 ---
    rmsVal = sqrt(mean(audioRecorded.^2));
    if ~started
        if rmsVal > silenceThresh
            started = true;
            disp("🎵 Sound detected! Analyzing with pre-roll buffer...");
        else
            % started でない間は、フルバッファへの追加や解析はスキップ
            continue; 
        end
    end
    

    
    
 
    

    if started
        accumulated_frame_count = accumulated_frame_count + 1;
        fullAudioBuffer = [fullAudioBuffer; audioRecorded];
        frame_count = frame_count + 1;
        start_recog = toc;
       
        if length(ringBuffer) > frameLen
            ringBuffer(1 : length(ringBuffer)-frameLen) = [];
        end
        
        
            
            
        if length(ringBuffer) >= frameLen;
            % --- MFCC処理 ---
            g = length(ringBuffer);
            frame = ringBuffer(1:frameLen);
            a=length(ringBuffer);
            c=length(frame);
            [coeffs, delta, deltaDelta] = mfcc(frame, Fs);
            mfcc_matrix_current = [coeffs, delta, deltaDelta];
     
        
            % ファイル保存のため累積
            
            latest_index = size(mfcc_matrix_current, 1);
            %if mfcc_count==0
                %mfcc_count = mfcc_count + 1; % Increment the MFCC count
                %mfcc_matrix_current_block = mfcc_matrix_current(1:latest_index,:);
            %else
            %mfcc_count = mfcc_count + 1;
            %mfcc_matrix_current_block = mfcc_matrix_current(latest_index,:);
            %end
            mfcc_matrix_current_block = mfcc_matrix_current(latest_index,:);
            fullmfcc = [fullmfcc;mfcc_matrix_current_block];
            % ⭐ 修正 1: HMMには最新の1フレームのみを渡す (次元数 x 1 に転置)
            mfcc_data = mfcc_matrix_current_block'; 
            
         
            % --- HMM認識処理 ---
            %disp('--- 2. HMM認識の実行 ---');
    
            p=size(mfcc_data,2);
            for s=1:size(mfcc_data,2);
                
                for k=1:num_fuda;
                   
                    l = 0;
                    pred = filt(:,k)'*a_i_j_m(:,:,k);
                    for i=2:N-1 
                        emission_prob = exp(logDiagGaussian(mfcc_data(:,s),mean_vec_i_m(:,i,k),var_vec_i_m(:,i,k)));
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
                    lock_counter = lock_counter + 1; 
                else, 
                    lock_counter = 0; 
                end

                if lock_counter >= 3 % consecutive_limit は 3 に設定
                    recog_locked = true;
                    total_sec = toc - start_recog; 
    % ここで初めて「確定」とみなし、出力を表示
                
                    [~,recog_fuda] = max(posterior);
                    break
                end
                  
                   
                % ⭐⭐⭐ 最新の事後確率を表示 ⭐⭐⭐
                %disp('--- 最新の札別 潜在確率 (Posterior) ---');
                %if max(posterior) > 0.1
                    %stars = repmat('★', 1, lock_counter);
                    %max_p = max(posterior);
                    %[max_val, max_idx] = max(posterior);
                    %fprintf('  候補: 札%d (%.2f%%) %s\n', max_idx, max_p*100, stars);
                %end
                %for k = 1:num_fuda
                    %fprintf('  札 %d: %.6f\n', k, posterior_result(k, end) * 100); 
                    %fprintf('  札 %d: %.6f\n', k, posterior(k) * 100); 
                %end
            end
            % ⭐ 変更 3: 状態変数を更新し、次のステップへ引き継ぐ (リセットはしない) ⭐
            %before_ll = current_ll_matrix(:, end) ;
            %before_filt = current_filt;            
            
            % --- 結果表示 ---
            %disp('--- 認識結果 ---');
            %disp(['認識された札のインデックス: ', num2str(recog_fuda)]);
            %disp(['決まり字確定フレームインデックス (累積): ', num2str(frame_count)]);
            
            % ⭐⭐⭐ 決まり字確定時の音声ファイル保存ロジック ⭐⭐⭐
            % 変更 4: recog_locked フラグでファイル保存を一度だけ行う制御に変更
            if recog_fuda ~= fuda 
                
                %total_sec = end_recog - start_recog; 
                fprintf("決まり字が確定しました！ %.3f sec. Total frames: %d\n", total_sec, frame_count);
                fuda = recog_fuda;
                % ⭐ 追加 4: 確定した札のインデックスを記録 ⭐
                recog_sequence_log = [recog_sequence_log, recog_fuda];
                disp('*** 決まり字が確定しました！確定区間の音声をファイル保存します (状態は継続) ***');
                % --- 修正箇所：if recog_fuda ~= fuda のブロック内 ---

    
    
    


                % ⭐ 修正 4: 確定フレーム数は累積カウントを使用 ⭐
                total_recog_frame = frame_count;
                
                % 確定時点までの秒数を計算 (frame_shift_sec は 10ms)
                kimariji_second = 0.01 * (total_recog_frame - 1) + 0.03; 

                % ⭐ 追加：時刻と札番号をペアで記録
                recog_timestamp_log = [recog_timestamp_log; recog_fuda, kimariji_second];
                
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
                
                % *** HMM状態リセット処理はここには追加しません ***
            end
            
            % ⭐ 追加: ファイル保存後も、HMMの状態は before_ll と before_filt を介して次のループに引き継がれる
        
            %ringBuffer(1:shift) = []; % シフト量 (20ms) 分をのこす
            %b = length(ringBuffer);
            %if length(ringBuffer) > g-(Fs*0.01)
                %shift_fix = shift_fix + 1;
                %shift_change = shift-(g-b);
                %ringBuffer = ringBuffer(shift_change + 1 : end);
                
            %end
            %if length(ringBuffer) < g-(Fs*0.01)
                %disp('欠落しました');
                %shift_error = shift_error + 1;

            %end
            
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

    fprintf('%-10s | %-15s\n', '札番号', '確定時刻 (秒)');
    disp('-----------|--------------------------------------');
    for i = 1:size(recog_timestamp_log, 1)
        fuda_idx = recog_timestamp_log(i, 1);
        fuda_time = recog_timestamp_log(i, 2);
        fprintf('札 %-7d | %-15.3f\n', fuda_idx, fuda_time);
    end
end


fprintf('バッファサイズを　%d 回調節しました。\n', shift_fix);

fprintf('バッファサイズが　%d 回足りませんでした。\n', shift_error);

% ========================================
% ⭐ 追加 2: オーバーラン情報の最終出力 ⭐
% ========================================
disp('---');
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


%try
    % 音声データのサンプリング周波数とデータ長を取得
    %TotalSamples = length(fullAudioBuffer);
    %TimeDuration = TotalSamples / Fs;
    
    % 時間ベクトルを作成
    %time_vector = (0:TotalSamples-1) / Fs;
    
    %figure;
    %plot(time_vector, fullAudioBuffer);
    %title('全入力音声波形');
    %xlabel('時間 (秒)');
    %ylabel('振幅');
    %grid on;
    %disp(['プロットが完了しました。音声総時間: ', num2str(TimeDuration, '%.3f'), ' 秒']);
%catch ME_plot
    %disp(['波形プロット中にエラーが発生しました: ', ME_plot.message]);
%end