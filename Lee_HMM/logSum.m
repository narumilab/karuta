function logS=logSum(x)          
    xmax=overall_max(x);
    if isinf(xmax)
        logS=xmax;
    else
        logS=xmax + log(overall_sum(exp(x-xmax))); 
        %exp(logS)=exp(xmax)*overall_sum(exp(x-xmax))
        %=overall_sum(exp(xmax)*exp(x-xmax))
        %=overall_sum(exp(x))
    end
end
