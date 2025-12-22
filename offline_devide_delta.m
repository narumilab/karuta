clear;
% HMM関数 karuta_HMM_recog_realtime がパス上にあることを前提とします。
addpath('Lee_HMM'); 
% === ユーザー設定部分 ===
model_file = 'models_state30/iter10.mat'; % HMM学習済みモデル 

n = 0.03; % 窓長 (30 ms)
m = 0.02; % オーバーラップ (20 ms)
l = 0.01; % バッファ取得時間 (10 ms)
threshold = 0.9999;
w = 0.1;
% ⭐ ファイル保存設定 ⭐
output_dir = './kimariji_outputs_offline';     
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
% === HMM状態の初期化 ===
shift_fix = 0;
% ⭐ 変更 1: recog_locked フラグは不要になるか、処理を制御するために残す ⭐
recog_locked = false;                 % ファイル保存の重複防止用として維持

   % 10 ms 
%単一ファイル用のtestを実行する
ringBuffer = [];
fullAudioBuffer = [];% ファイル保存のために全音声データを累積
fullmfcc = [];
started = false;

mfcc_before = zeros(1,14);
delta_before = zeros(1,14);

% ⭐ 追加 1: オーバーラン情報を記録するリストを初期化 ⭐
% [フレーム番号, 時刻 (s), 欠落サンプル数] を格納
overrun_log = {};
check_data = 0;
tic


% === ユーザー設定部分 ===


% 認識対象の単一の音声ファイルパス

% 例: './aihara_test/tsu/tsu1.wav' のように、フォルダ名とファイル名を含む完全なパスを指定してください。

input_wav_path = './aihara_test/nageke/nageke1.wav'; 

% ========================

% ----------------------------------------------------



%% === 1. 単一ファイルの特徴量抽出 (MFCC) の代替処理 ===

disp('--- 1. 単一テストファイルの特徴量抽出 (MFCC) ---');



% (1) ファイル全体を一度読み込む（初期データ取得）

[y, Fs] = audioread(input_wav_path);

audio_data = y; % 処理対象のデータ
% === 変数の計算 ===
x =1;
frameLen = round(n * x * Fs);% 30 ms 
shift_check = round(m * Fs);
frame_shift_sec = n - m;        % 10 ms 
shift    = round(frame_shift_sec * Fs); % 10 ms 
bufLen   = round(l * Fs);    
% 1. 音声ファイルの読み込み
% [y, Fs] = audioread('ファイル名.wav');
% 例: 'sample.wav'というファイルがある場合
% 音声データyとサンプリング周波数Fsを取得

% 2. 時間軸データの作成
% データ長 n を取得
n = length(y);
% 時間ベクトル t を作成
t = (0:n-1) / Fs; % 時刻の系列を作成

% 3. 波形のプロット

plot(t, y);
xlabel('Time (s)'); % x軸ラベル（時間）
ylabel('Amplitude'); % y軸ラベル（振幅）
title('Audio Waveform'); % グラフタイトル
grid on; % グリッド表示


% (2) 10msブロックのサイズを計算

block_duration_sec = 0.01; % 0.01 10ms

block_size = round(Fs * block_duration_sec); 

total_samples = length(audio_data);

disp(['シミュレーション開始。Fs: ', num2str(Fs), ' Hz, 10msブロックサイズ: ', num2str(block_size), ' サンプル']);

    

    % (3) 10msごとにデータを切り出し、MFCC処理をシミュレート

for start_idx = 1:block_size:(total_samples - block_size + 1)

    

    % 10msの音声データを切り出し

    current_block = audio_data(start_idx : start_idx + block_size - 1);

    

    % リアルタイム処理のシミュレーション（ここで実際の処理を記述）

    

    % HMM認識のためのMFCC抽出処理（仮の関数呼び出し）

    % ringBufferに蓄積し、一定の長さ（例：30ms）になったらmfcc(frame, Fs)を実行

    ringBuffer = [ringBuffer; current_block];

    

    % ここに、ご提示の後半のコード（MFCC処理、HMM認識）を組み込みます。

    

    % 一時停止してリアルタイム処理をシミュレート

    % pause(block_duration_sec); 







    fullAudioBuffer = [fullAudioBuffer; current_block]; % ファイル保存のため累積
    g = length(ringBuffer);
   
    % --- MFCC処理 ---
    if length(ringBuffer) >= frameLen
        frame = ringBuffer(1:frameLen);
        a = length(ringBuffer);
        c = length(frame);
        %mfccの計算
        [coeffs] = mfcc(frame, Fs);
        mfcc_current = coeffs;
        delta = mfcc_current-mfcc_before;
        deltaDelta = delta - delta_before;
        mfcc_matrix_current_block = [coeffs, delta, deltaDelta];
        mfcc_before = mfcc_current;
        delta_before = delta; 
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
            check_data = check_data + 1;

            
        end
        % --- HMM認識処理 ---
        % ⭐ 変更 2: recog_locked を使わず、常に認識を試みる ⭐
        disp('--- 2. HMM認識の実行 ---');
        
        % 状態変数を渡し、結果を受け取る 
%        [recog_time_relative, recog_fuda_index, posterior_result, current_ll_matrix, current_filt] = ...
%            karuta_HMM_recog_realtime2(mfcc_data, model_file, threshold, w, before_ll, before_filt);
        p=size(mfcc_data,2);
        for s=1:size(mfcc_data,2)
            
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
            
            % *** HMM状態リセット処理はここには追加しません ***
        end
        
        % ⭐ 追加: ファイル保存後も、HMMの状態は before_ll と before_filt を介して次のループに引き継がれる
    end
end


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

fprintf('バッファサイズを　%d 回調節しました', shift_fix);

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

fprintf('欠落が　%d 回おきました', check_data);