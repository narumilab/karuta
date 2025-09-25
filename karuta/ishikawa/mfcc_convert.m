Tw = 25;           % analysis frame duration (ms)
Ts = 10;           % analysis frame shift (ms)
alpha = 0.97;      % preemphasis coefficient
R = [ 300 3700 ];  % frequency range to consider
M = 20;            % number of filterbank channels 
C = 13;            % number of cepstral coefficients
L = 22;            % cepstral sine lifter parameter
       
% hamming window (see Eq. (5.2) on p.73 of [1])
hamming = @(N)(0.54-0.46*cos(2*pi*[0:N-1].'/(N-1)));

MFCCs = zeros(13,800,3,10);
FBEs = zeros(20,800,3,10);

for i=1:10
    filename1 = sprintf('ooe%d.wav',i);
    filename2 = sprintf('ooke%d.wav',i);
    filename3 = sprintf('ooko%d.wav',i);
    % Read speech samples, sampling rate and precision from file
    [ speech, fs, nbits ] = wavread(filename1);   
    % Feature extraction (feature vectors as columns)
    [ MFCCs_tmp, FBEs_tmp, frames ] = mfcc( speech, fs, Tw, Ts, alpha, hamming, R, M, C, L );
    MFCCs(:,1:size(MFCCs_tmp,2),1,i) = MFCCs_tmp;
    FBEs(:,1:size(FBEs_tmp,2),1,i) = FBEs_tmp;
    % Read speech samples, sampling rate and precision from file
    [ speech, fs, nbits ] = wavread(filename2);   
    % Feature extraction (feature vectors as columns)
    [ MFCCs_tmp, FBEs_tmp, frames ] = mfcc( speech, fs, Tw, Ts, alpha, hamming, R, M, C, L );
    MFCCs(:,1:size(MFCCs_tmp,2),2,i) = MFCCs_tmp;
    FBEs(:,1:size(FBEs_tmp,2),2,i) = FBEs_tmp;
    % Read speech samples, sampling rate and precision from file
    [ speech, fs, nbits ] = wavread(filename3);   
    % Feature extraction (feature vectors as columns)
    [ MFCCs_tmp, FBEs_tmp, frames ] = mfcc( speech, fs, Tw, Ts, alpha, hamming, R, M, C, L );
    MFCCs(:,1:size(MFCCs_tmp,2),3,i) = MFCCs_tmp;
    FBEs(:,1:size(FBEs_tmp,2),3,i) = FBEs_tmp;
end

save('ishikawa_mfcc.mat','MFCCs','FBEs');
