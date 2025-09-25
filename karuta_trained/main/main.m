main_dr_wav2mfcc_e_d_a;
%written by mei
MODEL_NO=3; % ooe,ooke,ooko
dim=39;
thresholds = [.99 .999 .9999 .99999 .999999];
feature_file_format='htk';
ITERATION_BEGIN=0; % Set ITERATION_BEGIN=0 to generate model structure
ITERATION_END=10;
MAX_EMIT_STATE_NO = 50;
A0=[1 0]; % the transition prob. from the dummy start state to the emitting states, i.e., A0(1) is used to initialize A(1,2) and A0(k) is used to initialize A(1,k+1) 
Aij=[0.6 0.4]; % the transition prob. from an emit-state to itself and the following states, i.e.,Aij(1) is used initialize A(i,i) and Aij(k) is used initialize A(i,i+k-1) for all i.
Af=[0];  % Af(k) is used to set the transition prob. from the last k-th emit-state to the null end state if Af(k) > A(N-k,N). For each k, if Af(k) is larger than A(N-k,N), then Af(k) is used to replace A(N-k,N) and the probability associated with the transition arcs leaving State k are renormalized. If Af(k) does not exist or Af(k) is not larger than A(N-k,N), then A(N-k,N) will not be affected.	
format compact;
tic
for test=1:10
    kimariji = zeros(3,length(thresholds));
    posterior_series = zeros(3,3,1000);
    list = cell(3,2);
    list{1,1} = 1;
    list{1,2} = sprintf('mfcc_e_d_a/ooe%d.mfc',test);
    list{2,1} = 2;
    list{2,2} = sprintf('mfcc_e_d_a/ooke%d.mfc',test);
    list{3,1} = 3;
    list{3,2} = sprintf('mfcc_e_d_a/ooko%d.mfc',test);
    save('testing_list_old.mat','list');
    list = cell(27,2);
    k = 1;
    for i=1:10
        if i==test
            continue;
        end
        list{k,1} = 1;
        list{k,2} = sprintf('mfcc_e_d_a/ooe%d.mfc',i);
        k = k+1;
        list{k,1} = 2;
        list{k,2} = sprintf('mfcc_e_d_a/ooke%d.mfc',i);
        k = k+1;
        list{k,1} = 3;
        list{k,2} = sprintf('mfcc_e_d_a/ooko%d.mfc',i);
        k = k+1;
    end
    save('training_list_old.mat','list');

    EMIT_STATE_NO=MAX_EMIT_STATE_NO;
        N=EMIT_STATE_NO+2;
        model_filename_prefix='models_state50/EM_models';
        traininglist_filename='training_list_old.mat';
        testinglist_filename='testing_list_old.mat'; % outside test
    
        total_log_prob=zeros(1,ITERATION_END);
        total_fr_no=zeros(1,ITERATION_END);
    
        for iter=ITERATION_BEGIN:ITERATION_END
            model_filename_new=[model_filename_prefix, '_S', int2str(EMIT_STATE_NO), '_iter', int2str(iter), '_test', int2str(test), '.mat'];
            if iter==0
                model_struct_filename=[model_filename_prefix, '_S', int2str(EMIT_STATE_NO), '_struct', int2str(iter),  '.mat'];
                generate_LR_HMM_skips_structure(MODEL_NO,model_struct_filename,dim,N,A0,Aij,Af);
                [global_mean_vec, global_var_vec, total_fr_no] = global_mean_var_for_hmm_skips_1gau(traininglist_filename,model_struct_filename, model_filename_new);
            else
                model_filename_old=[model_filename_prefix, '_S', int2str(EMIT_STATE_NO), '_iter', int2str(iter-1), '_test', int2str(test), '.mat'];
                [total_log_prob(iter),total_fr_no(iter),dim] = EM_hmm_skips_1gau(traininglist_filename,model_filename_old,model_filename_new);
            end
        end
        
        model_filename=['models_state50/EM_models_S', int2str(EMIT_STATE_NO), '_iter' int2str(ITERATION_END) '_test' int2str(test) '.mat'];
        ll = zeros(3,10);
    for fuda=1:3
        if fuda==1
            filename = sprintf('mfcc_e_d_a/ooe%d.mfc',test);
        end
        if fuda==2
            filename = sprintf('mfcc_e_d_a/ooke%d.mfc',test);
        end
        if fuda==3
            filename = sprintf('mfcc_e_d_a/ooko%d.mfc',test);
        end
        fid=fopen(filename,'r');
        fseek(fid, 12, 'bof'); % skip the 12-byte HTK header
        c=fread(fid,'float','b');        
        fclose(fid);
        fr_no=length(c)/dim;
        c=reshape(c,dim,fr_no);
        ll = zeros(MODEL_NO,1000);
        ll_tmp = recognition_Viterbi_hmm_skips_1gau_no_terminal(c,1,model_filename);
        ll(1,1:fr_no) = ll_tmp(1,:);
        ll(2,1:fr_no) = ll_tmp(2,:);
        ll(3,1:fr_no) = ll_tmp(3,:);
        p = exp(ll-ones(MODEL_NO,1)*mean(ll));
        for t=1:fr_no
            if max(p(:,t)) == Inf
                [tmp,argmax] = max(p(:,t));
                posterior_series(fuda,:,t) = 0;
                posterior_series(fuda,argmax,t) = 1;
            else
                posterior_series(fuda,:,t) = p(:,t)/sum(p(:,t));
            end
        end
        k = 1;
        for t=1:fr_no
            if min(posterior_series(fuda,fuda,t:fr_no)) > thresholds(k)
                kimariji(fuda,k) = t;
                k = k+1;
                if k > length(thresholds)
                    break;
                end
            end
        end
        kimariji(fuda,k:length(thresholds)) = fr_no;
    end
    output_filename=sprintf('final%d_state50.mat',test);
    save(output_filename,'kimariji','thresholds','posterior_series');
end
