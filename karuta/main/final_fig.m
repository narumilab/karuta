%load('final1.mat');
%for i=1:3
%    figure
%   plot(AIC(i,:),'k','LineWidth',2)
%    xlabel('状態数')
%    ylabel('AIC')
%    set(gca,'FontSize',16);
%end
state_check;
for i=1:3
    for j=i+1:3
        figure
        plot(squeeze(dist(i,j,:,1)),'k','LineWidth',2)
        xlabel('状態番号')
        ylabel('ワッサースタイン距離')
        set(gca,'FontSize',16);
    end
end
