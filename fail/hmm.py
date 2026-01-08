import numpy as np
from hmmlearn import hmm

# 1. モデルの設定
# 状態数: 3 (State 0, State 1, State 2)
# 観測シンボル数: 2 (例: 0=不調, 1=好調)
n_states = 3
n_features = 2

# モデルの初期化（CategoricalHMM: 離散的な観測を扱うモデル）
model = hmm.CategoricalHMM(n_components=n_states)

# --- ここがポイント：初期状態確率 (pi) ---
# 状態0 (State 1) から必ず始まるように設定
# [1.0, 0.0, 0.0] とすることで、最初の状態を固定します
model.startprob_ = np.array([1.0, 0.0, 0.0])

# 2. 状態遷移確率 (A) の設定
# 各行の合計が 1.0 になる必要があります
model.transmat_ = np.array([
    [0.7, 0.2, 0.1], # State 0 からの遷移率
    [0.3, 0.5, 0.2], # State 1 からの遷移率
    [0.3, 0.3, 0.4]  # State 2 からの遷移率
])

# 3. 観測確率 (B) の設定 (各状態からどのシンボルが出るか)
model.emissionprob_ = np.array([
    [0.1, 0.9], # State 0 は 90% の確率でシンボル1を出す
    [0.5, 0.5], # State 1 は 50% ずつ
    [0.8, 0.2]  # State 2 は 80% の確率でシンボル0を出す
])

# --- 動作確認：データを10ステップ生成してみる ---
X, Z = model.sample(10)

print("生成された観測シーケンス (X):")
print(X.flatten())
print("\n内部で遷移した状態の推移 (Z):")
print(Z)

# 最初の状態が必ず 0 になっていることを確認
if Z[0] == 0:
    print("\n検証結果: 期待通り状態0 (状態1) から開始されました。")