
function [log_prob, pr_i_t,  pr_tr_i_j_t ] = forward_backward_hmm_skips_1gau_log_math( V, mean_vec_i, var_vec_i, a_i_j  )
flag_plot_frame_distribution=0; % 1 or 0
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

[dim , N]=size(mean_vec_i);
[dim2 , T]=size(V);
pr_tr_i_j_t=zeros(N,N,T);

[log_prob,  logfw, logObsevation_i_t] = forward_hmm_skips_1gau_log_math(V, mean_vec_i, var_vec_i, a_i_j );
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                    log backward function
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
logbw=ones(N,T)*(-inf);
t=T;
logbw(2:N-1,T)=log(a_i_j(2:N-1,N));
pr_tr_i_j_t(2:N-1,N,T) = exp(logfw(2:N-1,T) + log(a_i_j(2:N-1,N)) - log_prob);
for t=T-1:-1:1
    for i=2:N-1
        logbw(i,t)=logSum( (log(a_i_j(i,i:N-1)) )' + logObsevation_i_t(i:N-1,t+1) + logbw(i:N-1,t+1)  );
        pr_tr_i_j_t(i,i:N-1,t)=exp(logfw(i,t) + (log(a_i_j(i,i:N-1)))'+logObsevation_i_t(i:N-1,t+1) + logbw(i:N-1,t+1)-log_prob);
    end
end

pr_i_t= exp(  logfw+logbw - log_prob );
count_at_t(1:T)=sum(pr_i_t,1);
count_at_t=squeeze(count_at_t);
frame_no_diff=sum(count_at_t) -T;
if  frame_no_diff > 1E-6
    error('the number of frames distributed to the states does not sum to T, the diff.=%f',frame_no_diff) ;
end
if flag_plot_frame_distribution == 1
    t=1;
    hold off; 
    plot(pr_i_t(:,t));
    hold on;
    for t=2:T
        plot(pr_i_t(:,t));
        pause(0.1);
    end
    count_i=sum(pr_i_t,2);
    stem( count_i );
    hold off;
end
% error_pr_i_t=pr_i_t - squeeze(sum(pr_tr_i_j_t,2));
end % of function
