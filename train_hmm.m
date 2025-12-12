%%% train_hmm.m (HMM学習部分のみを取り出した）
clear;
addpath('Lee_HMM'); % 必要なパスを追加

disp('--- 1. 学習データの特徴量抽出 (MFCC) ---');
% wav_to_mfcc を使用して学習データの特徴量を抽出
%[mfccs_train,fudas_train] = wav_to_mfcc('./aihara_train');
[mfccs_train,fudas_train] = wav_to_mfcc('./aihara_train');

disp('--- 2. HMMモデルの学習 ---');
% karuta_HMM_train を実行してモデルを学習・保存
% (この関数内でモデルファイルが 'models_state30/iter10.mat' のような名前で保存されると仮定)
% karuta_HMM_train(mfccs_train, 状態数, 反復回数);
karuta_HMM_train(mfccs_train, 30, 10);

disp('学習プロセスが完了しました。モデルは models_state30/iter10.mat に保存されています。');