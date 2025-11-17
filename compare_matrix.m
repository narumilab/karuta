% === 1. ユーザー設定 ===
file1_name = 'オフライン処理_nageke1_mfcc.mat'; % 比較対象の1つ目の.matファイル名
file2_name = 'リアルタイム処理_nageke1_mfcc.mat'; % 比較対象の2つ目の.matファイル名
variable_name = 'mfcc_data'; % .matファイルに保存されている行列の変数名

% === 2. データの読み込み ===
try
    % .matファイルを読み込み、指定された変数名から行列を取得
    data1 = load(file1_name, variable_name);
    data2 = load(file2_name, variable_name);
    
    matrix1 = data1.(variable_name);
    matrix2 = data2.(variable_name);
    
catch ME
    fprintf('エラー: ファイルの読み込みまたは変数名の確認に失敗しました。\n');
    fprintf('メッセージ: %s\n', ME.message);
    return; % エラー発生時は処理を終了
end

% === 3. 形状チェック ===
[R1, C1] = size(matrix1);
[R2, C2] = size(matrix2);

if C1 ~= 42 || C2 ~= 42
    fprintf('警告: 行列の列数が42ではありません。 (data1: %d列, data2: %d列)\n', C1, C2);
end

if R1 ~= R2
    fprintf('注意: 行列の行数が異なります。(data1: %d行, data2: %d行)\n', R1, R2);
    % 比較可能なように、行数の少ない方に合わせて行列を調整
    min_rows = min(R1, R2);
    matrix1 = matrix1(1:min_rows, :);
    matrix2 = matrix2(1:min_rows, :);
else
    min_rows = R1;
end

% === 4. 比較行列の作成 ===

% 二つの行列の差を計算
difference = matrix1 - matrix2;

% 差の絶対値が非常に小さい（ほぼゼロ）かどうかを判定 (浮動小数点数対策)
tolerance = 1e-6; % 許容誤差（必要に応じて調整）
% 差が許容誤差内なら 0 (一致)、そうでなければ 1 (不一致)
mismatch_matrix = abs(difference) > tolerance;

% === 5. 結果の可視化 (ヒートマップ) ===

figure('Name', '行列比較結果の可視化', 'NumberTitle', 'off');

% === 4. 比較行列の作成 ===
% 二つの行列の差を計算
difference = matrix1 - matrix2;
% 差の絶対値を取得（ずれの「大きさ」）
absolute_difference = abs(difference);

% 差の絶対値が非常に小さい（ほぼゼロ）かどうかを判定 (浮動小数点数対策)
tolerance = 1e-6; % 許容誤差（必要に応じて調整）
% 差が許容誤差内なら 0 (一致)、そうでなければ 1 (不一致)
mismatch_matrix = absolute_difference > tolerance;

% === 5. 結果の可視化 (差の大きさのヒートマップ) ===

figure('Name', '差の絶対値ヒートマップ (ずれの大きさ)', 'NumberTitle', 'off');

% absolute_difference (差の絶対値) を画像として表示
% 差が大きいほど色が濃くなる
h_diff = imagesc(absolute_difference); 

% カラーマップの設定 (差がない場所は白、差が大きい場所は濃い色)
% 'hot' や 'jet' など、変化が分かりやすいカラーマップを使うのが一般的です。
colormap('jet'); 

% カラーバーを追加し、値の意味を説明 (差の絶対値を示す)
c = colorbar;
c.Label.String = '差の絶対値 (|matrix1 - matrix2|)';

% タイトルと軸ラベルの設定
title('オフライン vs リアルタイム MFCC 差の絶対値');
xlabel('特徴量次元 (列)');
ylabel('時間フレーム (行)');

% 軸を整数値で表示
set(gca, 'XTick', 1:C1);
set(gca, 'YTick', 1:5:min_rows); % 行数が多すぎる場合は5行おきに表示

% -----------------------------------------------------------------------

% === 6. 結果の可視化 (二値比較ヒートマップ) ===
% 以前の二値比較も残しておくと、どこが本当にゼロに近いか確認できます
figure('Name', '二値比較結果 (一致/不一致)', 'NumberTitle', 'off');
imagesc(mismatch_matrix); 
colormap([1 1 1; 1 0 0]); % [白; 赤]
c_bin = colorbar;
c_bin.Ticks = [0.25, 0.75]; 
c_bin.TickLabels = {'一致 (0)', '不一致 (1)'};
title(sprintf('二値比較 (許容誤差: %g)', tolerance));
xlabel('特徴量次元 (列)');
ylabel('時間フレーム (行)');
set(gca, 'XTick', 1:C1);
set(gca, 'YTick', 1:5:min_rows); 


% === 7. 統計結果 ===
% 最後に、行ごとの一致/不一致の割合を計算 (ロジックは変更なし)
rows_mismatched = sum(any(mismatch_matrix, 2)); % 1つでも不一致な要素を含む行数
total_rows = min_rows;
fprintf('\n--- 統計結果 ---\n');
fprintf('総行数（フレーム数）: %d\n', total_rows);
fprintf('完全に一致した行数: %d\n', total_rows - rows_mismatched);
fprintf('1つでも不一致な要素を含む行数 (許容誤差 %g): %d\n', tolerance, rows_mismatched);