function [f,P,ll]=viterbi_hmm_LR_skips_1gau_no_terminal(V, mean_vec_i, var_vec_i, a_i_j)

[dim ,N]=size(mean_vec_i);
[dim ,T]=size(V);
P=cell(N,T);
f=ones(N,T)*(-inf);
ll=zeros(1,T);

%%%%%%%%%%%%  t=1  %%%%%%%%%%%%%%%%%%%%
t=1;
l = 0;
post = zeros(N,1);
for i=2:N-1
    P{i,t}=i;
    f(i,t)=log(a_i_j(1,i)) + logDiagGaussian(V(:,t),mean_vec_i(:,i),var_vec_i(:,i));
    l = l + a_i_j(1,i)*exp(logDiagGaussian(V(:,t),mean_vec_i(:,i),var_vec_i(:,i)));
    post(i) = a_i_j(1,i)*exp(logDiagGaussian(V(:,t),mean_vec_i(:,i),var_vec_i(:,i)));
end
ll(t) = log(l);
post = post/sum(post);
% other f(i,t) terms have been set to -inf

%%%%%%%%%%%%  t=2:T   %%%%%%%%%%%%%
for t=2:T
    l = 0;
    pred = post'*a_i_j;
    for i=2:N-1 
        [f(i,t), argmax] = max( f(1:i,t-1) + log(a_i_j(1:i,i)) );
        %[f(i,t), argmax] = max( f(2:i,t-1) + log(a_i_j(2:i,i)) ); argmax=argmax+1; % if we pass the sub-array of index [2:i] instead of [1:i] to max function
        f(i,t)=f(i,t)+logDiagGaussian(V(:,t),mean_vec_i(:,i),var_vec_i(:,i) );
        P{i,t}=[P{argmax,t-1}  i ];
        l = l + pred(i)*exp(logDiagGaussian(V(:,t),mean_vec_i(:,i),var_vec_i(:,i)));
        post(i) = pred(i)*exp(logDiagGaussian(V(:,t),mean_vec_i(:,i),var_vec_i(:,i)));
    end
    ll(t) = ll(t-1)+log(l);
    post = post/sum(post);
end

%%%%%%%%%%%%%% optimal path  %%%%%%%%%%%%%
%[Fopt,argmax] = max( f(1:N-1,T) ) ; % changed by matsuda
%[Fopt,argmax] = max( f(1:N-1,T) + log(a_i_j(1:N-1,N))) ;
%[Fopt,argmax] = max( f(2:N-1,T) + log(a_i_j(2:N-1,N))) ; argmax=argmax+1; % if we pass the sub-array of index [2:N-1] instead of [1:N-1] to max function

end
