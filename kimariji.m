% example: [y,Fs]=kimariji('./aihara_wav',fudas{1},2,recog_time{1}{2})
% wavdir: wavファイルのディレクトリパス
% fuda: 札名
% num: ファイル番号
% kimariji_frame: 決まり字確定フレーム番号

function [y,Fs,kimariji_second]=kimariji(wavdir,fuda,num,kimariji_frame)
    [y,Fs] = audioread(sprintf([wavdir '/' fuda '/' fuda '%d.wav'],num));
    frame_size_sec = 0.030;
    frame_shift_sec = 0.010;
    kimariji_second = frame_shift_sec*(kimariji_frame-1)+frame_size_sec
    y = y(1:ceil(kimariji_second*Fs));
end
