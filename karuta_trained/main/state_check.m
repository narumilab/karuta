dist = zeros(3,3,50,10);
dista = zeros(3,3,50,10);
for test=1:10
    filename = sprintf('./models_state50/EM_models_S50_iter10_test%d.mat',test);
    load(filename);
    for i=1:3
        for j=1:3
            for k=1:50
                dist(i,j,k,test) = norm(mean_vec_i_m(:,k+1,i)-mean_vec_i_m(:,k+1,j))^2+norm(sqrt(var_vec_i_m(:,k+1,i))-sqrt(var_vec_i_m(:,k+1,j)))^2;
                dista(i,j,k,test) = (a_i_j_m(k,k+1,i)-a_i_j_m(k,k+1,j))^2;
            end
        end
    end
end
