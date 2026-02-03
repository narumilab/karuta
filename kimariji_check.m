% example: kimariji_check
% 複数の音声ファイルに対して決まり字抽出を
% 実行し、結果を音声再生で確認するスクリプト

for i=1:9
    for j=1:5
        if recog_fuda{i}{j} == i
            ote = '';
        else
            ote = '  otetsuki';
        end
        disp(['ans: ' fudas_test{i} ' (' num2str(j) '), recog: ' fudas_train{recog_fuda{i}{j}} ote]);
        [y,Fs] = kimariji('./aihara_test',fudas_test{i},j,recog_time{i}{j});
        sound(y,Fs);
        pause(2)
    end
end
