
function xmax=overall_max(x)
   n=ndims(x);          
   xmax=x;
    for k=n:-1:1
        xmax=max(xmax,[ ], k);
    end
end
