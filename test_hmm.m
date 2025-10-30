%%% test_hmm.m (HMM認識・評価部分のみを取り出した)
clear;
addpath('Lee_HMM'); % 必要なパスを追加

% HMM認識に使用する学習済みモデルのファイルパス
model_file = 'models_state30/iter10.mat';

% ----------------------------------------------------
disp('--- 1. テストデータの特徴量抽出 (MFCC) ---');
% wav_to_mfcc を使用してテストデータの特徴量を抽出
[mfccs_test,fudas_test] = wav_to_mfcc('./aihara_test');

nfuda = length(mfccs_test);
recog_time = cell(1,nfuda);
recog_fuda = cell(1,nfuda);
posterior = cell(1,nfuda);
recog_rate = zeros(1,nfuda);

% ----------------------------------------------------
disp('--- 2. HMM認識と評価 ---');
for i=1:nfuda % 札の種類 (フォルダ) のループ
    nmfcc = length(mfccs_test{i});
    
    recog_time{i} = cell(1,nmfcc);
    recog_fuda{i} = cell(1,nmfcc);
    posterior{i} = cell(1,nmfcc);
    
    for j=1:nmfcc % 同じ札の繰り返しのループ (ファイル)
        % HMM認識を実行
        [recog_time{i}{j}, recog_fuda{i}{j}, posterior{i}{j}] = karuta_HMM_recog(mfccs_test{i}{j}, model_file, 0.99, 0.1);
        
        % 認識率を計算
        % 認識結果(recog_fuda{i}{j})が正しい札のインデックス(i)と一致するかを判定
        if recog_fuda{i}{j} == i
            recog_rate(i) = recog_rate(i) + 1/nmfcc;
        end
    end
    disp(['札 ', fudas_test{i}, ' の認識率: ', num2str(recog_rate(i)*100), '%']);
end
disp(['全体の平均認識率: ', num2str(mean(recog_rate)*100), '%']);


% ----------------------------------------------------
disp('--- 3. 決まり字区間の抽出とWAVファイル保存 ---');


% 認識結果に基づいて決まり字区間を切り出し、保存
for i=1:nfuda
    fuda = fudas_test{i};
    % 保存先フォルダを作成
    kimariji_dir = ['./aihara_realtime_kimariji/' fudas_test{i}];
    if ~exist(kimariji_dir, 'dir')
        mkdir(kimariji_dir);
    end

    for j=1:length(mfccs_test{i})
        % [y,Fs] = kimariji('./aihara_test',fuda,j,recog_time{i}{j}); は
        % 決まり字区間の音声波形を切り出す処理を行うカスタム関数と仮定
        [y,Fs] = kimariji('./aihara_test',fuda,j,recog_time{i}{j});

        % 切り出した区間を新しいWAVファイルとして保存
        filename = sprintf(['./aihara_realtime_kimariji/' fudas_test{i} '/' fudas_test{i} '%d_kimariji.wav'],j);
        audiowrite(filename, y, Fs);
    end
end
disp('決まり字区間のWAVファイル保存が完了しました。');