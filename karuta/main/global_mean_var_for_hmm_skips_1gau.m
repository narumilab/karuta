function [global_mean_vec, global_var_vec, total_fr_no]=global_mean_var_for_hmm_skips_1gau(traininglist_filename,model_filename_old, model_filename_new)
if nargin ==0
    traininglist_filename='training_list.mat';
    model_filename_old='hmm_with_skips.mat';
    model_filename_new='hmm_with_skips_new.mat'; 
end;

load(model_filename_old, 'mean_vec_i_m', 'var_vec_i_m', 'a_i_j_m');
load(traininglist_filename,'list');

[dim,N,MODEL_NO]=size(mean_vec_i_m);

% allocate mean vectors of states of models
vector_sum=zeros(dim,1);
vector_squared_sum=zeros(dim,1);

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
        
        total_fr_no = total_fr_no + fr_no;
        vector_sum=vector_sum+sum(c,2);
        vector_squared_sum=vector_squared_sum+sum(c.*c,2);
end %for k=1:utterance_no
        
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
fprintf('%s initialized with global mean vector and variance vector\n', model_filename_new);
