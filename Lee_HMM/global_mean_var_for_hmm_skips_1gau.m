function [global_mean_vec, global_var_vec, total_fr_no]=global_mean_var_for_hmm_skips_1gau(train_mfcc,model_filename_old, model_filename_new)
load(model_filename_old, 'mean_vec_i_m', 'var_vec_i_m', 'a_i_j_m');

[dim,N,MODEL_NO]=size(mean_vec_i_m);

% allocate mean vectors of states of models
vector_sum=zeros(dim,1);
vector_squared_sum=zeros(dim,1);

total_fr_no = 0;
for i=1:length(train_mfcc)
    for j=1:length(train_mfcc{i})
        c=train_mfcc{i}{j}';
        total_fr_no = total_fr_no + size(c,2);
        vector_sum=vector_sum+sum(c,2);
        vector_squared_sum=vector_squared_sum+sum(c.*c,2);
    end
end
        
global_mean_vec=vector_sum/total_fr_no;
global_var_vec=vector_squared_sum/total_fr_no - global_mean_vec.*global_mean_vec;
% model initilizatiion 
for m=1:MODEL_NO
   for i=2:N-1;
         mean_vec_i_m(:,i,m) = global_mean_vec;
         var_vec_i_m(:,i,m)= global_var_vec;
   end
end
      
save(model_filename_new, 'mean_vec_i_m', 'var_vec_i_m', 'a_i_j_m');
%fprintf('%s initialized with global mean vector and variance vector\n', model_filename_new);
