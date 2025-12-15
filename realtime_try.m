clear;
addpath('Lee_HMM'); 

% === ユーザー設定 ===
model_file = 'models_state30/iter10.mat'; 
input_wav_path = './aihara_test/nageke/nageke1.wav'; 

% 'online' で自動テスト
if ~exist('run_mode', 'var'), run_mode = 'online'; end
is_offline = strcmpi(run_mode, 'offline');

Fs_target = 44100; 
l = 0.01; 
threshold = 0.9999;
w = 0.1;

% バッファサイズ 0.3秒
context_duration = 0.3; 
% 連続一致回数 
consecutive_limit = 3; 

% マイク設定
silenceThresh = 0.03; 
input_gain = 1.5; % ★5.0は大きすぎてノイズ誤爆の元なので、1.5くらいに下げます

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
% [モードA] オフライン分析
% =========================================================
if is_offline
    disp(['--- オフライン分析モード ---']);
    [y, Fs_in] = audioread(input_wav_path);
    if Fs_in ~= Fs_target, y = resample(y, Fs_target, Fs_in); end
    
    sim_buffer = [];
    context_samples = round(context_duration * Fs_target); 
    step_samples = round(0.01 * Fs_target);   
    current_pos = 1; frame_count = 0;
    
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
            
            % ★修正ポイント(Offline): 最新のフレーム（最後尾）を使う
            latest_idx = size(mfcc_block, 1); 
            mfcc_data = mfcc_block(latest_idx, :)'; 

            [~, ~, posterior_result, current_ll_matrix, current_filt] = ...
                karuta_HMM_recog_realtime(mfcc_data, model_file, threshold, w, before_ll, before_filt);
            before_ll = current_ll_matrix(:, end); before_filt = current_filt;
            [max_p, max_idx] = max(posterior_result(:, end));
            
            time_sec = frame_count * 0.01;
            if max_p > 0.999, lock_counter = lock_counter + 1; else, lock_counter = 0; end
            
            if lock_counter >= consecutive_limit
                disp(['★ 理論確定タイム: ' num2str(time_sec) ' 秒 (札: ' num2str(max_idx) ')']);
                if ~exist(output_dir, 'dir'), mkdir(output_dir); end
                timestamp = datestr(now, 'yyyymmddHHMMSS');
                output_filename = fullfile(output_dir, [output_base_name '_OFFLINE_REF_idx' num2str(max_idx) '_' timestamp '.wav']);
                cut_end_idx = min(current_pos + step_samples - 1, length(y));
                audiowrite(output_filename, y(1:cut_end_idx), Fs_target);
                return;
            end
        end
        current_pos = current_pos + step_samples;
    end
    return;
end

% =========================================================
% [モードB] オンラインモード
% =========================================================
disp('--- オンラインモード: 自動テスト開始 ---');
disp('3秒後にPCから音声を再生し、同時にマイクで聞き取ります...');
pause(1); disp('2...');
pause(1); disp('1...');

[y_play, Fs_play] = audioread(input_wav_path);
y_play = y_play / max(abs(y_play)) * 0.8; 

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
played_flag = false; 

tic;
start_time = toc;

while ~recog_locked
    acquiredAudio = deviceReader();
    acquiredAudio = acquiredAudio * input_gain; 
    
    ringBuffer = [ringBuffer; acquiredAudio];
    if length(ringBuffer) > context_samples
        overflow = length(ringBuffer) - context_samples;
        ringBuffer(1:overflow) = [];
    end
    
    current_time = toc;
    if ~played_flag && (current_time - start_time > 0.5)
        disp('>>> NOW PLAYING AUDIO >>>');
        sound(y_play, Fs_play); 
        played_flag = true;
    end
    
    if length(ringBuffer) >= context_samples
        rmsVal = sqrt(mean(acquiredAudio.^2));
        
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
                disp('>>> 録音開始 (トリガー検知) >>>');
                fullAudioBuffer = []; 
                fullAudioBuffer = [ringBuffer; acquiredAudio]; 
                before_ll = zeros(num_fuda, 1); before_filt = zeros(N, num_fuda);
                lock_counter = 0;
            else
                fullAudioBuffer = [fullAudioBuffer; acquiredAudio];
            end
            
            [coeffs, delta, deltaDelta] = mfcc(ringBuffer, Fs_target);
            mfcc_block = [coeffs, delta, deltaDelta];
            if size(mfcc_block, 2) > model_dim, mfcc_block = mfcc_block(:, 1:model_dim);
            elseif size(mfcc_block, 2) < model_dim, mfcc_block(:, end+1:model_dim) = 0; end
            
            % ★★★ ここが最大の修正ポイント ★★★
            % バッファの「真ん中」ではなく「一番後ろ（最新）」を取る！
            % これで無音（過去）ではなく、今鳴った音（現在）を認識できます
            latest_idx = size(mfcc_block, 1); 
            mfcc_data = mfcc_block(latest_idx, :)'; 
            
            [~, ~, posterior_result, current_ll_matrix, current_filt] = ...
                karuta_HMM_recog_realtime(mfcc_data, model_file, threshold, w, before_ll, before_filt);
            before_ll = current_ll_matrix(:, end); before_filt = current_filt;
            
            [max_p, max_idx] = max(posterior_result(:, end));
            
            if max_p > 0.1
                stars = repmat('★', 1, lock_counter);
                fprintf('  有力: 札%d (%.1f%%) %s\n', max_idx, max_p*100, stars);
            end
            
            if max_p > 0.999, lock_counter = lock_counter + 1; else, lock_counter = 0; end
            
            if lock_counter >= consecutive_limit
                recog_locked = true;
                recog_fuda_index = max_idx;
                disp(['=== 決まり字確定！ 札: ', num2str(recog_fuda_index), ' ===']);
            end
        else
            if started
                disp('<<< 無音リセット <<<');
                started = false; silence_counter = 0; lock_counter = 0;
                before_ll = zeros(num_fuda, 1); before_filt = zeros(N, num_fuda);
            end
        end
    end
    
    if toc > 10, disp('タイムアウト'); break; end
end

release(deviceReader);

if recog_locked && ~is_offline
    try
        if ~exist(output_dir, 'dir'), mkdir(output_dir); end
        timestamp = datestr(now, 'yyyymmddHHMMSS');
        output_filename = fullfile(output_dir, ...
            [output_base_name '_ONLINE_AUTO_idx' num2str(recog_fuda_index) '_' timestamp '.wav']);
        
        audioToSave = fullAudioBuffer;
        if max(abs(audioToSave)) > 0, audioToSave = audioToSave / max(abs(audioToSave)); end
        audiowrite(output_filename, audioToSave, Fs_target);
        disp(['音声を保存しました: ', output_filename]);
    catch ME, disp(['保存エラー: ', ME.message]); end
end