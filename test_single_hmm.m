%単一ファイル用のtestを実行する
clear;
tic
addpath('Lee_HMM'); % 必要なパスを追加
% === ユーザー設定部分 ===
% HMM認識に使用する学習済みモデルのファイルパス
model_file = 'models_state30/iter10.mat';
% 認識対象の単一の音声ファイルパス
% 例: './aihara_test/tsu/tsu1.wav' のように、フォルダ名とファイル名を含む完全なパスを指定してください。
input_wav_path = './aihara_test/nageke/nageke1.wav'; 
% 決まり字区間の保存先ディレクトリとファイル名（元のスクリプトを踏襲）
output_dir = './aihara_realtime_kimariji_single';
output_base_name = 'kimariji_output'; % 保存ファイル名のベース
% ========================
% ----------------------------------------------------
disp('--- 1. 単一テストファイルの特徴量抽出 (MFCC) ---');
try
    % 音声ファイルを読み込み
    [y, Fs] = audioread(input_wav_path);
    
    % 'extract_single_mfcc' 関数は別ファイル (extract_single_mfcc.m) で定義されています。
    mfcc_matrix = extract_single_mfcc(y, Fs);
    
    % karuta_HMM_recogが要求する形式に合わせる: {{MFCC行列}}
    mfccs_test_single = {{mfcc_matrix}}; 
    
    
    % ファイルパスから情報を抽出
    % 例: input_wav_path = './aihara_test/nageke/nageke1.wav'
    [dirPath, fileName, ~] = fileparts(input_wav_path);
    
        
    % base_dir_for_kimariji (wavdir, 例: './aihara_test') は dirPath の親ディレクトリ
    base_dir_for_kimariji = fileparts(dirPath); 
    
    % fuda_name (札名フォルダ名、例: 'nageke') は dirPath の最後のディレクトリ名
    % [~, name, ~] = fileparts(path) を使用して最後のディレクトリ名を取得
    [~, fuda_name, ~] = fileparts(dirPath); 
    % file_num (ファイルインデックス、例: 'nageke1' -> 1) をファイル名から抽出
    file_num_str = regexp(fileName, '\d+$', 'match', 'once');
    if isempty(file_num_str)
        file_num = 1; % 数字がない場合はデフォルトで1
    else
        file_num = str2double(file_num_str);
    end
    
catch ME
    disp(['エラー: 特徴量抽出中に問題が発生しました。']);
    disp(['エラーメッセージ: ' ME.message]);
    % 続行できないため終了
    return; 
end
disp(['特徴量抽出が完了しました。ファイル: ' input_wav_path]);
disp(['kimariji関数への引数情報: wavdir=', base_dir_for_kimariji, ', fuda=', fuda_name, ', num=', num2str(file_num)]);
% ----------------------------------------------------
disp('--- 2. HMM認識の実行 ---');
% HMM認識を実行（単一ファイルなのでループ不要）
mfcc_data = mfccs_test_single{1}{1};
disp(mfcc_data)% MFCC行列を取得
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
% ----------------------------------------------------
disp('--- 3. 決まり字区間の抽出とWAVファイル保存 ---');
% 保存先フォルダを作成
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end
try
    % kimariji(wavdir, fuda, num, kimariji_frame) を呼び出し
    % wavdir: './aihara_test' (base_dir_for_kimariji)
    % fuda: 'nageke' (fuda_name)
    % num: 1 (file_num)
    % kimariji_frame: recog_time_result (HMM認識結果のフレームインデックス)
  
    [y_kimariji, Fs_kimariji] = kimariji(base_dir_for_kimariji, fuda_name, file_num, recog_time_result);
    
    % 切り出した区間を新しいWAVファイルとして保存
    % 認識インデックス (recog_fuda_index) の代わりに、ファイル番号 (file_num) を使用します。
    output_filename = fullfile(output_dir, [output_base_name '_' fuda_name '_fileidx' num2str(file_num) '.wav']);
    audiowrite(output_filename, y_kimariji, Fs_kimariji);
    
    disp(['決まり字区間のWAVファイル保存が完了しました。']);
    disp(['保存先: ', output_filename]);
catch ME
    disp('エラー: 決まり字区間の抽出または保存に失敗しました。');
    disp(['エラーメッセージ: ' ME.message]);
end
% ----------------------------------------------------------------------
% 注: karuta_HMM_recog 関数は外部のカスタムファイルに依存しています。
% 
% kimariji.m および extract_single_mfcc.m は、このファイルとは別の外部ファイルとして
% MATLABのパス上に存在している必要があります。
% ----------------------------------------------------------------------
% ----------------------------------------------------
disp('--- 4. リアルタイムMFCCとの比較と一致率の定量化 ---');

% ⭐ ユーザー設定: リアルタイム処理で保存されたMFCCファイルへのパス ⭐
% (必要に応じて、このパスを修正してください)
mfcc_realtime_file = './kimariji_outputs/all_mfcc_features.mat'; 

% 単一ファイルMFCC行列をAとする
mfcc_A = mfcc_data; 
    
% ⭐ リアルタイム処理で保存されたMFCCデータをロード ⭐
if exist(mfcc_realtime_file, 'file')
    loaded_data = load(mfcc_realtime_file, 'all_mfcc_data'); 
    mfcc_B = loaded_data.all_mfcc_data; % リアルタイム累積MFCC (B)
    
    % ⭐ 比較するフレーム数の決定 (短い方に合わせる) ⭐
    min_frames = min(size(mfcc_A, 1), size(mfcc_B, 1));
    
    if min_frames == 0
        disp('MFCC行列のサイズがゼロのため、比較できませんでした。');
        % 続行できないため終了
        return; 
    end
    
    % 比較する範囲にトリミング
    mfcc_A_crop = mfcc_A(1:min_frames, :);
    mfcc_B_crop = mfcc_B(1:min_frames, :);
    
    % ⭐ 差分行列の計算 (一致部分を可視化するための基礎) ⭐
    mfcc_diff = abs(mfcc_A_crop - mfcc_B_crop);
    
    % ⭐ 一致率の定量化 (平均絶対誤差: MAE) ⭐
    average_diff = mean(mfcc_diff(:));
    
    fprintf('--------------------------------------------------\n');
    fprintf('  比較フレーム数: %d\n', min_frames);
    fprintf('  MFCCの平均絶対誤差 (MAE): %.8f\n', average_diff);
    fprintf('  => この値が小さいほど、両者のMFCCは一致しています。\n');
    fprintf('--------------------------------------------------\n');

    % ⭐ 5. 可視化: 3つのヒートマップを並べて表示 ⭐
    figure('Position', [100, 100, 1200, 400]); 
    
    % カラーバーのスケールを固定するため、全データの最小/最大を計算
    min_val = min([mfcc_A_crop(:); mfcc_B_crop(:)]);
    max_val = max([mfcc_A_crop(:); mfcc_B_crop(:)]);
    
    % === Subplot 1: 単一ファイル処理 MFCC (A) ===
    subplot(1, 3, 1);
    imagesc(mfcc_A_crop'); 
    caxis([min_val, max_val]); % スケール統一
    colormap('jet');
    title('1. Single-File MFCC (A)');
    xlabel('Time Frame');
    ylabel('MFCC Dimension');
    axis tight;
    
    % === Subplot 2: リアルタイム処理 MFCC (B) ===
    subplot(1, 3, 2);
    imagesc(mfcc_B_crop'); 
    caxis([min_val, max_val]); % スケール統一
    colormap('jet');
    title('2. Real-Time MFCC (B)');
    xlabel('Time Frame');
    axis tight;
    
    % === Subplot 3: 差分 (一致部分の可視化) ===
    subplot(1, 3, 3);
    imagesc(mfcc_diff'); 
    colormap('hot'); % 差分が大きいほど明るく（熱く）
    colorbar;
    title(['3. Absolute Difference (A - B), MAE: ' num2str(average_diff, '%.4f')]);
    xlabel('Time Frame'); 
    
    % 差分ヒートマップの説明
    disp('*** 差分ヒートマップの見方 ***');
    disp('   色が「濃い（黒に近い）」部分が、MFCC値が**一致している**（差分が非常に小さい）箇所です。');
    disp('   色が「明るい（白に近い）」部分が、MFCC値が**大きく異なっている**箇所です。');
    
else
    disp(['エラー: リアルタイム処理MFCCファイル (', mfcc_realtime_file, ') が見つかりません。']);
end
% ----------------------------------------------------