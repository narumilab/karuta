function [total_log_prob, total_fr_no, dim]=EM_hmm_skips_1gau(train_mfcc,model_filename_old, model_filename_new)
MIN_SELF_TRANSITION_COUNT=0.00;

load(model_filename_old, 'mean_vec_i_m', 'var_vec_i_m', 'a_i_j_m');

[dim,N,MODEL_NO]=size(mean_vec_i_m);

% allocate mean vectors of states of models
vector_sums_i_m=zeros(dim,N,MODEL_NO);
%var_vec_sums_i_m=zeros(dim,N,MODEL_NO);
vector_squared_sums_i_m=zeros(dim,N,MODEL_NO);
fr_no_i_m=zeros(N,MODEL_NO);
fr_no_i_j_m=zeros(N,N,MODEL_NO);

total_log_prob = 0;
total_fr_no = 0;
for i=1:length(train_mfcc)
    for j=1:length(train_mfcc{i})
        m=i;
        c=train_mfcc{i}{j}';
        fr_no=size(c,2);
        [log_prob, pr_i_t, pr_tr_i_j_t ]=forward_backward_hmm_skips_1gau_log_math(c,mean_vec_i_m(:,:,m),var_vec_i_m(:,:,m),a_i_j_m(:,:,m));
        total_log_prob = total_log_prob + log_prob;
        total_fr_no = total_fr_no + fr_no;
    
        fr_no_i_m(1,m)=fr_no_i_m(1,m)+1; % the dummy start state occurs once for each utterance
        fr_no_i_j_m(1,:,m)=fr_no_i_j_m(1,:,m)+ pr_i_t(:,1)';

        for k=2:N-1
            fr_no_i_m(k,m)=fr_no_i_m(k,m)+sum(pr_i_t(k,:));
            fr_no_i_j_m(k,:,m)=fr_no_i_j_m(k,:,m)+sum(pr_tr_i_j_t(k,:,:),3);
            for fr=1:fr_no
                vector_sums_i_m(:,k,m) = vector_sums_i_m(:,k,m) +  pr_i_t(k,fr)*c(:,fr);
                vector_squared_sums_i_m(:,k,m) = vector_squared_sums_i_m(:,k,m) +  pr_i_t(k,fr)*c(:,fr).*c(:,fr);
            end
        end
    
    end
end

% model reestimation
old_mean_vec_i_m= mean_vec_i_m;
old_var_vec_i_m= var_vec_i_m;
old_a_i_j_m= a_i_j_m;

for m=1:MODEL_NO
    i=1;
    a_i_j_m(i,:,m)=(fr_no_i_j_m(i,:,m)+MIN_SELF_TRANSITION_COUNT) /(fr_no_i_m(i,m)+2*MIN_SELF_TRANSITION_COUNT);
    for i=2:N-1;
        a_i_j_m(i,:,m)=(fr_no_i_j_m(i,:,m)+MIN_SELF_TRANSITION_COUNT) /(fr_no_i_m(i,m)+2*MIN_SELF_TRANSITION_COUNT);
        mean_vec_i_m(:,i,m) = vector_sums_i_m(:,i,m)/ fr_no_i_m(i,m);
        % var_vec_i_m(:,i,m)= var_vec_sums_i_m(:,i,m) /  fr_no_i_m(i,m);
        var_vec_i_m(:,i,m)= vector_squared_sums_i_m(:,i,m) / fr_no_i_m(i,m) - mean_vec_i_m(:,i,m).*mean_vec_i_m(:,i,m);
    end
    a_i_j_m(N,1:N-1,m)=0;
    a_i_j_m(N,N,m)=1;
end

[norm(mean_vec_i_m(:)-old_mean_vec_i_m(:)) norm(var_vec_i_m(:)-old_var_vec_i_m(:)) norm(a_i_j_m(:)-old_a_i_j_m(:))]
save(model_filename_new, 'mean_vec_i_m', 'var_vec_i_m', 'a_i_j_m');
%fprintf('re-estimation complete \n');
