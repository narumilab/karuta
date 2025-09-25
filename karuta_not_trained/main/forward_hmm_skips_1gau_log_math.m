%log_pr: log prob. of forward function
%varargout(1)= logfw 
%varargout(2)=  logObsevation_i_t
function [log_pr, varargout] = forward_hmm_skips_1gau_log_math(V, mean_vec_i, var_vec_i,  a_i_j  )
if nargin==0
    V=[20 30 40 10 0 30]; % an example that the best path does not skip any state
    % to get an example of state-skipped path, use the following input sequence
    % V=[40 30 40 10 0 -5];
    mean_vec_i=[NaN 10 40 -10 20 NaN];
    var_vec_i= [NaN  1  1   1  1 NaN];
    a_i_j=[0  0.8 0.2  0   0   0
        0  0.6 0.3 0.1  0   0
        0   0  0.6 0.3 0.1  0
        0   0   0  0.6 0.3 0.1
        0   0   0   0  0.6 0.4
        0   0   0   0   0   1 ];
end
[dim ,N]=size(mean_vec_i);
[dim , T]=size(V);
logObsevation_i_t=ones(N,T)*(-inf);
for t=1:T
    for i=2:N-1
        logObsevation_i_t(i,t)=logDiagGaussian(V(:,t),mean_vec_i(:,i),var_vec_i(:,i));
    end
end
%%%%%%%%%%%%%%  log  forward probability        %%%%%%%%%%%%%
logfw=ones(N,T)*(-inf);
%%%%%%%%%%%%%%  t=1, i=2:N-1   %%%%%%%%%%%%%
t=1;
logfw(2:N-1,1)=log(a_i_j(1,2:N-1))' + logObsevation_i_t(2:N-1,1);
% logfw([1 end],1)=-inf have already been initialized during array allocation

%%%%%%%%%%%%  t=2:T, i=2:N-1   %%%%%%%%%%%%%
for t=2:T
   for i=2:N-1
        logfw(i,t)= logSum(  logfw(2:i,t-1) +log(a_i_j(2:i,i))  ) + logObsevation_i_t(i,t);      
   end   
end %for t=2:T
   
 log_pr=logSum(  logfw(2:N-1,T) +log(a_i_j(2:N-1,N))  );


if nargout > 1
    varargout(1)= {logfw}; 
end
if nargout > 2
    varargout(2)= {logObsevation_i_t}; 
end

end % of function
