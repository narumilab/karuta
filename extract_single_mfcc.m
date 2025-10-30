%単一ファイル用のwavtomfcc
function mfcc_matrix = extract_single_mfcc(y, Fs)
    % extract_single_mfcc: 単一の音声信号からMFCC特徴量（係数、デルタ、ダブルデルタ）を抽出します。
    %
    % 入力:
    %   y: 音声信号の波形データ（ベクトル）
    %   Fs: サンプリング周波数 (Hz)
    %
    % 出力:
    %   mfcc_matrix: 結合された特徴量行列 [フレーム数 x (MFCC次元 * 3)]
    
    % HMM認識用のMFCC特徴量を抽出します。
    % 適切なMFCCライブラリ（例: MATLABのAudio Toolbox）の mfcc 関数を使用して、
    % 係数、デルタ、ダブルデルタを計算します。
    
    % mfcc 関数は通常、以下の3つの出力を返します。
    % coeffs: MFCC係数
    % delta: 1次微分 (速度)
    % deltaDelta: 2次微分 (加速度)
    % ※ mfcc関数の引数は既定値を使用することを前提とします。
    [coeffs, delta, deltaDelta] = mfcc(y, Fs);
    
    % HMM認識用に、これら3つの特徴量を水平方向に結合します。
    % 結果として得られる行列のサイズは [フレーム数 x (D*3)] となります。
    mfcc_matrix = [coeffs delta deltaDelta];
end
