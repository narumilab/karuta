clear; clc;

% === ユーザー設定 ===
input_wav_path = './aihara_test/ooke/ooke1.wav'; % 元のファイルパス
output_wav_path = 'output_cut_0.3s.wav';             % 保存するファイルパス
target_sec = 0.3;                                    % 切り出す秒数 (0.3秒)

% === 処理 ===
try
    % 1. 音声を読み込む
    [y, Fs] = audioread(input_wav_path);
    
    % 2. 0.3秒分のサンプル数を計算
    target_samples = round(target_sec * Fs);
    
    % 3. 切り出し処理 (ファイルが短い場合の安全策付き)
    if size(y, 1) > target_samples
        % 指定サンプル数までを切り出し (ステレオ対応のため : を使用)
        y_cut = y(1:target_samples, :);
        fprintf('音声ファイルを %.2f 秒 (サンプル数: %d) にカットしました。\n', target_sec, target_samples);
    else
        % 元の音声が0.3秒より短い場合はそのまま使う
        y_cut = y;
        fprintf('⚠️ 警告: 元の音声が %.2f 秒未満 (%.3f秒) でした。カットせずそのまま保存します。\n', target_sec, size(y,1)/Fs);
    end
    
    % 4. ファイル保存
    audiowrite(output_wav_path, y_cut, Fs);
    disp(['✅ 保存完了: ', output_wav_path]);

catch ME
    disp('❌ エラーが発生しました:');
    disp(ME.message);
end