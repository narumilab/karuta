function [recog_time, recog_fuda, posterior, ll, current_filt] = karuta_HMM_recog_realtime(mfcc, model, threshold, w, before_ll, before_filt)

    % The input mfcc is already in the format (dimensions x frames).
    % Do not transpose it.
    % mfcc = mfcc';
    load(model, 'mean_vec_i_m', 'var_vec_i_m', 'a_i_j_m');
    num_fuda = size(mean_vec_i_m,3);
    N = size(mean_vec_i_m,2);
    T = size(mfcc,2);
    
    ll = zeros(num_fuda,T);
    posterior = zeros(num_fuda,T);
    % ⭐ 変更 1: current_filt を初期化 (状態数 N x 札数 num_fuda)
    current_filt = zeros(N, num_fuda); 
    
    % ⭐ T フレームの逐次処理ループ
    for t=1:T
        % 修正前の `filt = [1; zeros(N-1,1)];` の代わりに、
        % `t=1` の場合のみ before_filt から初期状態を引き継ぐ
        
        for k=1:num_fuda
            mean_vec_i = mean_vec_i_m(:,:,k);
            var_vec_i = var_vec_i_m(:,:,k);
            a_i_j = a_i_j_m(:,:,k);
            l = 0;
            
            % ⭐ 変更 2: フレーム t における前方確率の初期化/引き継ぎ ⭐
            if t == 1 
                % 外部から引き継いだ状態 (before_filt) を使用
                if isempty(before_filt) || all(before_filt(:) == 0)
                    % before_filt が空なら、HMMの開始状態1を1.0として簡易初期化
                    filt = zeros(N, 1);
                    filt(1) = 1.0; 
                else
                    % before_filt の k 番目の札の状態を使用
                    filt = before_filt(:, k);
                end
            else
                % フレーム t > 1: フレーム t-1 で計算された状態 current_filt を使用
                filt = current_filt(:, k); 
            end

            pred = filt'*a_i_j;
            
            % 新しい前方確率を一時的に格納
            temp_filt_k = zeros(N, 1);
            
            for i=2:N-1 
                emission_prob = exp(logDiagGaussian(mfcc(:,t),mean_vec_i(:,i),var_vec_i(:,i)));
                l = l + pred(i) * emission_prob;
                temp_filt_k(i) = pred(i) * emission_prob;
                
            end
            
                        
            if t==1
                % before_ll は num_fuda x 1 のベクトルとして想定
                % ll(k,t) = before_ll(k) + log(l);
                % [修正 A] log(l) の代わりに log(l + eps) を使用
                ll(k,t) = before_ll(k) + log(l + eps); % <-- MATLABの最小浮動小数点数epsを追加
            else
                % [修正 A] log(l) の代わりに log(l + eps) を使用
                ll(k,t) = ll(k,t-1)+log(l + eps); % <-- MATLABの最小浮動小数点数epsを追加
            end


            % スケーリング/正規化
            % temp_filt_k = temp_filt_k / sum(temp_filt_k) ;
            sum_filt = sum(temp_filt_k);
            if sum_filt == 0
                % 総和が0の場合、現在の状態を維持（または初期状態に戻すなど）
                % ここでは、すべての状態に均等な小さな確率を割り当て、NaNを防ぐ
                temp_filt_k = ones(N, 1) * (1/N); 
                warning('HMM Forward Probability sum was zero, resetting filter.');
            else
                temp_filt_k = temp_filt_k / sum_filt;
            end
            
            % 結果を current_filt に保存（次のフレーム t+1 または次の k の初期値として使用）
            current_filt(:, k) = temp_filt_k;
        end % end for k
    end % end for t

    % ⭐ 変更 3: posterior/recog の計算は T フレーム全体に対して行う ⭐
    for t=1:T
        % ... posterior の計算ロジックは変更なし
        posterior(:,t) = exp(w*(ll(:,t)-max(ll(:,t))));
        posterior(:,t) = posterior(:,t)/(sum(posterior(:,t))+ eps);
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