clear;
% HMM関数 karuta_HMM_recog_realtime がパス上にあることを前提とします。
addpath('Lee_HMM'); 

% === ユーザー設定部分 ===
model_file = 'models_state30/iter10.mat'; % HMM学習済みモデル 
base_path = 'C:\Lab\karuta\success\karuta_HMM_realtime\aihara_test'; % 基本パス
folders = {'nageke', 'nageki', 'ooe', 'ooke', 'ooko', 'wasura', 'wasure', 'yamaga', 'yamaza'};
num_files = 5;      % data1 ～ data5
num_trials = 3;     % 各3回試行

% === HMMモデルのロード (一回のみ) ===
load(model_file, 'mean_vec_i_m', 'var_vec_i_m', 'a_i_j_m');
num_fuda = size(mean_vec_i_m, 3); % 札数 (K)
N = size(mean_vec_i_m, 2);      % 状態数 (N)

% 結果格納用 (フォルダ数 x ファイル数)
results_summary = cell(length(folders), num_files);

% ========================================
% 🔄 自動テストループ開始
% ========================================
for f_idx = 1:length(folders)
    folder_name = folders{f_idx};
    
    for d_idx = 1:num_files
        % ファイルパス設定 (例: nageke/nageke1.wav)
        input_wav_path = fullfile(base_path, folder_name, [folder_name num2str(d_idx) '.wav']);
        
        if ~exist(input_wav_path, 'file')
            fprintf('⚠️ ファイルが見つかりません: %s\n', input_wav_path);
            results_summary{f_idx, d_idx} = 'N/A';
            continue;
        end
        
        trial_results = zeros(1, num_trials); % 3回分の結果格納用
        
        for t = 1:num_trials
            fprintf('\n🔊 再生中: %s (試行 %d/%d)\n', input_wav_path, t, num_trials);

            % --- 元コードの初期化ロジック (そのまま維持) ---
            Fs = 44100;
            n = 0.03; m = 0.02; l = 0.01;
            threshold = 0.9999;
            w = 0.1;
            ll = zeros(num_fuda, 1);
            posterior = zeros(num_fuda,1);
            filt = zeros(N, num_fuda); 
            filt(1:N, :) = 1/N;
            accumulated_frame_count = 0;
            frame_count = 0;
            recog_fuda = 0;
            fuda = 0;
            lock_counter = 0;
            ringBuffer = [];
            fullAudioBuffer = [];
            started = false;
            input_gain = 2.0;
            silenceThresh = 0.05;
            frameLen = round(0.19 * Fs); 
            bufLen = round(l * Fs); 

            % デバイス設定
            deviceReader = audioDeviceReader('Device', 'ステレオ ミキサー (Realtek(R) Audio)', ...
                'SampleRate', Fs, 'SamplesPerFrame', bufLen);

            % 再生用データの読み込み
            [y_play, Fs_play] = audioread(input_wav_path);
            play_duration = length(y_play) / Fs_play; 
            
            % 音声再生開始
            sound(y_play, Fs_play);
            
            % --- 元コードの認識ループ (条件のみplay_durationに変更) ---
            tic
            while toc < (play_duration + 1.0) % 音声長 + 1秒の余裕
                [audioRecorded, numOverrun] = deviceReader(); 
                audioRecorded = audioRecorded * input_gain;
                
                if size(audioRecorded, 2) > 1
                    audioRecorded = mean(audioRecorded, 2);
                end
                
                ringBuffer = [ringBuffer; audioRecorded];
                if length(ringBuffer) > frameLen
                    ringBuffer(1 : length(ringBuffer)-frameLen) = [];
                end

                rmsVal = sqrt(mean(audioRecorded.^2));
                if ~started
                    if rmsVal > silenceThresh
                        started = true;
                    else
                        continue;
                    end
                end

                if started
                    accumulated_frame_count = accumulated_frame_count + 1;
                    fullAudioBuffer = [fullAudioBuffer; audioRecorded];
                    frame_count = frame_count + 1;
                    start_recog = toc;
                    
                    if length(ringBuffer) >= frameLen
                        % MFCC処理
                        [coeffs, delta, deltaDelta] = mfcc(ringBuffer(1:frameLen), Fs);
                        mfcc_matrix_current = [coeffs, delta, deltaDelta];
                        mfcc_data = mfcc_matrix_current(end,:)'; 
                        
                        % HMM認識処理
                        for k=1:num_fuda
                            pred = filt(:,k)'*a_i_j_m(:,:,k);
                            l_val = 0;
                            for i=2:N-1 
                                emission_prob = exp(logDiagGaussian(mfcc_data,mean_vec_i_m(:,i,k),var_vec_i_m(:,i,k)));
                                l_val = l_val + pred(i) * emission_prob;
                                filt(i,k) = pred(i) * emission_prob;
                            end
                            ll(k) = ll(k)+log(l_val + eps);
                            filt(:,k) = filt(:,k)/(sum(filt(:,k)) + eps);
                        end
                        posterior = exp(w*(ll-max(ll)));
                        posterior = posterior/sum(posterior);
                        
                        if max(posterior) > threshold
                            lock_counter = lock_counter + 1; 
                        else
                            lock_counter = 0; 
                        end

                        if lock_counter >= 3
                            [~,recog_fuda] = max(posterior);
                            break; % 確定したらループを抜ける
                        end
                    end
                end
            end
            
            % 試行終了後の後処理
            release(deviceReader);
            
            % ⭐ 次の音声を流す前に、現在の音声が鳴り終わるまで待機
            wait_time = (play_duration + 0.5) - toc;
            if wait_time > 0
                pause(wait_time);
            else
                pause(0.5); % 最低限のインターバル
            end
            
            trial_results(t) = recog_fuda;
            fprintf('   -> 試行 %d 結果: 札%d\n', t, recog_fuda);
        end
        
        % 3回分の結果を "12,12,12" の形式で保存
        results_summary{f_idx, d_idx} = strjoin(string(trial_results), ',');
    end
end

% ========================================
% 📊 最終結果表示
% ========================================
disp(' ');
disp('📜 ================= 決まり字 最終認識結果一覧 ================= 📜');
final_table = cell2table(results_summary, ...
    'VariableNames', {'data1', 'data2', 'data3', 'data4', 'data5'}, ...
    'RowNames', folders);
disp(final_table);

% 必要に応じて結果をCSV保存する場合
% writetable(final_table, 'recognition_results.csv', 'WriteRowNames', true);

disp('全ての処理が終了しました。');