clear;
addpath('Lee_HMM'); 

% === ユーザー設定 ===
model_file = 'models_state30/iter10.mat'; 
input_wav_path = './aihara_test/ooke/ooke1.wav'; 

run_mode = 'online'; 

% レート設定
Fs_device = 48000; % BlackHoleからの入力
Fs_model  = 44100; % モデルの形式

l = 0.01; 
threshold = 0.9999;
w = 0.1;
context_duration = 0.3; 
consecutive_limit = 3; 

% ★★★ 修正1: デジタル増幅（ブースト） ★★★
% 音が小さい場合、ここで無理やり大きくします
input_gain = 2.0;  % 1.0 -> 10.0 に変更

% ★★★ 修正2: 閾値の調整 ★★★
% ブースト後の音量に合わせて調整
silenceThresh = 0.05; 

output_dir = './kimariji_outputs';     
output_base_name = 'recog_kimariji'; 

% === HMM初期化 ===
load(model_file, 'mean_vec_i_m');
model_dim = size(mean_vec_i_m, 1); 
num_fuda = size(mean_vec_i_m, 3); 
N = size(mean_vec_i_m, 2);      

before_ll = zeros(num_fuda, 1);       
before_filt = zeros(N, num_fuda);     
recog_locked = false;                 
lock_counter = 0; 
recog_fuda_index = 0; 

% =========================================================
% [モードB] BlackHole 入力増幅モード
% =========================================================
disp('==================================================');
disp('   🎧 BlackHole Input (High Gain Mode)   ');
disp('==================================================');
disp('準備完了。音声を再生してください。');
disp('--------------------------------------------------');

context_samples_model = round(context_duration * Fs_model); 

try
    deviceReader = audioDeviceReader(...
        'Device', 'BlackHole 2ch', ... 
        'SampleRate', Fs_device, ...
        'SamplesPerFrame', round(l * Fs_device)); 
    disp(['✅ BlackHole 2ch に接続 (Gain: x' num2str(input_gain) ')']);
catch
    disp('⚠️ BlackHole接続エラー'); return;
end

ringBuffer = [];      
fullAudioBuffer = []; 
started = false;      
silence_counter = 0;
lock_counter = 0; 

% リサンプラー
src = dsp.SampleRateConverter('InputSampleRate', Fs_device, 'OutputSampleRate', Fs_model);

tic;
while ~recog_locked
    % 1. 取得 & モノラル化
    acquiredAudio_48k = deviceReader();
    if size(acquiredAudio_48k, 2) > 1
        acquiredAudio_48k = mean(acquiredAudio_48k, 2);
    end
    
    % 2. リサンプリング (48k -> 44.1k)
    acquiredAudio_44k = src(acquiredAudio_48k);
    
    % 3. ★強制増幅★
    acquiredAudio_44k = acquiredAudio_44k * input_gain;
    
    % --- 音量デバッグ表示 (重要) ---
    % 現在、MATLABがどれくらいの音量を受け取っているかを表示
    vol = max(abs(acquiredAudio_44k));
    if vol > 0.01 && ~started
        fprintf('現在の入力レベル: %.4f (目標: 0.1以上)\n', vol);
    end
    % ---------------------------

    ringBuffer = [ringBuffer; acquiredAudio_44k];
    if length(ringBuffer) > context_samples_model
        ringBuffer(1:length(ringBuffer)-context_samples_model) = [];
    end
    
    rmsVal = sqrt(mean(acquiredAudio_44k.^2));
    
    if length(ringBuffer) >= context_samples_model
        if rmsVal > silenceThresh
            silence_counter = 0; is_active = true;
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
                fullAudioBuffer = []; 
                fullAudioBuffer = [ringBuffer; acquiredAudio_44k]; 
                before_ll = zeros(num_fuda, 1); before_filt = zeros(N, num_fuda);
                lock_counter = 0;
            else
                fullAudioBuffer = [fullAudioBuffer; acquiredAudio_44k];
            end
            
            [coeffs, delta, deltaDelta] = mfcc(ringBuffer, Fs_model);
            mfcc_block = [coeffs, delta, deltaDelta];
            if size(mfcc_block, 2) > model_dim, mfcc_block = mfcc_block(:, 1:model_dim);
            elseif size(mfcc_block, 2) < model_dim, mfcc_block(:, end+1:model_dim) = 0; end
            
            latest_idx = size(mfcc_block, 1); 
            mfcc_data = mfcc_block(latest_idx, :)'; 
            
            [~, ~, posterior_result, current_ll_matrix, current_filt] = ...
                karuta_HMM_recog_realtime(mfcc_data, model_file, threshold, w, before_ll, before_filt);
            before_ll = current_ll_matrix(:, end); before_filt = current_filt;
            
            [max_p, max_idx] = max(posterior_result(:, end));
            
            if max_p > 0.1
                stars = repmat('★', 1, lock_counter);
                fprintf('  候補: 札%d (%.1f%%) %s\n', max_idx, max_p*100, stars);
            end
            
            if max_p > 0.999, lock_counter = lock_counter + 1; else, lock_counter = 0; end
            
            if lock_counter >= consecutive_limit
                recog_locked = true;
                recog_fuda_index = max_idx;
                disp(['=== 🎯 決まり字確定！ 札: ', num2str(recog_fuda_index), ' ===']);
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
release(src);

if recog_locked
    try
        if ~exist(output_dir, 'dir'), mkdir(output_dir); end
        timestamp = datestr(now, 'yyyymmddHHMMSS');
        output_filename = fullfile(output_dir, ...
            [output_base_name '_BLACKHOLE_HighGain_idx' num2str(recog_fuda_index) '_' timestamp '.wav']);
        
        audioToSave = fullAudioBuffer;
        if max(abs(audioToSave)) > 0
            audioToSave = audioToSave / max(abs(audioToSave));
        end
        audiowrite(output_filename, audioToSave, Fs_model);
        disp(['保存しました: ', output_filename]);
    catch ME, disp(['保存エラー: ', ME.message]); end
end