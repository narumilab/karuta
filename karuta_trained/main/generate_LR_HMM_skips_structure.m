function [a_i_j_m, mean_vec_i_m, var_vec_i_m]=generate_LR_HMM_skips_structure(MODEL_NO,model_filename,dim,AUG_STATE_NO,A0,Aij,Af)
if nargin==0
    MODEL_NO=11;
    model_filename='hmm_with_skips.mat';
    dim =39;
    AUG_STATE_NO=10; % including the dummy start and end states
    A0=[0.8 0.2]; % the transition prob. from the dummy start state to the emitting states
    Aij=[0.6 0.3 0.1]; % the transition prob. from an emit-state to itself and the following states
    Af=[];  % Af(k) is used to set the transition prob. from the last k-th emit-state to the null end state if Af(k) > A(AUG_STATE_NO-k,AUG_STATE_NO)
end
N=AUG_STATE_NO;
flag_show_transition_prob=true;
EPSILON=1E-9;
mean_vec_i_m=zeros(dim,N,MODEL_NO);
var_vec_i_m=ones(dim,N,MODEL_NO);
a_i_j_m=zeros(N,N,MODEL_NO);


A=zeros(N,N);
A(1,1)=0; A(1,2:length(A0)+1)=A0;
for i=2:N-length(Aij)+1
    A(i,1:i-1)=0;
    A(i,i:i+length(Aij)-1) = Aij;
end

for i=N-length(Aij)+2:N
    A(i,1:i-1)=0;
    A(i,i:N) = Aij(1:N-i+1)/sum(Aij(1:N-i+1));
end

for k=1:length(Af)
    row=N-k;
    if A(row,N) < Af(k)
        A(row,1:N-1)=A(row,1:N-1)/(1-A(row,N))*(1-Af(k));
        A(row,N)=Af(k);
    end
end

for m=1:MODEL_NO
    a_i_j_m(:,:,m)=A;
end

if (flag_show_transition_prob)
    fprintf('  <TransP> %d \n',N);
     A,
end

if sum(abs(sum(A,2)-1)) > EPSILON
    fprintf('1 - transition prob. = %f \n', 1-sum(A,2));
    error('transition prob. do not sum to 1');
end

save(model_filename, 'mean_vec_i_m', 'var_vec_i_m', 'a_i_j_m');
fprintf('model structure %s generated\n', model_filename);

