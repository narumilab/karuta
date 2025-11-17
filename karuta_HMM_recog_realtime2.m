function [recog_time, recog_fuda, posterior, ll, current_filt] = karuta_HMM_recog_realtime(mfcc, model, threshold, w, before_ll, before_filt)
    mfcc = mfcc'
    load(model, 'mean_vec_i_m', 'var_vec_i_m', 'a_i_j_m');
    num_fuda = size(mean_vec_i_m,3);
    N = size(mean_vec_i_m,2);
    T = size(mfcc,2);
    ll = zeros(num_fuda,T);
    posterior = zeros(num_fuda,T);
    % current_filt を初期化 (状態数 N x 札数 num_fuda)
    current_filt = zeros(N, num_fuda); 
    
    % T フレームの逐次処理ループ
    for t=1:T
        
        % ⭐ 修正 A: フレーム t の新しい前方確率を保持するための行列を初期化 ⭐
        new_filt_T = zeros(N, num_fuda); 
        
        for k=1:num_fuda
            mean_vec_i = mean_vec_i_m(:,:,k);
            var_vec_i = var_vec_i_m(:,:,k);
            a_i_j = a_i_j_m(:,:,k);
            l = 0;
            
            % ⭐ 修正 B: フレーム t の入力状態を決定 ⭐
            if t == 1 
                % HMM開始状態、または外部から引き継いだ状態を使用
                if isempty(before_filt) || all(before_filt(:) == 0)
                    filt = zeros(N, 1);
                    filt(1) = 1.0; 
                else
                    filt = before_filt(:, k); % 前回の最終状態を引き継ぐ
                    disp('before exists');
                end
            else
                % フレーム t > 1: フレーム t-1 で確定した状態を使用
                % Tフレームのループ内で current_filt を更新しているため、ここではt-1の結果を反映できない。
                % ただし、この関数は T=1 のブロック処理を想定しているため、
                % 外部からの before_filt 引き継ぎを優先し、T>1 の場合は前の結果を使う。
                % [この実装では T=1 のブロック処理が前提]
                filt = current_filt(:, k); % 前の反復の結果を使用
            end
            
            % 予測 (Prediction) は次のフレームへの遷移確率
            pred = filt'*a_i_j;
            
            % 新しい前方確率を一時的に格納 (N x 1)
            temp_filt_k = zeros(N, 1);
            temp_filt_k(1) = filt(1); % <-- 状態 1 の値を前の状態からコピー!
            
            % ⭐ 修正 C: 状態 1 (開始状態) の処理を追加 ⭐
            % HMMが左向きモデルの場合、通常状態 1 は開始時にのみ確率を持つ
            % 処理しない場合は temp_filt_k(1) = 0 のまま

            % 状態 2 から N-1 までの計算
            for i=2:N-1 
                emission_prob = exp(logDiagGaussian(mfcc(:,t),mean_vec_i(:,i),var_vec_i(:,i)));
                % l の計算 (確率の総和)
                l = l + pred(i) * emission_prob;
                % フィルタリング: (前フレームの状態からiへの遷移確率) * iでの観測確率
                temp_filt_k(i) = pred(i) * emission_prob;
            end

            
            
            % ⭐ 修正 D: 対数尤度 (Log-Likelihood) の更新 ⭐
            if t==1
                % before_ll は num_fuda x 1 のベクトルとして想定
                ll(k,t) = before_ll(k) + log(l + eps); % log(0)回避
            else
                ll(k,t) = ll(k,t-1)+log(l + eps); % log(0)回避
            end
            
            % ⭐ 修正 E: スケーリング/正規化（0 除算防止ロバスト化）⭐
            sum_filt = sum(temp_filt_k);
            if sum_filt == 0
                temp_filt_k = zeros(N, 1);
                %temp_filt_k(1) = filt(1);
                temp_filt_k(1) = 1.0;
                disp('HMM Forward Probability sum was zero.');
            else
                temp_filt_k = temp_filt_k / sum_filt;
            end
            
            % ⭐ 修正 F: 結果を new_filt_T に保存（このフレーム t の結果）⭐
            new_filt_T(:, k) = temp_filt_k;
        end % end for k
        % karuta_HMM_recog_realtime 内の for t=1:T ループの終わり（llの計算後など）に:
        %if mod(t, 10) == 0 % 10フレームごとに表示
         %   fprintf('Log-Likelihood (ll): '); % accumulated_frame_count は外部から渡せないため、t を使用
          %  disp(ll(:, t)'); % すべての札の累積尤度を表示
            % fprintf('Frame %d, Forward Probability Sum (l): %.2e\n', t, l); % l も表示
        %end
        % ⭐ 修正 G: フレーム t のすべての札のフィルタリング結果を current_filt にコピー ⭐
        current_filt = new_filt_T;
        

    end % end for t
    
    % ⭐ 変更 3: posterior/recog の計算は T フレーム全体に対して行う ⭐
    for t=1:T
        % 修正前の `posterior(:,t) = posterior(:,t)/(sum(posterior(:,t))+ eps);` は不要
        posterior(:,t) = exp(w*(ll(:,t)-max(ll(:,t))));
        posterior(:,t) = posterior(:,t)/sum(posterior(:,t)); % epsは0除算防止
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