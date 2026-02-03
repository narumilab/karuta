% 決定版：karuta_HMM_recog_realtime.m（修正完了版）
% リアルタイム音声入力に対してHMM認識を行い、決まり字確定時に音声をファイル保存するスクリプト
% 追加機能:
% - オーバーラン検出とログ記録
% - 決まり字確定シーケンスの最終出力
% - 音声再生と認識の同期処理

clear;
addpath('Lee_HMM'); 

% === ユーザー設定 ===
model_file = 'models_state30/iter10.mat'; 
input_wav_path = './aihara_test/ooke/ooke1.wav'; 

run_mode = 'online'; 

% レート設定
Fs_device = 44100; % ステレオミキサーからの入力
Fs_model  = 44100; % モデルの形式

l = 0.01; 
threshold = 0.9999;
w = 0.1;
context_duration = 0.19; 
consecutive_limit = 1; 

% ★★★ 修正1: デジタル増幅（ブースト） ★★★
% 音が小さい場合、ここで無理やり大きくします
input_gain = 2.0;  % 1.0 -> 10.0 に変更

% ★★★ 修正2: 閾値の調整 ★★★
% ブースト後の音量に合わせて調整
silenceThresh = 0.05; 

output_dir = './kimariji_outputs_success';     
output_base_name = 'recog_kimariji'; 

% === HMM初期化 ===
     
load(model_file, 'mean_vec_i_m', 'var_vec_i_m', 'a_i_j_m');
model_dim = size(mean_vec_i_m, 1); 
num_fuda = size(mean_vec_i_m, 3); % 札数 (K)
N = size(mean_vec_i_m, 2);      % 状態数 (N)
% ⭐ HMMの状態管理変数を初期化 ⭐
ll = zeros(num_fuda, 1);       % 累積尤度 (K x 1)
posterior = zeros(num_fuda,1);
%filt = zeros(N, num_fuda); 
%filt(1, :) = 1.0;
% 状態1だけに100%振るのではなく、最初の方の状態（例えば状態1〜5）に少し余裕を持たせる
filt = zeros(N, num_fuda);
filt(1:N, :) = 1/N; % 最初の5状態のどこから始まっても良いとする
     
recog_locked = false;                 
lock_counter = 0; 
recog_fuda_index = 0; 
mfcc_count=0;

% ⭐ 追加 3: 認識された札の確定インデックスの記録用リスト ⭐
recog_sequence_log = []; 
recog_timestamp_log = [];
overrun_log = {};

% =========================================================
% [モード] Windows ステレオミキサー入力増幅モード
% =========================================================
disp('==================================================');
disp('   🎧 Windows Stereo Mix Input (High Gain Mode)   ');
disp('==================================================');
disp('準備完了。音声を再生してください。');
disp('--------------------------------------------------');

context_samples_model = round(context_duration * Fs_model); 

try
    deviceReader = audioDeviceReader(...
        'Device', 'ステレオ ミキサー (Realtek(R) Audio)', ... 
        'SampleRate', Fs_device, ...
        'SamplesPerFrame', round(l * Fs_device)); 
    disp(['✅ ステレオ ミキサーに接続 (Gain: x' num2str(input_gain) ')']);
catch
    disp('⚠️ ステレオミキサー接続エラー。デバイスリスト:');
    audioDeviceReader.getAudioDevices();
    return;
end

ringBuffer = [];      
fullAudioBuffer = []; 
started = false;      
silence_counter = 0;
lock_counter = 0; 
accumulated_frame_count = 0;
frame_count = 0;

% リサンプラー（Fs_device と Fs_model が異なる場合のみ使用）
if Fs_device ~= Fs_model
    src = dsp.SampleRateConverter('InputSampleRate', Fs_device, 'OutputSampleRate', Fs_model);
else
    src = []; % リサンプリング不要
end

tic;
while ~recog_locked
    % 1. 取得 & モノラル化
     [acquiredAudio, numOverrun] = deviceReader();
    accumulated_frame_count = accumulated_frame_count + 1;
    if numOverrun > 0

        fprintf('⚠️ 警告: フレーム %d (%.3f秒) で**オーバーラン**が発生しました。欠落サンプル数: %d\n', ...
            accumulated_frame_count, toc, numOverrun);
        % 2. ここで overrun_log にデータを追加する
        overrun_log{end+1} = [accumulated_frame_count, toc, numOverrun];
    end
   
    if size(acquiredAudio, 2) > 1
        acquiredAudio = mean(acquiredAudio, 2);
    end
    
    % 2. リサンプリング（必要な場合のみ）
    if ~isempty(src)
        acquiredAudio = src(acquiredAudio);
    end
    
    % 3. ★強制増幅★
    acquiredAudio = acquiredAudio * input_gain;
    
    % --- 音量デバッグ表示 (重要) ---
    % 現在、MATLABがどれくらいの音量を受け取っているかを表示
    vol = max(abs(acquiredAudio));
    if vol > 0.01 && ~started
        fprintf('現在の入力レベル: %.4f (目標: 0.1以上)\n', vol);
    end
    % ---------------------------

    ringBuffer = [ringBuffer; acquiredAudio];
    if length(ringBuffer) > context_samples_model
        ringBuffer(1:length(ringBuffer)-context_samples_model) = [];
    end
    
    rmsVal = sqrt(mean(acquiredAudio.^2));
    
    if length(ringBuffer) >= context_samples_model
        if rmsVal > silenceThresh
            silence_counter = 0; is_active = true; start_recog = toc;
        else
            if started
                silence_counter = silence_counter + 1;
                % ★修正3: 音切れ防止のため、無音許容時間を少し伸ばす
                if silence_counter <= 50, is_active = true; else, is_active = false; end
            else, is_active = false; end
        end
        
        if is_active
            
            if ~started
                started = true;
                disp('>>> 🎵 音声を検知！ 解析中... >>>');
                 
                fullAudioBuffer = [ringBuffer; acquiredAudio]; 
                %before_ll = zeros(num_fuda, 1); before_filt = zeros(N, num_fuda);
                lock_counter = 0;
                start_frame = accumulated_frame_count;
            else
                fullAudioBuffer = [fullAudioBuffer; acquiredAudio];
            end
            frame_count = frame_count + 1;

            [coeffs, delta, deltaDelta] = mfcc(ringBuffer, Fs_model);
            mfcc_block = [coeffs, delta, deltaDelta];
            if size(mfcc_block, 2) > model_dim, mfcc_block = mfcc_block(:, 1:model_dim);
            elseif size(mfcc_block, 2) < model_dim, mfcc_block(:, end+1:model_dim) = 0; end
            
            latest_idx = size(mfcc_block, 1);
            %if mfcc_count==0
                %mfcc_count = mfcc_count + 1; % Increment the MFCC count
                %mfcc_matrix_current_block = mfcc_block(latest_idx,:);
            %else
                %mfcc_count = mfcc_count + 1;
                %mfcc_matrix_current_block = mfcc_block(latest_idx,:);
            %end 
            mfcc_matrix_current_block = mfcc_block(latest_idx,:);
            mfcc_data = mfcc_matrix_current_block'; 
            disp('--- 2. HMM認識の実行 ---');
    
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
                
            
                if max(posterior) > 0.1
                    stars = repmat('★', 1, lock_counter);
                    max_p = max(posterior);
                    [max_val, max_idx] = max(posterior);
                    fprintf('  候補: 札%d (%.2f%%) %s\n', max_idx, max_p*100, stars);
                end
                
                if max(posterior) > threshold, lock_counter = lock_counter + 1; else, lock_counter = 0; end
                
                if lock_counter >= consecutive_limit
                    end_toc = toc;
                    elapsed_time = end_toc - start_recog;
                    recog_locked = true;
                    % ⭐ 修正 4: 確定フレーム数は累積カウントを使用 ⭐
                    total_recog_frame = frame_count
                    %total_recog_frame = accumulated_frame_count - start_frame +1
                    % 確定時点までの秒数を計算 (frame_shift_sec は 10ms)
                    kimariji_second = 0.01 * (total_recog_frame - 1) + 0.03;
                    recog_fuda_index = max_idx;
                    recog_sequence_log = [recog_sequence_log, recog_fuda_index]; % ⭐ 追加: 確定した札インデックスを記録 ⭐
                    recog_timestamp_log = [recog_timestamp_log; recog_fuda_index, kimariji_second];
                    disp(['=== 🎯 決まり字確定！ 札: ', num2str(recog_fuda_index), ' 時間: ', num2str(elapsed_time), '秒 ===']);
                end
            end
        else
            if started
                disp('<<< リセット (音が途切れました) <<<');
                started = false; silence_counter = 0; lock_counter = 0;
                before_ll = zeros(num_fuda, 1); before_filt = zeros(N, num_fuda);
            end
        end
    end
    
    if toc > 60, disp('タイムアウト'); break; end
end

release(deviceReader);
if ~isempty(src)
    release(src);
end

if recog_locked
    try
        if ~exist(output_dir, 'dir'), mkdir(output_dir); end
        timestamp = datestr(now, 'yyyymmddHHMMSS');
        output_filename = fullfile(output_dir, [output_base_name '_idx' num2str(recog_fuda_index) '_' timestamp '.wav']);
        audioToSave = fullAudioBuffer;
        if ~isempty(audioToSave)
            audioToSave = audioToSave / (max(abs(audioToSave)) + eps); % 正規化
            audiowrite(output_filename, audioToSave, Fs_model);
            disp(['💾 保存完了: ', output_filename]);
        end
    catch ME, disp(['⚠️ 保存エラー: ', ME.message]); end
end


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
    %TimeDuration = TotalSamples / Fs_device;
    
    % 時間ベクトルを作成
    %time_vector = (0:TotalSamples-1) / Fs_device;
    
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