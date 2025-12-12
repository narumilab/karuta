%単一ファイル用のtestを実行する
clear;
tic
addpath('Lee_HMM'); % 必要なパスを追加
% === ユーザー設定部分 ===
% HMM認識に使用する学習済みモデルのファイルパス
% === ユーザー設定部分 ===
model_file = 'models_state30/iter10.mat'; % HMM学習済みモデル 
%Fs = 48000;
Fs = 44100;
n = 0.03; % 窓長 (30 ms)
m = 0.02; % オーバーラップ (20 ms)
l = 0.01; % バッファ取得時間 (10 ms)
threshold = 0.9999;
w = 0.1;

% === HMM状態の初期化 ===
load(model_file, 'mean_vec_i_m', 'var_vec_i_m', 'a_i_j_m');
num_fuda = size(mean_vec_i_m, 3); % 札数 (K)
N = size(mean_vec_i_m, 2);      % 状態数 (N)

accumulated_frame_count = 0;          % 累積フレーム数



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
fullAudioBuffer = []; 
mfcc_matrix2 = [];% ファイル保存のために全音声データを累積
started = false;
silenceThresh = 0.0001470000014; 
tic

while toc < 5 % 時間を30秒間に延長 (認識が継続するため)
    [audioRecorded, numOverrun] = deviceReader(); % 音声を取得 (10ms分)
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
    
    ringBuffer = [ringBuffer; audioRecorded]; 
    fullAudioBuffer = [fullAudioBuffer; audioRecorded]; % ファイル保存のため累積
end  
% --- MFCC処理 ---
while length(ringBuffer) >= frameLen
    frame = ringBuffer(1:frameLen);
    [coeffs, delta, deltaDelta] = mfcc(frame, Fs);
    
    mfcc_matrix_current_block = [coeffs, delta, deltaDelta];
    
    % ⭐ 修正 1: HMMには最新の1フレームのみを渡す (次元数 x 1 に転置)
    mfcc_current = mfcc_matrix_current_block; 
    mfcc_matrix2 = [mfcc_matrix2; mfcc_current];
    mfccs_test_single = {{mfcc_matrix2}}; 
  
    
    ringBuffer(1:shift) = []; % 窓長 (30ms) からシフト量 (10ms) 分を削除
end

disp(['特徴量抽出が完了しました。']);

% ----------------------------------------------------
disp('--- 2. HMM認識の実行 ---');
% HMM認識を実行（単一ファイルなのでループ不要）
%mfcc_data = mfccs_test_single{1}{1}
mfcc_data = mfcc_matrix2;
%disp(mfcc_data)% MFCC行列を取得
% karuta_HMM_recog(MFCCデータ, モデルファイル, スコア閾値, 時間閾値)
% karuta_HMM_recog と extract_single_mfcc は外部ファイルに依存します。
[recog_time_result, recog_fuda_index, posterior_result] = karuta_HMM_recog(mfcc_data, model_file, 0.99, 0.1);
%disp(mfcc_data)
% 認識結果の表示
disp('--- 認識結果 ---');
disp(['認識された札のインデックス: ', num2str(recog_fuda_index)]);
% ⭐ 決まり字が確定したフレームインデックスの表示を追加
disp(['決まり字確定フレームインデックス: ', num2str(recog_time_result)]); 
toc
