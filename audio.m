
%%%
%%% passthough test. 10ms latency measured with blackhole.
%%%
clear;

buffsize = 32; 
sfrq = 48000;


deviceReader = audioDeviceReader;
devices = getAudioDevices(deviceReader)
aPR = audioPlayerRecorder('Device', 'ZOOM UAC-2 ASIO Driver', 'SampleRate',sfrq, 'BufferSize', buffsize, 'RecorderChannelMapping', [1], 'PlayerChannelMapping', [1]);



tic
out_buf_device = zeros(buffsize, 1);
in_buf_device = zeros(buffsize, 1);
while(1)
    [audioRecorded,nUnderruns,nOverruns] = aPR(in_buf_device);
    disp(audioRecorded(1, 1));
end
toc