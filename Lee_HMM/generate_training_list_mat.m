clear;
list_filename='training_list.mat';
MODEL_NO=10;
fea_dir='mfcc_e_d_a';

k=0;
for phase=1:6
    for m=1:MODEL_NO
        for spk=1:2:99
            k=k+1;
            list{k,1}=m;
            list{k,2}=sprintf('%s/S%d/%02d_%02d.mfc', fea_dir,phase,spk,m-1);
        end
    end
end
save(list_filename,'list');
