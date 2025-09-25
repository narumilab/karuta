for i=1:10
    filename = sprintf('./ooe%d.wav',i)
    [data,Fs,Bits] = wavread(filename);
    sound(data,Fs);
end
for i=1:10
    filename = sprintf('./ooke%d.wav',i)
    [data,Fs,Bits] = wavread(filename);
    sound(data,Fs);
end
for i=1:10
    filename = sprintf('./ooko%d.wav',i)
    [data,Fs,Bits] = wavread(filename);
    sound(data,Fs);
end
