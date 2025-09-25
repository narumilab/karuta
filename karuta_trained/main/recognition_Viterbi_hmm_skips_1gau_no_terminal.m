function [ll]=recognition_Viterbi_hmm_skips_1gau_no_terminal(testing_data,test_ans,model_filename)
    load(model_filename, 'mean_vec_i_m', 'var_vec_i_m', 'a_i_j_m');
    N = size(mean_vec_i_m,2);
    T = size(testing_data,2);
    MODEL_NO=size(mean_vec_i_m,3);
    posterior_series = zeros(1,T);
    f = zeros(N,T,MODEL_NO);
    P = cell(N,T,MODEL_NO);
    path = cell(T,MODEL_NO);
    ll = zeros(MODEL_NO,T);
    for m=1:MODEL_NO
        [f(:,:,m),P(:,:,m),ll(m,:)]=viterbi_hmm_LR_skips_1gau_no_terminal( testing_data, mean_vec_i_m(:,:,m), var_vec_i_m(:,:,m), a_i_j_m(:,:,m) );
    end
    max_f = zeros(MODEL_NO,T);
    for t=1:T
        for m=1:MODEL_NO
            [max_f(m,t),argmax] = max(f(1:N-1,t,m));
            path(t,m) = P(argmax,t,m);
        end
    end
    max_f = max_f-ones(MODEL_NO,1)*mean(max_f);
    p = exp(max_f);
    p = exp(ll-ones(MODEL_NO,1)*mean(ll));
    for t=1:T
        if p(test_ans,t) == Inf
            posterior_series(t) = 1;
        else
            posterior_series(t) = p(test_ans,t)/sum(p(:,t));
        end
        if max(p(:,t)) == Inf
            [tmp,argmax] = max(p(:,t));
            p(:,t) = 0;
            p(argmax,t) = 1;
        else
            p(:,t) = p(:,t)/sum(p(:,t));
        end
    end
end
