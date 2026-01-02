% --- ノードの定義 ---
% 1:START, 2:S1, 3:S2, 4:... , 5:SN
nodeNames = {'START', 'S1', 'S2', '...', 'SN'};

% --- エッジ（つながり）の定義 ---
s = [1, 2, 2, 3, 3, 4, 4, 5]; 
t = [2, 2, 3, 3, 4, 4, 5, 5];

% --- 記号ラベルの定義 ---
% 自己遷移を a_ii, 次の状態への遷移を a_ij と表記
edgeLabels = {'\pi_1=1', 'a_{11}', 'a_{12}', 'a_{22}', 'a_{23}', 'a_{ii}', 'a_{i,N}', 'a_{NN}'};

% 内部計算用のダミーウェイト（接続関係を維持するため）
weights = ones(size(s));

% --- グラフ作成 ---
G = digraph(s, t, weights);
G.Nodes.Name = nodeNames';

% --- 描画 ---
figure('Color', 'w');
h = plot(G, 'Layout', 'layered', 'Direction', 'right', ...
    'LineWidth', 1.5, 'MarkerSize', 10, 'NodeFontSize', 12);

% ラベルに記号（TeX形式）を割り当て
h.EdgeLabel = edgeLabels;

% --- デザイン調整 ---
% STARTノードを赤系で強調
highlight(h, 'START', 'NodeColor', [0.9 0.4 0.4]);
% 状態ノードを青系で強調
highlight(h, {'S1', 'S2', 'SN'}, 'NodeColor', [0.3 0.6 0.9]);
% 省略ノードは小さく目立たなくする
highlight(h, '...', 'NodeColor', [0.6 0.6 0.6], 'MarkerSize', 4);

% グラフの装飾
title('状態１のみ確率１の隠れマルコフモデル(HMM)', 'FontSize', 14);
axis off;

% ラベルのフォントサイズ調整
h.EdgeFontSize = 11;

% --- ノードの定義 (斜体 \it) ---
nodeNames = {'\it START', '\it S_1', '\it S_2', '...', '\it S_N'};

% --- エッジ（つながり）の定義 ---
% 1:START, 2:S1, 3:S2, 4:... , 5:SN
s_init = [1, 1, 1, 1]; % STARTから全状態へ
t_init = [2, 3, 4, 5];

s_trans = [2, 2, 3, 3, 4, 4, 5]; % 状態間の遷移
t_trans = [2, 3, 3, 4, 4, 5, 5];

s = [s_init, s_trans];
t = [t_init, t_trans];
selfLoopIdx = (s == t);

% --- 記号ラベルの定義 ---
edgeLabels = {'1/N', '1/N', '1/N', '1/N', ... 
              'a_{11}', 'a_{12}', 'a_{22}', 'a_{23}', 'a_{ii}', 'a_{i,N}', 'a_{NN}'};

% --- グラフ作成 ---
G = digraph(s, t, ones(size(s)));
G.Nodes.Name = nodeNames';

% --- 描画 ---
figure('Color', 'w');
h = plot(G, 'LineWidth', 1.5, 'MarkerSize', 12, 'NodeFontSize', 12, 'Interpreter', 'tex');

% --- ★配置の調整★ ---
% X座標: S1~SNを等間隔(2,4,6,8)に並べ、STARTをその中央(5)に配置
% Y座標: 状態をすべて0（水平）にし、STARTだけを上(1.5)に配置
h.XData = [5,  2,  4,  6,  8]; 
h.YData = [1.5, 0,  0,  0,  0]; 

% --- ラベルと矢印サイズの調整 ---
h.EdgeLabel = edgeLabels;
h.EdgeFontSize = 10;
arrowSizes = ones(size(s)) * 11; 
arrowSizes(selfLoopIdx) = 6; % 自己推移を小さく
h.ArrowSize = arrowSizes;

% --- デザイン調整 ---
highlight(h, '\it START', 'NodeColor', [0.9 0.4 0.4]);
highlight(h, {'\it S_1', '\it S_2', '...', '\it S_N'}, 'NodeColor', [0.3 0.6 0.9]);
highlight(h, '...', 'MarkerSize', 6);

title('初期状態一様分布（1/N）のHMM構造図', 'FontSize', 14, 'Interpreter', 'tex');
axis off;