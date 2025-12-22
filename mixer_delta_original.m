clear;
addpath('Lee_HMM'); 

% === ユーザー設定 ===
model_file = 'models_state30/iter10.mat'; 
Fs_model = 44100; % モデルのサンプリング周波数に合わせる
input_gain = 2.0; % 音が小さい場合の増幅倍率

% --- 無音判定パラメータ ---
silenceThresh = 0.02; % この振幅以下を無音とみなす（環境に合わせて調整）
silence_limit = 50;   % 何フレーム無音（10ms×50=0.5秒）が続いたらリセットするか
% -----------------------
started = false; % 音声検知フラグ
silence_counter = 0; % 無音フレームカウンタ

% 認識パラメータ
threshold = 0.999; % 確定しきい値
w = 0.1;           % 重み
context_duration = 0.19; % MFCC計算に使う窓長 (190ms)
shift_sec = 0.01;        % シフト量 (10ms)

% === HMM初期化 ===
load(model_file, 'mean_vec_i_m', 'var_vec_i_m', 'a_i_j_m');
model_dim = size(mean_vec_i_m, 1); 
num_fuda = size(mean_vec_i_m, 3); 
N = size(mean_vec_i_m, 2); 

% 状態管理変数の初期化（ループの外で保持し続ける）
ll = zeros(num_fuda, 1); 
filt = zeros(N, num_fuda); 
filt(1, :) = 1.0; 
fuda_last_reported = 0;
accumulated_frame_count = 0;

% === オーディオデバイス設定 (ステレオミキサー) ===
% デバイス名は 'audioDeviceReader.getAudioDevices()' で確認した名前に適宜書き換えてください
try
    deviceReader = audioDeviceReader(...
        'Device', 'ステレオ ミキサー (Realtek(R) Audio)', ... 
        'SampleRate', Fs_model, ...
        'SamplesPerFrame', round(shift_sec * Fs_model)); 
    disp('✅ ステレオミキサーに接続成功。解析を開始します。');
catch
    disp('⚠️ ステレオミキサーが見つかりません。デバイスリストを表示します：');
    disp(audioDeviceReader.getAudioDevices());
    return;
end
% 状態変数の関数化（リセット用）
reset_hmm = @() deal(zeros(num_fuda, 1), [ones(1, num_fuda); zeros(N-1, num_fuda)]);
[ll, filt] = reset_hmm();

% バッファ準備
frameLen = round(context_duration * Fs_model);
ringBuffer = [];
fullAudioBuffer = [];
output_dir = './kimariji_outputs_online';

disp('🎤 PCで音声を再生してください... (Ctrl+C で終了)');
tic;

% === メインリアルタイムループ ===
while true
    % 1. 音声の取得
    acquiredAudio = deviceReader();
    
    % ステレオならモノラル化
    if size(acquiredAudio, 2) > 1
        acquiredAudio = mean(acquiredAudio, 2);
    end
    
    % 増幅
    acquiredAudio = acquiredAudio * input_gain;
    % 現在のブロックの音量（RMS）を計算
    rmsVal = sqrt(mean(acquiredAudio.^2));
    
    % --- 無音/有音の判定ロジック ---
    if rmsVal > silenceThresh
        % 【有音】
        if ~started
            disp('>>> 🎵 音声を検知：HMMをリセットして解析開始');
            [ll, filt] = reset_hmm(); % 読み上げ開始時に真っさらにする
            fullAudioBuffer = [];
            started = true;
        end
        silence_counter = 0;
    else
        % 【無音】
        if started
            silence_counter = silence_counter + 1;
            if silence_counter > silence_limit
                disp('<<< 🔇 無音を検知：待機状態に戻ります');
                started = false;
                % ここで必要なら「確定しなかったが録音したデータ」を捨てる等の処理
            end
        end
    end

    % --- 解析処理（音声検知時のみ実行） ---
    if started
    % リングバッファと保存用バッファへ蓄積
        ringBuffer = [ringBuffer; acquiredAudio];
        fullAudioBuffer = [fullAudioBuffer; acquiredAudio];
        
        % 2. MFCC抽出 (バッファが窓長に達したら実行)
        if length(ringBuffer) >= frameLen
            frame = ringBuffer(1:frameLen);
            
            % MFCC計算
            [coeffs, delta, deltaDelta] = mfcc(frame, Fs_model);
            mfcc_feat = [coeffs, delta, deltaDelta];
            
            % HMMには最新の1フレーム(最後尾)を渡す
            mfcc_data = mfcc_feat(end, 1:model_dim)'; 
            accumulated_frame_count = accumulated_frame_count + 1;

            % 3. HMM 尤度計算 (1フレーム分)
            for k = 1:num_fuda
                pred = filt(:,k)' * a_i_j_m(:,:,k);
                l_val = 0;
                
                % 出力確率の計算
                for i = 2:N-1 
                    emission_prob = exp(logDiagGaussian(mfcc_data, ...
                        mean_vec_i_m(:,i,k), var_vec_i_m(:,i,k)));
                    l_val = l_val + pred(i) * emission_prob;
                    filt(i,k) = pred(i) * emission_prob;
                end
                
                % 累積対数尤度の更新 (epsで数値安定化)
                ll(k) = ll(k) + log(l_val + eps);
                
                % 前方確率の正規化
                sum_f = sum(filt(:,k));
                if sum_f > 0
                    filt(:,k) = filt(:,k) / sum_f;
                else
                    filt(1,k) = 1.0; % 異常時は初期化
                end
            end
            
            % 4. 事後確率 (Posterior) の計算
            posterior = exp(w * (ll - max(ll)));
            posterior = posterior / sum(posterior);
            
            [max_p, max_idx] = max(posterior);
            
            % 5. 認識結果の表示と確定処理
            if max_p > 0.1 % 低すぎる時は表示しない
                fprintf('Frame %d | 候補: 札%d (%.1f%%)\n', ...
                    accumulated_frame_count, max_idx, max_p*100);
            end
            
            if max_p > threshold && max_idx ~= fuda_last_reported
                fuda_last_reported = max_idx;
                disp(['🎯 ★確定★ 札番号: ', num2str(max_idx)]);
                
                % 確定音声を保存
                save_recog_audio(fullAudioBuffer, Fs_model, max_idx, output_dir);
            end

            % リングバッファをシフト
            shift_samples = round(shift_sec * Fs_model);
            ringBuffer(1:shift_samples) = [];
        end
    end

end  