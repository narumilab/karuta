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
