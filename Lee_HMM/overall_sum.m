function s=overall_sum(x)
    n=ndims(x);          
    s=x;
    for k=n:-1:1
        s=sum(s,k);
    end
end
