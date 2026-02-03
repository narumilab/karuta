% plot_compare.m
% 二つのfigファイルから波形データを抽出し、一つのプロットに重ねて表示するスクリプト 
% ----------------------------------------
% 1. 新しいFigureを作成
% ----------------------------------------
h_new_fig = figure;
hold on; % 複数のグラフを重ねて描画できるように設定
% 現在のAxesハンドルを保持しておく（copyobjのコピー先）
h_target_axes = gca;




% ----------------------------------------
% 3. 2つ目のfigファイルからデータを取得してプロット
% ----------------------------------------
% figファイルを開く
h_fig2 = openfig('plot\offline_ooke4.fig', 'invisible'); 
% Figure内のAxesオブジェクトを見つける
h_axes2 = findobj(h_fig2, 'Type', 'Axes'); 
if ~isempty(h_axes2)
    % Axesの子要素（Lineオブジェクト、つまり波形データ）を全て取得
    h_lines2 = findobj(h_axes2, 'Type', 'Line');
    disp(length(h_lines2))
    
    % Lineオブジェクトを新しいFigureのAxesにコピー (copyobjを使用)
    h_line_copy2 = copyobj(h_lines2, h_target_axes);
    
    % Lineオブジェクトが複数ある可能性があるため、ループで個別に設定
    for i = 1:length(h_line_copy2)
        set(h_line_copy2(i), 'DisplayName', sprintf('波形 2 offline (データ %d)', i));
        set(h_line_copy2(i), 'Color', 'r'); % 赤色に設定
    end
else
    warning('realtime_wasura1_aligment.fig に Axes オブジェクトが見つかりません。');
end

% 2つ目のFigureを閉じる
close(h_fig2); 

% ----------------------------------------
% 2. 1つ目のfigファイルからデータを取得してプロット
% ----------------------------------------
% figファイルを開く
h_fig1 = openfig('plot\realtime_ooke4_new.fig', 'invisible');
% Figure内のAxesオブジェクト（グラフ本体）を見つける
h_axes1 = findobj(h_fig1, 'Type', 'Axes'); 
if ~isempty(h_axes1)
    % Axesの子要素（Lineオブジェクト、つまり波形データ）を全て取得
    h_lines1 = findobj(h_axes1, 'Type', 'Line');
    
    % Lineオブジェクトを新しいFigureのAxesにコピー (copyobjを使用)
    % h_target_axes (gca) にコピーする
    h_line_copy1 = copyobj(h_lines1, h_target_axes);
    
    % Lineオブジェクトが複数ある可能性があるため、ループで個別に設定
    for i = 1:length(h_line_copy1)
        set(h_line_copy1(i), 'DisplayName', sprintf('波形 1 realtime (データ %d)', i));
        set(h_line_copy1(i), 'Color', 'b'); % 青色に設定
    end
 
else
    warning('offline_waura1_0.00005.fig に Axes オブジェクトが見つかりません。');
end
% 最初のFigureを閉じる（非表示で開いているため）
close(h_fig1); 

% ----------------------------------------
% 4. プロットの仕上げ
% ----------------------------------------
title('二つの音声波形の重ね描き');
xlabel('時間 (s)');
ylabel('振幅');

% ★★★ X軸の表示範囲を狭く設定して、詳細を見る ★★★
% 例: 1.5秒から2.5秒の範囲に絞る
%xlim([1.0, 1.5]); 

legend('show'); 
grid on;
hold off;
disp('二つの波形を一つのプロットに重ねて表示しました。');

%title(h_target_axes, '二つの音声波形の重ね描き'); % Axesハンドルを指定
%xlabel(h_target_axes, '時間 (s)'); % Axesハンドルを指定
%ylabel(h_target_axes, '振幅'); % Axesハンドルを指定
%legend(h_target_axes, 'show'); % Axesハンドルを指定して凡例を表示
%grid(h_target_axes, 'on'); % Axesハンドルを指定
%hold off;
%disp('二つの波形を一つのプロットに重ねて表示しました。');