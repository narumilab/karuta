% example: karuta_HMM_recog(mfccs{i}{j},'models_state30/iter10.mat',0.99,0.1)
function [recog_time,recog_fuda,posterior]=karuta_HMM_recog(mfcc,model,threshold,w)
    mfcc = mfcc';
    load(model, 'mean_vec_i_m', 'var_vec_i_m', 'a_i_j_m');
    num_fuda = size(mean_vec_i_m,3);
    N = size(mean_vec_i_m,2);
    T = size(mfcc,2);
    ll = zeros(num_fuda,T);
    posterior = zeros(num_fuda,T);
    for k=1:num_fuda
        mean_vec_i = mean_vec_i_m(:,:,k);
        var_vec_i = var_vec_i_m(:,:,k);
        a_i_j = a_i_j_m(:,:,k);
        filt = [1; zeros(N-1,1)];
        for t=1:T
            l = 0;
            pred = filt'*a_i_j;
            for i=2:N-1 
                
                l = l + pred(i)*exp(logDiagGaussian(mfcc(:,t),mean_vec_i(:,i),var_vec_i(:,i)));
                filt(i) = pred(i)*exp(logDiagGaussian(mfcc(:,t),mean_vec_i(:,i),var_vec_i(:,i)));
            end
            if t==1
                ll(k,t) = log(l);
            else
                ll(k,t) = ll(k,t-1)+log(l);
            end
            filt = filt/sum(filt);
        end
    end
    for t=1:T
        posterior(:,t) = exp(w*(ll(:,t)-max(ll(:,t))));
        posterior(:,t) = posterior(:,t)/sum(posterior(:,t));
    end
    recog_time = inf;
    recog_fuda = 0;
    for t=1:T
        if max(posterior(:,t)) > threshold
            recog_time = t;
            [~,recog_fuda] = max(posterior(:,t));
            break
        end
    end
end
