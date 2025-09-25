for i=1:10
    for fuda=1:3
        if fuda==1
            filename = sprintf('wav/ooe%d.wav',i);
        end
        if fuda==2
            filename = sprintf('wav/ooke%d.wav',i);
        end
        if fuda==3
            filename = sprintf('wav/ooko%d.wav',i);
        end
        [data,Fs] = audioread(filename);
        for t=50000:length(data)
            if abs(data(t)) > .08
                break
            end
        end
        start = t;
        if fuda==1
            filename = sprintf('wav_silence_cut/ooe%d.wav',i);
        end
        if fuda==2
            filename = sprintf('wav_silence_cut/ooke%d.wav',i);
        end
        if fuda==3
            filename = sprintf('wav_silence_cut/ooko%d.wav',i);
        end
        audiowrite(filename,data(start:end),Fs);
    end
end
