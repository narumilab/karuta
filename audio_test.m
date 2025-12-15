% capture_device.m 例: 内蔵マイクから2秒録音して保存
Fs = 44100;
dev = 'MacBook Proのマイク';  % realtime_try と同じデバイス名に
deviceReader = audioDeviceReader('Device', dev, ...
    'SampleRate', Fs, 'SamplesPerFrame', round(0.01*Fs)); % 10ms刻み
secondsToCapture = 2;
buf = [];
tic;
while toc < secondsToCapture
    disp('Capturing audio...');
    buf = [buf; deviceReader()];
end
release(deviceReader);
audiowrite('captured_mic.wav', buf, Fs);
disp('captured_mic.wav を保存しました。元の WAV と聞き比べ/波形比較してください。');

% 簡易比較（任意）: 元WAVとRMSや相関を見る
[src, Fs_src] = audioread('./aihara_test/nageke/nageke1.wav');   % 再生した元ファイル
if Fs_src ~= Fs
    src = resample(src, Fs, Fs_src);
end
minlen = min(length(src), length(buf));
fprintf('RMS(src)=%.4f, RMS(captured)=%.4f\n', rms(src(1:minlen)), rms(buf(1:minlen)));
corr = corrcoef(src(1:minlen), buf(1:minlen));
fprintf('相関係数(先頭%gサンプル) = %.3f\n', minlen, corr(1,2));
