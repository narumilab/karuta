%load('final1.mat');
%for i=1:3
 %   figure
  %  plot(AIC(i,:),'k','LineWidth',2)
   % xlabel('状態数')
    %ylabel('AIC')
    %set(gca,'FontSize',16);
%end
state_check;
for i=1:3
    for j=i+1:3
        figure

        % ファイル名を定義（PNG形式）
        filename_png = sprintf('Wasserstein_Dist_Compare_%d_%d.png', i, j);
        
        plot(squeeze(dist(i,j,:,1)),'k','LineWidth',2)
        xlabel('状態番号')
        ylabel('ワッサースタイン距離')
        set(gca,'FontSize',16);
        % ★★★ グラフをファイルに保存するコード（saveas関数） ★★★
        % saveas(gcf, filename_png); は、現在のフィギュアをファイル名に従って保存します。
        saveas(gcf, filename_png); 

        fprintf('プロットをファイル: %s に保存しました。\n', filename_png);
    end
end
