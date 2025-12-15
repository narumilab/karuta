clear;
addpath('Lee_HMM'); 

% === ユーザー設定 ===
model_file = 'models_state30/iter10.mat'; 
input_wav_path = './aihara_test/ooko/ooko1.wav'; 

% デフォルトは offline でテストして「理論値」を見てください
if ~exist('run_mode', 'var'), run_mode = 'offline'; end
is_offline = strcmpi(run_mode, 'offline');

Fs_target = 44100; 
l = 0.01; % 10ms
threshold = 0.9999;
w = 0.1;

% ★重要変更: バッファサイズを 0.3秒 (300ms) に拡大★
% これにより前後の音脈を広く見れるようになり、誤認識が減ります。
context_duration = 0.3; 

% 連続一致回数 (3回 = 30ms 連続で確率99.9%超えなら確定)
consecutive_limit = 3; 

% マイク設定
silenceThresh = 0.05; 
input_gain = 3.0; 

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

% =========================================================
% [モードA] オフライン分析 (理論上の最速タイムを計測)
% =========================================================
if is_offline
    disp(['--- オフライン分析モード: ' input_wav_path ' ---']);
    disp(['Context Duration: ' num2str(context_duration) ' sec']);
    
    [y, Fs_in] = audioread(input_wav_path);
    if Fs_in ~= Fs_target, y = resample(y, Fs_target, Fs_in); end
    
    sim_buffer = [];
    % ★修正: ここで変数を参照するように変更
    context_samples = round(context_duration * Fs_target); 
    step_samples = round(0.01 * Fs_target);   
    
    disp('--------------------------------------------------');
    current_pos = 1;
    frame_count = 0;
    
    while current_pos + step_samples <= length(y)
        new_chunk = y(current_pos : current_pos + step_samples - 1);
        sim_buffer = [sim_buffer; new_chunk];
        
        if length(sim_buffer) > context_samples
            sim_buffer(1 : length(sim_buffer)-context_samples) = [];
        end
        
        if length(sim_buffer) >= context_samples
            frame_count = frame_count + 1;
            
            [coeffs, delta, deltaDelta] = mfcc(sim_buffer, Fs_target);
            mfcc_block = [coeffs, delta, deltaDelta];
            if size(mfcc_block, 2) > model_dim, mfcc_block = mfcc_block(:, 1:model_dim);
            elseif size(mfcc_block, 2) < model_dim, mfcc_block(:, end+1:model_dim) = 0; end
            stable_idx = round(size(mfcc_block, 1) / 2); 
            mfcc_data = mfcc_block(stable_idx, :)'; 

            [~, ~, posterior_result, current_ll_matrix, current_filt] = ...
                karuta_HMM_recog_realtime(mfcc_data, model_file, threshold, w, before_ll, before_filt);
            
            before_ll = current_ll_matrix(:, end);
            before_filt = current_filt;
            
            [max_p, max_idx] = max(posterior_result(:, end));
            
            time_sec = frame_count * 0.01;
            if max_p > 0.01
                fprintf('経過: %.2f秒 | 有力: 札%d (%.2f%%)\n', time_sec, max_idx, max_p*100);
            end
            
            if max_p > 0.999
                lock_counter = lock_counter + 1;
            else
                lock_counter = 0;
            end
            
            if lock_counter >= consecutive_limit
                disp('--------------------------------------------------');
                disp(['★ 理論上の認識確定タイム: ' num2str(time_sec) ' 秒']);
                disp(['★ 認識された札: ' num2str(max_idx)]);
                disp('--------------------------------------------------');
                break; 
            end
        end
        current_pos = current_pos + step_samples;
    end
    return;
end

% =========================================================
% [モードB] オンラインモード (最速アタック仕様)
% =========================================================
disp('--- オンラインモード: マイク入力を開始 ---');
disp(['Context Duration: ' num2str(context_duration) ' sec']);

% ★修正: ここで変数を参照するように変更
context_samples = round(context_duration * Fs_target); 

deviceReader = audioDeviceReader(...
    'Device', 'MacBook Proのマイク', ... 
    'SampleRate', Fs_target, ...
    'SamplesPerFrame', round(l * Fs_target)); 

ringBuffer = [];      
fullAudioBuffer = []; 
started = false;      
silence_counter = 0;
lock_counter = 0; 

tic;
while ~recog_locked
    acquiredAudio = deviceReader();
    acquiredAudio = acquiredAudio * input_gain; 
    
    ringBuffer = [ringBuffer; acquiredAudio];
    if length(ringBuffer) > context_samples
        ringBuffer(1:length(ringBuffer)-context_samples) = [];
    end
    
    rmsVal = sqrt(mean(acquiredAudio.^2));
    
    if length(ringBuffer) >= context_samples
        if rmsVal > silenceThresh
            silence_counter = 0; is_active = true;
        else
            if started
                silence_counter = silence_counter + 1;
                if silence_counter <= 30, is_active = true; else, is_active = false; end
            else, is_active = false; end
        end
        
        if is_active
            if ~started
                started = true;
                disp('>>> 音声を検知! 認識開始 >>>');
                fullAudioBuffer = []; fullAudioBuffer = [fullAudioBuffer; ringBuffer]; 
                before_ll = zeros(num_fuda, 1); before_filt = zeros(N, num_fuda);
                lock_counter = 0;
            else
                fullAudioBuffer = [fullAudioBuffer; acquiredAudio];
            end
            
            [coeffs, delta, deltaDelta] = mfcc(ringBuffer, Fs_target);
            mfcc_block = [coeffs, delta, deltaDelta];
            if size(mfcc_block, 2) > model_dim, mfcc_block = mfcc_block(:, 1:model_dim);
            elseif size(mfcc_block, 2) < model_dim, mfcc_block(:, end+1:model_dim) = 0; end
            stable_idx = round(size(mfcc_block, 1) / 2); mfcc_data = mfcc_block(stable_idx, :)'; 
            
            [~, ~, posterior_result, current_ll_matrix, current_filt] = ...
                karuta_HMM_recog_realtime(mfcc_data, model_file, threshold, w, before_ll, before_filt);
            before_ll = current_ll_matrix(:, end); before_filt = current_filt;
            
            [max_p, max_idx] = max(posterior_result(:, end));
            
            if max_p > 0.1
                stars = repmat('★', 1, lock_counter);
                fprintf('  有力: 札%d (%.1f%%) %s\n', max_idx, max_p*100, stars);
            end
            
            if max_p > 0.999
                lock_counter = lock_counter + 1;
            else
                lock_counter = 0; 
            end
            
            if lock_counter >= consecutive_limit
                recog_locked = true;
                recog_fuda_index = max_idx;
                disp(['=== 決まり字確定！ 札: ', num2str(recog_fuda_index), ' ===']);
            end
            
        else
            if started
                disp('<<< 無音検知によりリセット <<<');
                started = false; silence_counter = 0; lock_counter = 0;
                before_ll = zeros(num_fuda, 1); before_filt = zeros(N, num_fuda);
            end
        end
    end
    
    if toc > 60, disp('タイムアウト'); break; end
end

release(deviceReader);

if recog_locked && ~is_offline
    try
        if ~exist(output_dir, 'dir'), mkdir(output_dir); end
        timestamp = datestr(now, 'yyyymmddHHMMSS');
        output_filename = fullfile(output_dir, ...
            [output_base_name '_idx' num2str(recog_fuda_index) '_' timestamp '.wav']);
        
        audiowrite(output_filename, fullAudioBuffer, Fs_target);
        disp(['音声を保存しました: ', output_filename]);
        disp(['認識までの時間: ', num2str(length(fullAudioBuffer)/Fs_target), ' 秒']);
    catch ME, disp(['保存エラー: ', ME.message]); end
end