 % --- 音声保存用補助関数 ---
    function save_recog_audio(buffer, Fs, idx, outDir)
        if ~exist(outDir, 'dir'), mkdir(outDir); end
        timestamp = datestr(now, 'yyyymmddHHMMSSFFF');
        fname = fullfile(outDir, sprintf('recog_idx%d_%s.wav', idx, timestamp));
        audiowrite(fname, buffer / (max(abs(buffer)) + eps), Fs);
        disp(['💾 保存完了: ', fname]);
    end