clear;
filename1='filelist_odd.txt';
filename2='filelist_even.txt';
filename3='io_filelist.txt';
PHASE_NO=6;
MODEL_NO=10;
fid=fopen(filename1,'w');
for phase=1:PHASE_NO
    for spk=1:2:99
        for m=1:MODEL_NO           
           fprintf(fid,'user_mfcc_e_d_a/S%d/%02d_%02d.mfcc\n', phase,spk,m-1);
        end
    end
end
fclose(fid);

fid=fopen(filename2,'w');
for phase=1:PHASE_NO
    for spk=0:2:99
        for m=1:MODEL_NO           
           fprintf(fid,'user_mfcc_e_d_a/S%d/%02d_%02d.mfcc\n', phase,spk,m-1);
        end
    end
end
fclose(fid);

fid=fopen(filename3,'w');
for phase=1:PHASE_NO
    for spk=0:99
        for m=1:MODEL_NO           
           fprintf(fid,'wav/S%d/%02d_%02d.wav  user_mfcc_e_d_a/S%d/%02d_%02d.mfcc\n', phase,spk,m-1,phase,spk,m-1);
        end
    end
end
fclose(fid);

