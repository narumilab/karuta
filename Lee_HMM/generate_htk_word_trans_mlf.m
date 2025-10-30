clear;
mlf_filename='word_trans.mlf';
PHASE_NO=6;
MODEL_NO=10;
fid=fopen(mlf_filename,'w');
           
fprintf(fid,'#!MLF!#\n');;
for phase=1:PHASE_NO
    for spk=0:99
        for m=1:MODEL_NO           
           fprintf(fid,'"user_mfcc_e_d_a/S%d/%02d_%02d.lab"\n', phase,spk,m-1);
           fprintf(fid,'d%d\n',m-1);
           fprintf(fid,'.\n');          
        end
    end
end
fclose(fid);
