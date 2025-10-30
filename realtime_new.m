clear;
mfccBuffer = [];


addpath('Lee_HMM'); % 必要なパスを追加
% === ユーザー設定部分 ===
% HMM認識に使用する学習済みモデルのファイルパス
model_file = 'models_state30/iter10.mat';
Fs = 48000;
n = 0.03; %窓長
m = 0.02; %フレームシフト
l = 0.01;
frameLen = round(n * Fs);   % n=0.03, 30 ms = 1440 samples
shift    = round((n-m) * Fs);   %m = 0.02
bufLen   = round(l * Fs);      

%audio_interface_name:'ZOOM UAC-2 ASIO Driver'
aPR = audioPlayerRecorder('Device', 'ZOOM UAC-2 ASIO Driver', ... 
    'SampleRate', Fs, ...
    'BufferSize', bufLen, ...
    'RecorderChannelMapping', 1, ...
    'PlayerChannelMapping', 1);



out_buf = zeros(bufLen,1);
ringBuffer = zeros(0,1);

started = false;       % 無音→音声を検知したかどうか
silenceThresh = 0.01;  % 無音判定のしきい値（RMS）
silenceCount = 0;      % 連続無音検出カウンタ

disp("Listening... (waiting for non-silent input)");

tic
while toc < 5   % 10 秒間モニタ
    [audioRecorded, ~, ~] = aPR(out_buf);
    
    
    % --- 無音判定 ---
    rmsVal = sqrt(mean(audioRecorded.^2));
    if ~started
        if rmsVal > silenceThresh
            started = true;
            disp("Sound detected! Starting MFCC processing...");
        else
            continue;  % まだ無音なので何もしない
        end
    end
    ringBuffer = [ringBuffer; audioRecorded];
    % --- MFCC処理 ---
    if length(ringBuffer) >= frameLen
        frame = ringBuffer(1:frameLen);
        [coeffs, delta, deltaDelta] = mfcc(frame, Fs);
        % 3. フレーム特徴量の結合: 
        % 各特徴量行列を横に結合し、フレームごとの特徴量行列（N x 39）を作成
        % これが、今回累積したい「mfcc_matrix」に相当します。
        mfcc_matrix_current_block = [coeffs, delta, deltaDelta];
        
        % 4. 特徴量バッファへの累積 (時間方向に行を追加)
        % mfccBufferに新しいMFCCフレームをどんどん追加します。
        mfccBuffer = [mfccBuffer; mfcc_matrix_current_block];
        mfcc_matrix = mfccBuffer;
        mfccs_test = {{mfcc_matrix}};
        fprintf("MFCC computed at %.3f sec\n", toc);
        ringBuffer(1:shift) = [];
        disp('--- 2. HMM認識の実行 ---');
        % HMM認識を実行（単一ファイルなのでループ不要）
        mfcc_data = mfccs_test{1}{1}; 
        disp(mfcc_data)% MFCC行列を取得
        % karuta_HMM_recog(MFCCデータ, モデルファイル, スコア閾値, 時間閾値)
        % karuta_HMM_recog と extract_single_mfcc は外部ファイルに依存します。
        [recog_time_result, recog_fuda_index, posterior_result] = karuta_HMM_recog(mfcc_data, model_file, 0.9999, 0.1);
        %disp(mfcc_data)
        % 認識結果の表示
        disp('--- 認識結果 ---');
        disp(['認識された札のインデックス: ', num2str(recog_fuda_index)]);
        % ⭐ 決まり字が確定したフレームインデックスの表示を追加
        disp(['決まり字確定フレームインデックス: ', num2str(recog_time_result)]); 
        
        % ----------------------------------------------------
    end
end

release(aPR);


