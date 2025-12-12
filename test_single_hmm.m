%単一ファイル用のtestを実行する
clear;
tic
addpath('Lee_HMM'); % 必要なパスを追加
% === ユーザー設定部分 ===
% HMM認識に使用する学習済みモデルのファイルパス
model_file = 'models_state30/iter10.mat';
% 認識対象の単一の音声ファイルパス
% 例: './aihara_test/tsu/tsu1.wav' のように、フォルダ名とファイル名を含む完全なパスを指定してください。
input_wav_path = './aihara_test/ooke/ooke1.wav'; 
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
    %mfcc_matrix = extract_single_mfcc(y, Fs);
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
