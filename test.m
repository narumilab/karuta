addpath('Lee_HMM');
[mfccs_train,fudas_train] = wav_to_mfcc('./aihara_train');
karuta_HMM_train(mfccs_train,30,10);
[mfccs_test,fudas_test] = wav_to_mfcc('./aihara_test');
nfuda = length(mfccs_test);
recog_time = cell(1,nfuda);
recog_fuda = cell(1,nfuda);
posterior = cell(1,nfuda);
recog_rate = zeros(1,nfuda);
for i=1:nfuda
    nmfcc = length(mfccs_test{i});
    recog_time{i} = cell(1,nmfcc);
    recog_fuda{i} = cell(1,nmfcc);
    posterior{i} = cell(1,nmfcc);
    for j=1:nmfcc
        [recog_time{i}{j},recog_fuda{i}{j},posterior{i}{j}]=karuta_HMM_recog(mfccs_test{i}{j},'models_state30/iter10.mat',0.9999,0.1);
        if recog_fuda{i}{j} == i
            recog_rate(i) = recog_rate(i)+1/nmfcc;
        end
    end
    disp(['札 ', fudas_test{i}, ' の認識率: ', num2str(recog_rate(i)*100), '%']);
end
for i=1:nfuda
    fuda = fudas_test{i};
    for j=1:length(mfccs_test{i})
        [y,Fs] = kimariji('./aihara_test',fuda,j,recog_time{i}{j});
        audiowrite(sprintf(['./aihara_test_kimariji/' fuda '/' fuda '%d_kimariji.wav'],j),y,Fs);
    end
end
