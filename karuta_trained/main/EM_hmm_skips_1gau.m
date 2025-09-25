function [total_log_prob, total_fr_no, dim]=EM_hmm_skips_1gau(traininglist_filename,model_filename_old, model_filename_new)
if nargin ==0
    traininglist_filename='training_list.mat';
    model_filename_old='hmm_with_skips.mat';
    model_filename_new='hmm_with_skips.mat';
end;
MIN_SELF_TRANSITION_COUNT=0.00;

load(model_filename_old, 'mean_vec_i_m', 'var_vec_i_m', 'a_i_j_m');
load(traininglist_filename,'list');

[dim,N,MODEL_NO]=size(mean_vec_i_m);

% allocate mean vectors of states of models
vector_sums_i_m=zeros(dim,N,MODEL_NO);
%var_vec_sums_i_m=zeros(dim,N,MODEL_NO);
vector_squared_sums_i_m=zeros(dim,N,MODEL_NO);
fr_no_i_m=zeros(N,MODEL_NO);
fr_no_i_j_m=zeros(N,N,MODEL_NO);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                          FOR DEBUG,  COV. MATRICES are set to identity matrix                                                %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% for m=1:MODEL_NO
%     for i=1:N
%             var_vec_i_m(:,i,m)= ones(dim,1);
%     end
% end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

total_log_prob = 0;
total_fr_no = 0;
utterance_no=size(list,1);
for k=1:utterance_no
    filename=list{k,2};
    m=list{k,1}; % word ID
    fid=fopen(filename,'r');
    fseek(fid, 12, 'bof'); % skip the 12-byte HTK header
    c=fread(fid,'float','b');
    fclose(fid);
    fr_no=length(c)/dim;
    c=reshape(c,dim,fr_no);
    [log_prob, pr_i_t, pr_tr_i_j_t ]=forward_backward_hmm_skips_1gau_log_math(c,mean_vec_i_m(:,:,m),var_vec_i_m(:,:,m),a_i_j_m(:,:,m));
    total_log_prob = total_log_prob + log_prob;
    total_fr_no = total_fr_no + fr_no;
    
    % i=1;
    fr_no_i_m(1,m)=fr_no_i_m(1,m)+1; % the dummy start state occurs once for each utterance
    fr_no_i_j_m(1,:,m)=fr_no_i_j_m(1,:,m)+ pr_i_t(:,1)';
    % i=2:N-1;
    for i=2:N-1
        fr_no_i_m(i,m)=fr_no_i_m(i,m)+sum(pr_i_t(i,:));
        fr_no_i_j_m(i,:,m)=fr_no_i_j_m(i,:,m)+sum(pr_tr_i_j_t(i,:,:),3);
        for fr=1:fr_no
            vector_sums_i_m(:,i,m) = vector_sums_i_m(:,i,m) +  pr_i_t(i,fr)*c(:,fr);
            %var_vec_sums_i_m(:,i,m) =var_vec_sums_i_m(:,i,m) + pr_i_t(i,fr)*(c(:,fr)-mean_vec_i_m(:,i,m)).*(c(:,fr)-mean_vec_i_m(:,i,m));
            vector_squared_sums_i_m(:,i,m) = vector_squared_sums_i_m(:,i,m) +  pr_i_t(i,fr)*c(:,fr).*c(:,fr);
        end
    end
    
end %for k=1:utterance_no

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

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                   tying of cov. matrices
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%  overall_var_vec=sum(sum(var_vec_sums_i_m(:,:,:),3 ),2)/sum(sum(fr_no_i_m,2 ),1);
%  for m=1:MODEL_NO
%      for i=1:N
%          var_vec_i_m(:,i,m)=overall_var_vec;
%      end
%  end
%%%%%%%%%%%%%%%%            end of cov. matrices tying                   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                            variance comparison
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% var_new_to_old_ratio=var_vec_i_m ./ old_var_vec_i_m;
%var_new_to_old_ratio
norm(mean_vec_i_m(:)-old_mean_vec_i_m(:))
norm(var_vec_i_m(:)-old_var_vec_i_m(:))
norm(a_i_j_m(:)-old_a_i_j_m(:))
save(model_filename_new, 'mean_vec_i_m', 'var_vec_i_m', 'a_i_j_m');
fprintf('re-estimation complete \n');
