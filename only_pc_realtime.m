clear;
mfccBuffer = [];
addpath('Lee_HMM'); % 必要なパスを追加

% === ユーザー設定部分 ===
model_file = 'models_state30/iter10.mat'; % HMM学習済みモデル
Fs = 48000;
n = 0.03; % 窓長 (frame_size_sec = 30 ms)
m = 0.02; % フレームオーバーラップ（20 ms 重複）
l = 0.01; % バッファ取得時間 (10 ms)

% ⭐ ファイル保存設定 ⭐
output_dir = './kimariji_outputs';     % 保存先ディレクトリ
output_base_name = 'recog_kimariji'; % ファイル名のベース

% 変数の計算
frameLen = round(n * Fs);       % 30 ms (窓サイズ)
frame_shift_sec = n - m;        % 10 ms (フレームシフト時間)
shift    = round(frame_shift_sec * Fs); % 10 ms (フレームシフトのサンプル数)
bufLen   = round(l * Fs);       % 10 ms (オーディオ入力のサンプル数)

% === 入力デバイス設定 ===
deviceReader = audioDeviceReader('Device', 'ステレオ ミキサー (Realtek(R) Audio)', ...
    'SampleRate', Fs, ...
    'SamplesPerFrame', bufLen);

disp('Listening... (waiting for non-silent input)');

% --- リアルタイム処理バッファの初期化 ---
ringBuffer = [];

fullAudioBuffer = []; % 処理開始からの全音声データバッファ

started = false;
silenceThresh = 0.01; % 無音検出しきい値

tic
while toc < 10  % 最大30秒間に延長
    audioRecorded = deviceReader(); % 音声を取得 (10ms分)
    
    
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
    fullAudioBuffer = [fullAudioBuffer; audioRecorded]; % 全体バッファに音声データを累積
    % --- MFCC処理 ---
    if length(ringBuffer) >= frameLen
        frame = ringBuffer(1:frameLen);
        [coeffs, delta, deltaDelta] = mfcc(frame, Fs);
        
        mfcc_matrix_current_block = [coeffs, delta, deltaDelta];
        mfccBuffer = [mfccBuffer; mfcc_matrix_current_block];
        
        mfcc_matrix = mfccBuffer;
        mfccs_test = {{mfcc_matrix}};
        fprintf("MFCC computed at %.3f sec. Total frames: %d\n", toc, size(mfccBuffer, 1));
        
        ringBuffer(1:shift) = [];
        
        % --- HMM認識処理 ---
        disp('--- 2. HMM認識の実行 ---');
        mfcc_data = mfccs_test{1}{1}; 
        [recog_time_result, recog_fuda_index, posterior_result] = ...
            karuta_HMM_recog(mfcc_data, model_file, 0.9999, 0.1);
        
        % --- 結果表示 ---
        disp('--- 認識結果 ---');
        disp(['認識された札のインデックス: ', num2str(recog_fuda_index)]);
        disp(['決まり字確定フレームインデックス: ', num2str(recog_time_result)]);
        
        % ⭐⭐⭐ 決まり字確定時の音声ファイル保存ロジック ⭐⭐⭐
        if recog_fuda_index > 0 
            disp('*** 決まり字が確定しました！確定区間の音声をファイル保存します ***');
            
            % kimarijiロジックに基づいて確定時点までの秒数を計算
            kimariji_second = frame_shift_sec * (recog_time_result - 1) + n; % n=frame_size_sec
            
            % 全体の音声バッファから、その秒数に対応するサンプル数を切り出す
            kimariji_samples = ceil(kimariji_second * Fs); 
            
            % 安全のため、バッファの長さを超えないように調整
            if kimariji_samples > length(fullAudioBuffer)
                kimariji_samples = length(fullAudioBuffer);
                disp('警告: 計算されたサンプル数が現在のバッファ長を超過したため、バッファ全体を保存します。');
            end
            
            audioToSave = fullAudioBuffer(1:kimariji_samples); 
            
            try
                % 1. 保存先ディレクトリが存在しない場合は作成
                if ~exist(output_dir, 'dir')
                    mkdir(output_dir);
                end
                
                % 2. ファイル名を生成（タイムスタンプと認識インデックスを含める）
                timestamp = datestr(now, 'yyyymmddHHMMSSFFF');
                output_filename = fullfile(output_dir, ...
                    [output_base_name '_idx' num2str(recog_fuda_index) '_' timestamp '.wav']);
                
                % 3. WAVファイルとして保存
                audiowrite(output_filename, audioToSave, Fs); 
                
                disp(['ファイル保存が完了しました。保存先: ', output_filename]);
                disp(['保存音声長: ', num2str(kimariji_second), ' 秒']);
                
            catch ME_save
                disp('ファイル保存エラーが発生しました。');
                disp(['エラーメッセージ: ' ME_save.message]);
            end
            
            % 認識が確定したので、次の読み上げに備えて状態をリセット
            
        end
    end
end
release(deviceReader);
disp('処理終了');