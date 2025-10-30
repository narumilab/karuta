% example: karuta_HMM_train(mfccs,30,10)
%
% num_state: number of hidden states
% num_iter: number of EM iterations
function []=karuta_HMM_train(train_mfcc,num_state,num_iter)
    nfuda = length(train_mfcc);
    N = num_state+2;
    dim = size(train_mfcc{1}{1},2);
    model_filename_prefix = sprintf('models_state%d/',num_state);    
    for iter=0:num_iter
        model_filename_new=[model_filename_prefix, 'iter', int2str(iter), '.mat'];
        if iter==0
            model_struct_filename=[model_filename_prefix, 'struct.mat'];
            generate_LR_HMM_skips_structure(nfuda,model_struct_filename,dim,N,[1 0],[0.6 0.4],0);
            global_mean_var_for_hmm_skips_1gau(train_mfcc,model_struct_filename, model_filename_new);
        else
            model_filename_old=[model_filename_prefix, 'iter', int2str(iter-1), '.mat'];
            EM_hmm_skips_1gau(train_mfcc,model_filename_old,model_filename_new);
        end
    end
end
