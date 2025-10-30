 １：音声データの準備

札ごとにwavファイルをまとめたフォルダを作成（例：aihara_train）

２：mfcc特徴量の計算

[mfccs,fudas]=wav_to_mfcc('./aihara_train')

mfccs{i}{j}：i番目の札のj番目の音声データのmfcc（フレーム数×mfcc次元の行列）
fudas{i}：i番目の札の名前（例：'ooe'、'wasura'）

３：隠れマルコフモデルの学習

karuta_HMM_train(mfccs,30,10)

第1引数：学習データのmfccを格納したセル配列
第2引数：隠れ状態数（元論文は50だが30でも十分そう）
第3引数：EMアルゴリズムの反復数（大きいほど時間はかかるが学習は進む）

学習したモデルはmodels_state30に保存されていく（例：10反復目のモデルはiter10.mat）

４：札の判別

[recog_time,recog_fuda,posterior]=karuta_HMM_recog(mfcc,'models_state30/iter10.mat',0.99,0.1)

第1引数：テストデータのmfcc
第2引数：判別に用いるモデルのパス
第3引数：判別の閾値（事後確率がこの値を超えたら札を取る）
第4引数：事後分布（power posterior）における尤度の重み（通常のベイズ推論は1に相当、どうやら0.1くらいにした方が安定するっぽい）

recog_time{i}{j}：i番目の札のj番目の音声データに対して札を判別した時点（フレーム番号）
recog_fuda{i}{j}：i番目の札のj番目の音声データに対して判別した札
posterior{i}{j}：i番目の札のj番目の音声データに対する各時点での札の事後確率（札の個数×フレーム数の行列）

５：決まり字で切り取ったwavデータ

kimariji('./aihara_test',fudas{i},j,recog_time{i}{j})
