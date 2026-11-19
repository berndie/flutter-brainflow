import 'dart:typed_data';

import '../core/board_data.dart';
import '../core/constants.g.dart';
import '../core/exit_codes.dart';
import '../ffi/data_handler.dart' as native;

/// A power spectral density: [amplitudes] at [frequencies] (Hz).
typedef Psd = ({Float64List amplitudes, Float64List frequencies});

/// A one-sided complex spectrum from [DataFilter.performFft].
typedef Spectrum = ({Float64List re, Float64List im});

/// Wavelet coefficients and the length of each decomposition level, from
/// [DataFilter.performWaveletTransform].
typedef WaveletOutput = ({Float64List coeffs, List<int> lengths});

/// Average and standard deviation of band powers across channels.
typedef BandPowers = ({Float64List avg, Float64List stddev});

/// Signal processing, mirroring BrainFlow's `DataFilter`
/// (<https://brainflow.readthedocs.io/en/stable/UserAPI.html>).
///
/// Methods named `perform...`/`remove...`/`detrend` that return `void`
/// modify their [Float64List] argument in place, like the Python binding
/// does with numpy arrays. Pass a row of [BoardData] (a view) to filter that
/// channel in place.
abstract final class DataFilter {
  // --- Filters (in place) ----------------------------------------------------

  /// Low-pass filter.
  static void performLowpass(
    Float64List data,
    int samplingRate,
    double cutoff,
    int order,
    FilterTypes filterType,
    double ripple,
  ) => native.performLowpass(
    data,
    samplingRate,
    cutoff,
    order,
    filterType.value,
    ripple,
  );

  /// High-pass filter.
  static void performHighpass(
    Float64List data,
    int samplingRate,
    double cutoff,
    int order,
    FilterTypes filterType,
    double ripple,
  ) => native.performHighpass(
    data,
    samplingRate,
    cutoff,
    order,
    filterType.value,
    ripple,
  );

  /// Band-pass filter between [startFreq] and [stopFreq] (Hz).
  static void performBandpass(
    Float64List data,
    int samplingRate,
    double startFreq,
    double stopFreq,
    int order,
    FilterTypes filterType,
    double ripple,
  ) => native.performBandpass(
    data,
    samplingRate,
    startFreq,
    stopFreq,
    order,
    filterType.value,
    ripple,
  );

  /// Band-stop filter between [startFreq] and [stopFreq] (Hz).
  static void performBandstop(
    Float64List data,
    int samplingRate,
    double startFreq,
    double stopFreq,
    int order,
    FilterTypes filterType,
    double ripple,
  ) => native.performBandstop(
    data,
    samplingRate,
    startFreq,
    stopFreq,
    order,
    filterType.value,
    ripple,
  );

  /// Removes power-line noise (50 Hz, 60 Hz or both).
  static void removeEnvironmentalNoise(
    Float64List data,
    int samplingRate,
    NoiseTypes noiseType,
  ) => native.removeEnvironmentalNoise(data, samplingRate, noiseType.value);

  /// Smooths with a rolling mean/median over [period] samples.
  static void performRollingFilter(
    Float64List data,
    int period,
    AggOperations operation,
  ) => native.performRollingFilter(data, period, operation.value);

  /// Removes a constant or linear trend.
  static void detrend(Float64List data, DetrendOperations operation) =>
      native.detrend(data, operation.value);

  /// Wavelet denoising.
  static void performWaveletDenoising(
    Float64List data,
    WaveletTypes wavelet,
    int decompositionLevel, {
    WaveletDenoisingTypes waveletDenoising = WaveletDenoisingTypes.sureshrink,
    ThresholdTypes threshold = ThresholdTypes.hard,
    WaveletExtensionTypes extensionType = WaveletExtensionTypes.symmetric,
    NoiseEstimationLevelTypes noiseLevel = NoiseEstimationLevelTypes.firstLevel,
  }) => native.performWaveletDenoising(
    data,
    wavelet.value,
    decompositionLevel,
    waveletDenoising.value,
    threshold.value,
    extensionType.value,
    noiseLevel.value,
  );

  // --- Transforms ------------------------------------------------------------

  /// Aggregates every [period] samples into one; returns
  /// `data.length ~/ period` values.
  static Float64List performDownsampling(
    Float64List data,
    int period,
    AggOperations operation,
  ) {
    if (period <= 0) {
      throw BrainFlowException(
        'perform_downsampling',
        BrainFlowExitCodes.invalidArgumentsError.value,
      );
    }
    return native.performDownsampling(data, period, operation.value);
  }

  /// Discrete wavelet transform.
  static WaveletOutput performWaveletTransform(
    Float64List data,
    WaveletTypes wavelet,
    int decompositionLevel, {
    WaveletExtensionTypes extensionType = WaveletExtensionTypes.symmetric,
  }) {
    final (coeffs, lengths) = native.performWaveletTransform(
      data,
      wavelet.value,
      decompositionLevel,
      extensionType.value,
    );
    return (coeffs: coeffs, lengths: lengths);
  }

  /// Inverse of [performWaveletTransform].
  static Float64List performInverseWaveletTransform(
    WaveletOutput waveletOutput,
    int originalDataLen,
    WaveletTypes wavelet,
    int decompositionLevel, {
    WaveletExtensionTypes extensionType = WaveletExtensionTypes.symmetric,
  }) => native.performInverseWaveletTransform(
    waveletOutput.coeffs,
    waveletOutput.lengths,
    originalDataLen,
    wavelet.value,
    decompositionLevel,
    extensionType.value,
  );

  /// Reconstructs the signal from the detail coefficients of one level.
  static Float64List restoreDataFromWaveletDetailedCoeffs(
    Float64List data,
    WaveletTypes wavelet,
    int decompositionLevel,
    int levelToRestore,
  ) => native.restoreDataFromWaveletDetailedCoeffs(
    data,
    wavelet.value,
    decompositionLevel,
    levelToRestore,
  );

  /// Peak detection with the smoothed z-score algorithm; returns `1`/`-1`
  /// at positive/negative peaks and `0` elsewhere.
  static Float64List detectPeaksZScore(
    Float64List data, {
    int lag = 5,
    double threshold = 3.5,
    double influence = 0.1,
  }) => native.detectPeaksZScore(data, lag, threshold, influence);

  /// Window function of [windowLen] samples.
  static Float64List getWindow(WindowOperations window, int windowLen) =>
      native.getWindow(window.value, windowLen);

  /// FFT of [data] (even length); returns `data.length ~/ 2 + 1` bins.
  static Spectrum performFft(Float64List data, WindowOperations window) {
    final (re, im) = native.performFft(data, window.value);
    return (re: re, im: im);
  }

  /// Inverse of [performFft]: returns `2 * (bins - 1)` samples.
  static Float64List performIfft(Spectrum spectrum) {
    if (spectrum.re.length != spectrum.im.length) {
      throw ArgumentError('re and im must have the same length');
    }
    return native.performIfft(spectrum.re, spectrum.im);
  }

  /// PSD of [data] (even length).
  static Psd getPsd(
    Float64List data,
    int samplingRate,
    WindowOperations window,
  ) {
    final (a, f) = native.getPsd(data, samplingRate, window.value);
    return (amplitudes: a, frequencies: f);
  }

  /// PSD with Welch's method: segments of [nfft] samples (a power of two)
  /// overlapping by [overlap] samples.
  static Psd getPsdWelch(
    Float64List data,
    int nfft,
    int overlap,
    int samplingRate,
    WindowOperations window,
  ) {
    final (a, f) = native.getPsdWelch(
      data,
      nfft,
      overlap,
      samplingRate,
      window.value,
    );
    return (amplitudes: a, frequencies: f);
  }

  /// Power of [psd] between [freqStart] and [freqEnd] (Hz).
  static double getBandPower(Psd psd, double freqStart, double freqEnd) =>
      native.getBandPower(psd.amplitudes, psd.frequencies, freqStart, freqEnd);

  /// Band powers for delta, theta, alpha, beta and gamma
  /// (2-4, 4-8, 8-13, 13-30, 30-45 Hz), averaged over [channels] of [data].
  static BandPowers getAvgBandPowers(
    BoardData data,
    List<int> channels,
    int samplingRate,
    bool applyFilter,
  ) => getCustomBandPowers(
    data,
    const [(2, 4), (4, 8), (8, 13), (13, 30), (30, 45)],
    channels,
    samplingRate,
    applyFilter,
  );

  /// Powers of [bands] (start, stop in Hz), averaged over [channels] of
  /// [data]. With [applyFilter], data is detrended and filtered first.
  static BandPowers getCustomBandPowers(
    BoardData data,
    List<(double, double)> bands,
    List<int> channels,
    int samplingRate,
    bool applyFilter,
  ) {
    if (channels.isEmpty || bands.isEmpty) {
      throw BrainFlowException(
        'get_custom_band_powers',
        BrainFlowExitCodes.invalidArgumentsError.value,
      );
    }
    final (avg, std) = native.getCustomBandPowers(
      _selectRows(data, channels),
      channels.length,
      data.numSamples,
      Float64List.fromList([for (final b in bands) b.$1]),
      Float64List.fromList([for (final b in bands) b.$2]),
      samplingRate,
      applyFilter,
    );
    return (avg: avg, stddev: std);
  }

  /// Common spatial patterns. Each of [epochs] is a `channels x times`
  /// matrix, all of the same shape; [labels] has one class label per epoch.
  /// Returns the spatial filters (`channels x channels`) and eigenvalues.
  static ({BoardData filters, Float64List eigenvalues}) getCsp(
    List<BoardData> epochs,
    Float64List labels,
  ) {
    if (epochs.isEmpty || labels.length != epochs.length) {
      throw BrainFlowException(
        'get_csp',
        BrainFlowExitCodes.invalidArgumentsError.value,
      );
    }
    final channels = epochs.first.numRows;
    final times = epochs.first.numSamples;
    final flat = Float64List(epochs.length * channels * times);
    for (final (i, e) in epochs.indexed) {
      if (e.numRows != channels || e.numSamples != times) {
        throw ArgumentError('All epochs must have the same shape');
      }
      flat.setAll(i * channels * times, e.data);
    }
    final (filters, eigen) = native.getCsp(
      flat,
      labels,
      epochs.length,
      channels,
      times,
    );
    return (
      filters: BoardData(channels, channels, filters),
      eigenvalues: eigen,
    );
  }

  /// Independent component analysis on [channels] of [data] (all rows if
  /// omitted). Returns the unmixing matrices W and K, the mixing matrix A
  /// and the sources S, as in the Python binding.
  static ({BoardData w, BoardData k, BoardData a, BoardData s}) performIca(
    BoardData data,
    int numComponents, {
    List<int>? channels,
  }) {
    if (numComponents < 1) {
      throw BrainFlowException(
        'perform_ica',
        BrainFlowExitCodes.invalidArgumentsError.value,
      );
    }
    final rows = (channels == null || channels.isEmpty)
        ? [for (var i = 0; i < data.numRows; i++) i]
        : channels;
    final c = numComponents;
    final cols = data.numSamples;
    final (w, k, a, s) = native.performIca(
      _selectRows(data, rows),
      rows.length,
      cols,
      c,
    );
    return (
      w: BoardData(c, c, w),
      k: BoardData(c, rows.length, k),
      a: BoardData(rows.length, c, a),
      s: BoardData(c, cols, s),
    );
  }

  // --- Statistics and biosignals ---------------------------------------------

  /// Standard deviation.
  static double calcStddev(Float64List data) => native.calcStddev(data);

  /// Percentage of samples near the ADC rails for amplifier [gain].
  static double getRailedPercentage(Float64List data, int gain) =>
      native.getRailedPercentage(data, gain);

  /// SpO2 from infrared and red PPG of equal length.
  static double getOxygenLevel(
    Float64List ppgIr,
    Float64List ppgRed,
    int samplingRate, {
    double coef1 = 1.5958422,
    double coef2 = -34.6596622,
    double coef3 = 112.6898759,
  }) {
    _checkSameLength('get_oxygen_level', [ppgIr, ppgRed]);
    return native.getOxygenLevel(
      ppgIr,
      ppgRed,
      samplingRate,
      coef1,
      coef2,
      coef3,
    );
  }

  /// Heart rate (beats per minute) from infrared and red PPG.
  static double getHeartRate(
    Float64List ppgIr,
    Float64List ppgRed,
    int samplingRate,
    int fftSize,
  ) {
    _checkSameLength('get_heart_rate', [ppgIr, ppgRed]);
    return native.getHeartRate(ppgIr, ppgRed, samplingRate, fftSize);
  }

  /// Activity index from 3-axis accelerometer data, one value per epoch of
  /// [period] samples (a multiple of [samplingRate]; default: as many whole
  /// seconds as the data has).
  static Float64List getActivityIndex(
    Float64List accelX,
    Float64List accelY,
    Float64List accelZ,
    int samplingRate, {
    int period = 0,
    double noiseVarX = 0,
    double noiseVarY = 0,
    double noiseVarZ = 0,
  }) {
    const fn = 'get_activity_index';
    _checkSameLength(fn, [accelX, accelY, accelZ]);
    final len = accelX.length;
    if (samplingRate <= 0 || len < samplingRate) _invalid(fn);
    if (period <= 0) period = len - len % samplingRate;
    if (period < samplingRate || len < period || period % samplingRate != 0) {
      _invalid(fn);
    }
    if (noiseVarX < 0 || noiseVarY < 0 || noiseVarZ < 0) _invalid(fn);
    return native.getActivityIndex(
      accelX,
      accelY,
      accelZ,
      samplingRate,
      period,
      noiseVarX,
      noiseVarY,
      noiseVarZ,
    );
  }

  /// The power of two nearest to [value].
  static int getNearestPowerOfTwo(int value) =>
      native.getNearestPowerOfTwo(value);

  // --- Files -----------------------------------------------------------------

  /// Writes [data] as a BrainFlow CSV file (one line per sample);
  /// [fileMode] is `w` (overwrite) or `a` (append).
  static void writeFile(BoardData data, String fileName, String fileMode) =>
      native.writeFile(
        data.data,
        data.numRows,
        data.numSamples,
        fileName,
        fileMode,
      );

  /// Reads a file written by [writeFile] or a file streamer.
  static BoardData readFile(String fileName) {
    final (data, rows, cols) = native.readFile(fileName);
    return BoardData(rows, cols, data);
  }

  // --- Logging and version ---------------------------------------------------

  /// Sets the log level of the data handler.
  static void setLogLevel(LogLevels level) => native.setLogLevel(level.value);

  /// Logs at info level and above.
  static void enableDataLogger() => setLogLevel(LogLevels.levelInfo);

  /// Logs everything (trace level).
  static void enableDevDataLogger() => setLogLevel(LogLevels.levelTrace);

  /// Disables logging.
  static void disableDataLogger() => setLogLevel(LogLevels.levelOff);

  /// Redirects the data handler log to the file at [path].
  static void setLogFile(String path) => native.setLogFile(path);

  /// Writes [message] to the data handler log.
  static void logMessage(LogLevels level, String message) =>
      native.logMessage(level.value, message);

  /// Version of the native data handler library, e.g. `5.23.0`.
  static String getVersion() => native.getVersion();

  // --- Helpers ---------------------------------------------------------------

  static Float64List _selectRows(BoardData data, List<int> rows) {
    final out = Float64List(rows.length * data.numSamples);
    for (final (i, r) in rows.indexed) {
      out.setAll(i * data.numSamples, data.row(r));
    }
    return out;
  }

  static void _checkSameLength(String fn, List<Float64List> arrays) {
    if (arrays.any((a) => a.length != arrays.first.length)) _invalid(fn);
  }

  static Never _invalid(String fn) => throw BrainFlowException(
    fn,
    BrainFlowExitCodes.invalidArgumentsError.value,
  );
}
