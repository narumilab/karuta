clear;
% HMM関数 karuta_HMM_recog_realtime がパス上にあることを前提とします。
addpath('Lee_HMM'); 
% === ユーザー設定部分 ===
model_file = 'models_state30/iter10.mat'; % HMM学習済みモデル 

input_wav_path = './aihara_test/wasura/wasura1.wav';
[y, Fs] = audioread(input_wav_path);
%Fs = 44100;
%Fs = 48000;
n = 0.03; % 窓長 (30 ms)
m = 0.02; % オーバーラップ (20 ms)
l = 0.01; % バッファ取得時間 (10 ms)
threshold = 0.8;
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

shift_fix = 0;
shift_error = 0;

% === HMM状態の初期化 ===


% ⭐ 変更 1: recog_locked フラグは不要になるか、処理を制御するために残す ⭐
recog_locked = false;                 % ファイル保存の重複防止用として維持

% === 変数の計算 ===
x=1;
frameLen = round(n * x * Fs);       % 30 ms 
shift_check = round(m * Fs);
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
fullAudioBuffer = [];
fullAudioBuffer_alignment = [];% ファイル保存のために全音声データを累積
fullmfcc = [];
started = false;
%silenceThresh = 0.0001; 
silenceThresh = 0.0001470000014;
%silenceThresh = 0.0001;

% ⭐ 追加 1: オーバーラン情報を記録するリストを初期化 ⭐
% [フレーム番号, 時刻 (s), 欠落サンプル数] を格納
overrun_log = {};
% ⭐⭐ アライメント設定部分の追加 ⭐⭐
alignment_duration_sec = 0.2; % アライメントに使用する音声の長さ
alignment_samples = round(alignment_duration_sec * Fs); % サンプル数
alignment_done = false; % アライメントが完了したかを示すフラグ
alignment_buffer = []; % リアルタイム音声収集用
initial_shift = 0; % 相互相関で求めたずれ (サンプル数)

% WAVファイルの初期データを抽出
wav_data_for_alignment = y(1:min(end, alignment_samples)); 
% ⭐⭐ アライメント設定部分の追加ここまで ⭐⭐
tic
while toc < 5 % 時間を30秒間に延長 (認識が継続するため)

    % ---- パディングが無い時だけ deviceReader を呼ぶ ----
    [audioRecorded, numOverrun] = deviceReader();


    if numOverrun > 0
        fprintf('⚠️ 警告: フレーム %d (%.3f秒) で**オーバーラン**が発生しました。欠落サンプル数: %d\n', ...
            accumulated_frame_count + 1, toc, numOverrun);
    end
    
    
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
    % ⭐⭐ 統合: アライメント処理ブロック (札判定用音声の開始位置修正) ⭐⭐
    if started && ~alignment_done
        % リアルタイム音声の収集
        alignment_buffer = [alignment_buffer; audioRecorded];
        
        if length(alignment_buffer) >= alignment_samples
            disp('--- 1. 音声アライメントの実行 (相互相関) ---');
            
            input_data_for_alignment = alignment_buffer(1:alignment_samples);
            
            % 相互相関の計算: lag_sample > 0 ならWAVが先行 (リアルタイム入力が遅延)
            [c,lags] = xcorr(wav_data_for_alignment, input_data_for_alignment);
            [~,I] = max(c)
            [~, I] = max(c);
            if I>1 && I<length(c)
                alpha = c(I-1); beta = c(I); gamma = c(I+1);
                lag_corr = 0.5 * (alpha - gamma) / (alpha - 2*beta + gamma);
                lag_sample = lags(I) + lag_corr; % サブサンプル精度
            else
                lag_sample = lags(I);
            end

            %lag_sample = lags(I)
            initial_shift = lag_sample;  % これを追加
            % ... (サブサンプル精度を持つ lag_sample の計算が完了) ...
            
            initial_shift = lag_sample;  % サブサンプル精度のまま保持
            
            % 補正処理には整数に丸めた値を使用
            %integer_shift = round(initial_shift); 
            if initial_shift > 0 
                % WAVが先行（リアルタイムが遅延）。削る量を確保するため、切り上げ（ceil）または四捨五入（round）
                % 削りすぎを防ぐため、ここでは round を維持
                integer_shift = round(initial_shift); 
            elseif initial_shift < 0
                % リアルタイムが先行。パディング量を確保するため、絶対値に対して切り上げ（ceil）
                integer_shift = ceil(abs(initial_shift)) * sign(initial_shift); % absを取りceilし、元の符号をかける
                
                % もしくはシンプルに：
                % integer_shift = floor(initial_shift);
                
                % ★最も安全なのは、統一して round を使うことです。
                integer_shift = round(initial_shift);
            end
            fprintf('相互相関で推定された時間ずれ: %.3f サンプル (%.3f ミリ秒) -> 補正量: %d サンプル\n', ...
                lag_sample, lag_sample / Fs * 1000, integer_shift);
            
            % --- リアルタイム入力バッファの補正 ---
            if integer_shift > 0 
                % WAVが先行（リアルタイムが遅延）の場合 → 切り捨てとゼロパディング
                
                shift_len = integer_shift; % 整数値
                shift_len = min(shift_len, length(alignment_buffer));
                
                % 削られた後のデータ
                trimmed_audio = alignment_buffer(shift_len + 1 : end);
                
                pad_len = shift_len;
                zero_padding = zeros(pad_len, 1);
                
                % ringBuffer と fullAudioBuffer_alignment に同じ補正済みデータ（[ゼロパディング; 削った後のデータ]）を設定する
                ringBuffer = [zero_padding; trimmed_audio];
                fullAudioBuffer_alignment = [zero_padding; trimmed_audio];
                
                fprintf('アライメント実行: 遅延 %d サンプルを削り、同量のゼロパディングで時間軸補正。\n', pad_len);
            
            elseif integer_shift < 0
                % リアルタイムが先行の場合 → ゼロパディング
                pad_len = abs(integer_shift);
                zero_padding = zeros(pad_len, 1);
            
                ringBuffer = [zero_padding; alignment_buffer];
                fullAudioBuffer_alignment = [zero_padding; alignment_buffer];
            
                fprintf('アライメント実行: 先行 %d サンプルをゼロパディングで補正。\n', pad_len);
            
            
     
            else
                ringBuffer = alignment_buffer;
                fullAudioBuffer_alignment = alignment_buffer;
                disp('アライメント完了: 時間ずれは無視できるレベルです。');
            end
            
            alignment_done = true;
            disp('アライメント完了。札判定用音声の開始位置はWAVに揃えられました。');
            
            % ⭐⭐ ringBuffer の短縮処理はそのまま維持 ⭐⭐
            if length(ringBuffer) >= shift_check
                ringBuffer = ringBuffer(end - shift_check + 1 : end); 
            end
        end
        % アライメント収集中は HMM/MFCC 処理をスキップ
        continue;
    end
    % ⭐⭐ 統合: アライメント処理ブロックここまで ⭐⭐
    % --- 修正: アライメント完了後のデータ追記とMFCC実行 ---
    if started && alignment_done
        
        % アライメント完了後のみ、新しい音声データを追加
        ringBuffer = [ringBuffer; audioRecorded]; 
        fullAudioBuffer = [fullAudioBuffer; audioRecorded]; % (任意)
        fullAudioBuffer_alignment = [fullAudioBuffer_alignment; audioRecorded]; % ⭐ ズレ補正済みのデータに追記
        g = length(ringBuffer);
    
    
         % --- MFCC処理 ---
       
        if length(ringBuffer) >= frameLen
            
            frame = ringBuffer(1:frameLen);
            a=length(ringBuffer);
            c=length(frame);
            [coeffs, delta, deltaDelta] = mfcc(frame, Fs);
            
            mfcc_matrix_current_block = [coeffs, delta, deltaDelta];
            fullmfcc = [fullmfcc;mfcc_matrix_current_block];
            % ⭐ 修正 1: HMMには最新の1フレームのみを渡す (次元数 x 1 に転置)
            mfcc_data = mfcc_matrix_current_block'; 
            
            % 累積フレーム数をカウント
            accumulated_frame_count = accumulated_frame_count + 1;
            
            fprintf("MFCC computed at %.3f sec. Total frames: %d\n", toc, accumulated_frame_count);
           
            ringBuffer(1:length(frame)-shift_check) = []; % シフト量 (20ms) 分をのこす
            b = length(ringBuffer);
            if length(ringBuffer) > g-c+(Fs*0.02)
                shift_fix = shift_fix + 1;
                shift_change = frameLen -shift_check;
                ringBuffer = ringBuffer(shift_change + 1 : end);
                
            end
            if length(ringBuffer) < g-c+(Fs*0.02)
                disp('欠落しました');
                shift_error =  shift_error + 1;
            end
          
            % --- HMM認識処理 ---
            disp('--- 2. HMM認識の実行 ---');
    
            %p=size(mfcc_data,2);
            for s=1:size(mfcc_data,2);
                for k=1:num_fuda
                   
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
                    [~,recog_fuda] = max(posterior);
                end
                  
                   
                % ⭐⭐⭐ 最新の事後確率を表示 ⭐⭐⭐
                disp('--- 最新の札別 潜在確率 (Posterior) ---');
                for k = 1:num_fuda
        %            fprintf('  札 %d: %.6f\n', k, posterior_result(k, end) * 100); 
                    fprintf('  札 %d: %.6f\n', k, posterior(k) * 100); 
                end
            end
            % ⭐ 変更 3: 状態変数を更新し、次のステップへ引き継ぐ (リセットはしない) ⭐
            %before_ll = current_ll_matrix(:, end) ;
            %before_filt = current_filt;            
            
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
                % 札判定に使う音声は既にアライメントされているため、単純に累積フレーム数から確定時刻を計算します。
                kimariji_second = frame_shift_sec * (total_recog_frame - 1) + n; 
                
                % 全体の音声バッファから、その秒数に対応するサンプル数を切り出す
                kimariji_samples = ceil(kimariji_second * Fs); 
                
                if kimariji_samples > length(fullAudioBuffer_alignment)
                    kimariji_samples = length(fullAudioBuffer_alignment);
                    disp('警告: 計算されたサンプル数が現在のバッファ長を超過したため、バッファ全体を保存します。');
                end
                
                %audioToSave = fullAudioBuffer(1:kimariji_samples); 
                audioToSave = fullAudioBuffer_alignment(1:kimariji_samples); 
                
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
        end
        
        % ⭐ 追加: ファイル保存後も、HMMの状態は before_ll と before_filt を介して次のループに引き継がれる
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


try
    % 音声データのサンプリング周波数とデータ長を取得
    TotalSamples = length(fullAudioBuffer);
    TimeDuration = TotalSamples / Fs;
    
    % 時間ベクトルを作成
    time_vector = (0:TotalSamples-1) / Fs;
    
    figure;
    plot(time_vector, fullAudioBuffer);
    title('全入力音声波形');
    xlabel('時間 (秒)');
    ylabel('振幅');
    grid on;
    disp(['プロットが完了しました。音声総時間: ', num2str(TimeDuration, '%.3f'), ' 秒']);
catch ME_plot
    disp(['波形プロット中にエラーが発生しました: ', ME_plot.message]);
end

% === 既存の最終プロットブロック ===
try
    % 音声データのサンプリング周波数とデータ長を取得
    TotalSamples = length(fullAudioBuffer_alignment);
    TimeDuration = TotalSamples / Fs;
    
    % 時間ベクトルを作成
    time_vector = (0:TotalSamples-1) / Fs;
    
    figure;
    plot(time_vector, fullAudioBuffer_alignment);
    title('全入力音声波形 (アライメント済み)'); % ⭐ タイトルを修正
    xlabel('時間 (秒)');
    ylabel('振幅');
    grid on;
    disp(['プロットが完了しました。音声総時間: ', num2str(TimeDuration, '%.3f'), ' 秒']);
catch ME_plot
    disp(['波形プロット中にエラーが発生しました: ', ME_plot.message]);
end