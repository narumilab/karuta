clear;
% HMM関数 karuta_HMM_recog_realtime がパス上にあることを前提とします。
addpath('Lee_HMM'); 
% === ユーザー設定部分 ===
model_file = 'models_state30/iter10.mat'; % HMM学習済みモデル 
% === ユーザー設定部分 ===
model_file = 'models_state30/iter10.mat'; 

% ⭐ ここから追加：巡回用の設定
% ⭐ 追加：巡回用の設定
base_path = './aihara_test'; 
%folders = {'nageke', 'nageki', 'ooe', 'ooke', 'ooko', 'wasura', 'wasure', 'yamaga', 'yamaza'};
folders = {'yamaga', 'nageki'};
num_files = 5; 
num_trials = 3; 
results_summary = cell(length(folders), num_files); 
times_summary   = cell(length(folders), num_files);

% ⭐ 追加：3重ループの開始
for f_idx = 1:length(folders)
    for d_idx = 1:num_files
        trial_results = strings(1, num_trials); % 1x3 の string配列
        trial_times   = cell(1, num_trials);    % 1x3 の セル配列
        for t = 1:num_trials
            

            % パスを自動生成 (例: ./aihara_test/nageke/nageke1.wav)
            input_wav_path = fullfile(base_path, folders{f_idx}, [folders{f_idx} num2str(d_idx) '.wav']);
            fprintf('\n🔊 再生中: %s (試行 %d/%d)\n', input_wav_path, t, num_trials);
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
            N = size(mean_vec_i_m, 2);      % 状態数 (N)
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
            if exist('deviceReader','var')
                release(deviceReader);
                clear deviceReader;
            end

            pause(0.3);   % デバイスを落ち着かせる
            deviceReader = audioDeviceReader( ...
                'Device', 'ステレオ ミキサー (Realtek(R) Audio)', ...
                'SampleRate', Fs, ...
                'SamplesPerFrame', bufLen);
            %disp('Listening... (waiting for non-silent input)')
            



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
            played_flag = false;   % ⭐ 音声再生済みかどうか

            mfcc_count=0;
            [y_play, Fs_play] = audioread(input_wav_path);
            play_duration = length(y_play) / Fs_play; 
            % ===== 完全リセット =====
            ringBuffer = [];
            fullAudioBuffer = [];
            fullmfcc = [];

            started = false;
            audio_started = false;
            recog_locked = false;
            recognized = false;

            ll = zeros(num_fuda,1);
            filt(:,:) = 1/N;
            lock_counter = 0;
            fuda = 0;
            recog_sequence_log = [];
            recog_timestamp_log = [];
            overrun_log = {};

            % deviceReader の残音フラッシュ
            for flush = 1:5
                deviceReader();
            end
            
            
            
            played_flag = false;
            %sound(y_play, Fs_play); 
            %pause(0.05);
            tic
            % ⭐ while toc < 5 を再生時間基準に変更
            while toc < (play_duration + 2)
            %tic
            %while toc < 5 % 時間を30秒間に延長 (認識が継続するため)
                
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
                if ~played_flag
                    pause(2); % 安定化待ち
                    sound(y_play, Fs_play);
                    played_flag = true; % ⭐ 3. すぐにスイッチを「オン」にする

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
                        %disp("🎵 Sound detected! Analyzing with pre-roll buffer...");
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
                            else
                                lock_counter = 0; 
                            end

                            if lock_counter >= 3
                                [~,recog_fuda] = max(posterior);
                                
                                % ⭐ 修正：エラーが出ていた箇所。tocで現在の時間を取得
                                total_sec = toc; 
                                %fprintf("✅ 札%d 確定 (%.3f秒)\n", recog_fuda, total_sec);
                                
                                break; % whileループを抜けて次の「試行」へ
                            end
                            
                            
                            % ⭐⭐⭐ 最新の事後確率を表示 ⭐⭐⭐
                            disp('--- 最新の札別 潜在確率 (Posterior) ---');
                            if max(posterior) > 0.1
                                stars = repmat('★', 1, lock_counter);
                                max_p = max(posterior);
                                [max_val, max_idx] = max(posterior);
                                fprintf('  候補: 札%d (%.2f%%) %s\n', max_idx, max_p*100, stars);
                            end
                            %for k = 1:num_fuda
                    %            fprintf('  札 %d: %.6f\n', k, posterior_result(k, end) * 100); 
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
                            %fprintf("決まり字が確定しました！ %.3f sec. Total frames: %d\n", total_sec, frame_count);
                            fuda = recog_fuda;
                            % ⭐ 追加 4: 確定した札のインデックスを記録 ⭐
                            recog_sequence_log = [recog_sequence_log, recog_fuda];
                            %disp('*** 決まり字が確定しました！確定区間の音声をファイル保存します (状態は継続) ***');
                            % --- 修正箇所：if recog_fuda ~= fuda のブロック内 ---

                
                
                


                            % ⭐ 修正 4: 確定フレーム数は累積カウントを使用 ⭐
                            total_recog_frame = frame_count;
                            
                            % 確定時点までの秒数を計算 (frame_shift_sec は 10ms)
                            kimariji_second = 0.01 * (total_recog_frame - 1) + 0.03; 

                            % ⭐ 追加：時刻と札番号をペアで記録
                            recog_timestamp_log = [recog_timestamp_log; recog_fuda, kimariji_second];
                            fprintf("✅ 札%d 確定 (%.3f秒)\n", recog_fuda, kimariji_second);
                            % 全体の音声バッファから、その秒数に対応するサンプル数を切り出す
                            kimariji_samples = ceil(kimariji_second * Fs);
                            
                            if kimariji_samples > length(fullAudioBuffer)
                                kimariji_samples = length(fullAudioBuffer);
                                %disp('警告: 計算されたサンプル数が現在のバッファ長を超過したため、バッファ全体を保存します。');
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
                                
                                %disp(['ファイル保存が完了しました。保存先: ', output_filename]);
                                %disp(['保存音声長: ', num2str(kimariji_second), ' 秒']);
                                
                            catch ME_save
                                %disp('ファイル保存エラーが発生しました。');
                                %disp(['エラーメッセージ: ' ME_save.message]);
                            end
                            
                            % *** HMM状態リセット処理はここには追加しません ***
                        end
                        
                        % ⭐ 追加: ファイル保存後も、HMMの状態は before_ll と before_filt を介して次のループに引き継がれる
                    
                        
                        
                    end
                end
            end
            % 試行の開始時にバッファをクリア
            release(deviceReader);
            
            %disp('📜 **決まり字 最終認識シーケンス** 📜');
            % --- 1 & 2. バッファ・オーバーラン警告（前回のまま） ---
            if shift_fix > 0, fprintf('ℹ️ バッファ調節: %d回\n', shift_fix); end
            if shift_error > 0, fprintf('⚠️ バッファ不足: %d回\n', shift_error); end
            if ~isempty(overrun_log)
                fprintf('🚨 オーバーラン発生 (%d箇所)\n', length(overrun_log));
            end

            % ⭐ 3. 認識シーケンス：2種類以上の札が検出された場合のみ表示 ⭐
            if ~isempty(recog_sequence_log)
                unique_seq = unique(recog_sequence_log, 'stable'); % 登場した順にユニーク化
                
                if length(unique_seq) >= 2
                    % 2種類以上の札番号がある場合のみ実行
                    output_str = join(string(unique_seq), ' → ');
                    fprintf('📍 認識遷移（揺れ）を検出: %s\n', output_str{1});
                    
                     %詳細な時刻も知りたい場合は以下も表示
                     disp('   (確定時刻詳細)');
                     for i = 1:size(recog_timestamp_log, 1)
                         fprintf('   札%d (%.3fs)\n', recog_timestamp_log(i,1), recog_timestamp_log(i,2));
                     end
                end
            end
            trial_results(t) = recog_fuda;
            % 1. 認識結果の文字列作成
            if isempty(recog_sequence_log)
                trial_results(t) = "None";
                trial_times{t}   = "NaN";
            else
                % 札番号の遷移を "10 → 12" 形式にする
                % join(string()) を使うと非常に安定します
                trial_results(t) = join(string(recog_sequence_log), " → ");
                
                % 2. 確定時刻を "0.50s, 1.20s" 形式にする
                % compose は数値を一括で整形して string 配列を返すため strjoin と相性抜群です
                if size(recog_timestamp_log, 1) > 0
                    time_values = recog_timestamp_log(:,2);
                    time_strs = compose("%.2fs", time_values); 
                    trial_times{t} = strjoin(time_strs, ", ");
                else
                    trial_times{t} = "NaN";
                end
            end

            % ⭐ 重要：以下の行は削除またはコメントアウトしてください
            % trial_results(t) = recog_fuda; % ← これがあると上の "10 → 12" がただの数値で上書きされます

            % 音声再生が終わるのを待つ同期処理
            remaining = (play_duration + 0.5) - toc;
            if remaining > 0
                pause(remaining); 
            end
        end % t (試行) ループ終了
        pause(2); % 各ファイル間に少し待機時間を入れる

        % ⭐ 追加：3回分の結果をカンマ区切りで表のセルに格納
        results_summary{f_idx, d_idx} = strjoin(trial_results, ' | ');
        times_summary{f_idx, d_idx}   = strjoin(string(trial_times), ' | ');
    end % 🔄 d_idx (file) ループ終了
end % f_idx (フォルダ) ループ終了

% ⭐ 追加：最後にまとめて表を表示
T = cell2table(results_summary, 'VariableNames',{'data1','data2','data3','data4','data5'}, 'RowNames',folders);
disp(T);
% === 📊 結果の自動保存 (ここを追加) ===
% 実行時の日時を取得してファイル名にする (例: results_20251229_1700.csv)
timestamp = datestr(now, 'yyyymmdd_HHMMSS');
csv_filename = ['recognition_results_', timestamp, '.csv'];
xlsx_filename = ['recognition_results_', timestamp, '.xlsx'];

% CSVとして保存
writetable(T, csv_filename, 'WriteRowNames', true);

% Excelとして保存 (Excelがインストールされている場合)
% writetable(T, xlsx_filename, 'WriteRowNames', true);

fprintf('💾 ファイルを保存しました:\n   - %s\n', csv_filename);


% === 📊 テーブル作成とExcel出力 ===

% 1. 札番号の表
T_fuda = cell2table(results_summary, 'VariableNames',{'data1','data2','data3','data4','data5'}, 'RowNames',folders);

% 2. 確定時刻の表
T_time = cell2table(times_summary, 'VariableNames',{'data1','data2','data3','data4','data5'}, 'RowNames',folders);

% ファイル名の生成
filename = ['Experiment_Results_', datestr(now, 'yyyymmdd_HHMM'), '.xlsx'];

% ExcelのSheet1に札番号、Sheet2に確定時刻を書き込み
writetable(T_fuda, filename, 'Sheet', 'Recognized_Fuda', 'WriteRowNames', true);
writetable(T_time, filename, 'Sheet', 'Recognition_Times', 'WriteRowNames', true);

fprintf('\n✅ Excelファイルを保存しました: %s\n', filename);
disp('--- 札番号結果 ---'); disp(T_fuda);
disp('--- 確定時刻結果 ---'); disp(T_time);


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