
function log_pr=logDiagGaussian(v,u,K1)
 dim=length(K1);
 log_pr=-1/2*dim*log(2*pi) -1/2*sum(log(K1))- 1/2*sum((v-u).*(v-u)./K1);
 end
