// Dart-typed wrappers over the data handler C API. Inputs are copied into
// native memory, outputs copied back into Dart memory. Enum arguments are
// their BrainFlow integer values; `data_filter/` maps them.
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'data_handler.g.dart' as dh;
import 'native_utils.dart';

/// Copies [data] into native memory, lets [call] modify it, copies it back.
void _inPlace(
  String function,
  Float64List data,
  int Function(Pointer<Double> buf, int len) call,
) => using((arena) {
  final buf = doubleBuffer(arena, data);
  checkExitCode(call(buf, data.length), function);
  data.setAll(0, buf.asTypedList(data.length));
});

/// Calls [call] with [data] in native memory and a zeroed output buffer of
/// [outLen] doubles; returns the output.
Float64List _transform(
  String function,
  Float64List data,
  int outLen,
  int Function(Pointer<Double> buf, int len, Pointer<Double> out) call,
) => using((arena) {
  final buf = doubleBuffer(arena, data);
  final out = arena<Double>(outLen < 1 ? 1 : outLen);
  checkExitCode(call(buf, data.length, out), function);
  return copyDoubles(out, outLen);
});

/// Calls [call] with [data] in native memory; returns its single double.
double _scalar(
  String function,
  Float64List data,
  int Function(Pointer<Double> buf, int len, Pointer<Double> out) call,
) => _transform(function, data, 1, call)[0];

// --- Filters (in place) ------------------------------------------------------

/// `perform_lowpass`.
void performLowpass(
  Float64List data,
  int samplingRate,
  double cutoff,
  int order,
  int filterType,
  double ripple,
) => _inPlace(
  'perform_lowpass',
  data,
  (b, n) =>
      dh.perform_lowpass(b, n, samplingRate, cutoff, order, filterType, ripple),
);

/// `perform_highpass`.
void performHighpass(
  Float64List data,
  int samplingRate,
  double cutoff,
  int order,
  int filterType,
  double ripple,
) => _inPlace(
  'perform_highpass',
  data,
  (b, n) => dh.perform_highpass(
    b,
    n,
    samplingRate,
    cutoff,
    order,
    filterType,
    ripple,
  ),
);

/// `perform_bandpass`.
void performBandpass(
  Float64List data,
  int samplingRate,
  double startFreq,
  double stopFreq,
  int order,
  int filterType,
  double ripple,
) => _inPlace(
  'perform_bandpass',
  data,
  (b, n) => dh.perform_bandpass(
    b,
    n,
    samplingRate,
    startFreq,
    stopFreq,
    order,
    filterType,
    ripple,
  ),
);

/// `perform_bandstop`.
void performBandstop(
  Float64List data,
  int samplingRate,
  double startFreq,
  double stopFreq,
  int order,
  int filterType,
  double ripple,
) => _inPlace(
  'perform_bandstop',
  data,
  (b, n) => dh.perform_bandstop(
    b,
    n,
    samplingRate,
    startFreq,
    stopFreq,
    order,
    filterType,
    ripple,
  ),
);

/// `remove_environmental_noise`.
void removeEnvironmentalNoise(
  Float64List data,
  int samplingRate,
  int noiseType,
) => _inPlace(
  'remove_environmental_noise',
  data,
  (b, n) => dh.remove_environmental_noise(b, n, samplingRate, noiseType),
);

/// `perform_rolling_filter`.
void performRollingFilter(Float64List data, int period, int operation) =>
    _inPlace(
      'perform_rolling_filter',
      data,
      (b, n) => dh.perform_rolling_filter(b, n, period, operation),
    );

/// `detrend`.
void detrend(Float64List data, int operation) =>
    _inPlace('detrend', data, (b, n) => dh.detrend(b, n, operation));

/// `perform_wavelet_denoising`.
void performWaveletDenoising(
  Float64List data,
  int wavelet,
  int level,
  int denoising,
  int threshold,
  int extension,
  int noiseLevel,
) => _inPlace(
  'perform_wavelet_denoising',
  data,
  (b, n) => dh.perform_wavelet_denoising(
    b,
    n,
    wavelet,
    level,
    denoising,
    threshold,
    extension,
    noiseLevel,
  ),
);

// --- Transforms --------------------------------------------------------------

/// `perform_downsampling`.
Float64List performDownsampling(Float64List data, int period, int operation) =>
    _transform(
      'perform_downsampling',
      data,
      data.length ~/ period,
      (b, n, o) => dh.perform_downsampling(b, n, period, operation, o),
    );

/// `perform_wavelet_transform`: returns coefficients and the lengths of
/// each decomposition level.
(Float64List, List<int>) performWaveletTransform(
  Float64List data,
  int wavelet,
  int level,
  int extension,
) => using((arena) {
  final buf = doubleBuffer(arena, data);
  // Same upper bound as the Python binding.
  final maxLen = data.length + 2 * level * (40 + 1);
  final out = arena<Double>(maxLen);
  final lengths = arena<Int>(level + 1);
  checkExitCode(
    dh.perform_wavelet_transform(
      buf,
      data.length,
      wavelet,
      level,
      extension,
      out,
      lengths,
    ),
    'perform_wavelet_transform',
  );
  final lens = [for (var i = 0; i <= level; i++) lengths[i]];
  return (copyDoubles(out, lens.fold(0, (a, b) => a + b)), lens);
});

/// `perform_inverse_wavelet_transform`.
Float64List performInverseWaveletTransform(
  Float64List coeffs,
  List<int> lengths,
  int originalLen,
  int wavelet,
  int level,
  int extension,
) => using((arena) {
  final buf = doubleBuffer(arena, coeffs);
  final lens = arena<Int>(lengths.isEmpty ? 1 : lengths.length);
  for (final (i, l) in lengths.indexed) {
    lens[i] = l;
  }
  final out = arena<Double>(originalLen < 1 ? 1 : originalLen);
  checkExitCode(
    dh.perform_inverse_wavelet_transform(
      buf,
      originalLen,
      wavelet,
      level,
      extension,
      lens,
      out,
    ),
    'perform_inverse_wavelet_transform',
  );
  return copyDoubles(out, originalLen);
});

/// `restore_data_from_wavelet_detailed_coeffs`.
Float64List restoreDataFromWaveletDetailedCoeffs(
  Float64List data,
  int wavelet,
  int level,
  int levelToRestore,
) => _transform(
  'restore_data_from_wavelet_detailed_coeffs',
  data,
  data.length,
  (b, n, o) => dh.restore_data_from_wavelet_detailed_coeffs(
    b,
    n,
    wavelet,
    level,
    levelToRestore,
    o,
  ),
);

/// `detect_peaks_z_score`.
Float64List detectPeaksZScore(
  Float64List data,
  int lag,
  double threshold,
  double influence,
) => _transform(
  'detect_peaks_z_score',
  data,
  data.length,
  (b, n, o) => dh.detect_peaks_z_score(b, n, lag, threshold, influence, o),
);

/// `get_window`.
Float64List getWindow(int window, int len) => using((arena) {
  final out = arena<Double>(len < 1 ? 1 : len);
  checkExitCode(dh.get_window(window, len, out), 'get_window');
  return copyDoubles(out, len);
});

/// `perform_fft`: returns (re, im), each `len / 2 + 1` long.
(Float64List, Float64List) performFft(Float64List data, int window) =>
    using((arena) {
      final buf = doubleBuffer(arena, data);
      final n = data.length ~/ 2 + 1;
      final re = arena<Double>(n);
      final im = arena<Double>(n);
      checkExitCode(
        dh.perform_fft(buf, data.length, window, re, im),
        'perform_fft',
      );
      return (copyDoubles(re, n), copyDoubles(im, n));
    });

/// `perform_ifft`: [re] and [im] have `n / 2 + 1` values; returns `n`.
Float64List performIfft(Float64List re, Float64List im) => using((arena) {
  final n = 2 * (re.length - 1);
  final out = arena<Double>(n < 1 ? 1 : n);
  checkExitCode(
    dh.perform_ifft(doubleBuffer(arena, re), doubleBuffer(arena, im), n, out),
    'perform_ifft',
  );
  return copyDoubles(out, n);
});

/// `get_psd` / `get_psd_welch` share this output shape: (ampl, freq).
(Float64List, Float64List) _psd(
  String function,
  Float64List data,
  int outLen,
  int Function(Pointer<Double>, Pointer<Double>, Pointer<Double>) call,
) => using((arena) {
  final buf = doubleBuffer(arena, data);
  final ampl = arena<Double>(outLen);
  final freq = arena<Double>(outLen);
  checkExitCode(call(buf, ampl, freq), function);
  return (copyDoubles(ampl, outLen), copyDoubles(freq, outLen));
});

/// `get_psd`.
(Float64List, Float64List) getPsd(
  Float64List data,
  int samplingRate,
  int window,
) => _psd(
  'get_psd',
  data,
  data.length ~/ 2 + 1,
  (b, a, f) => dh.get_psd(b, data.length, samplingRate, window, a, f),
);

/// `get_psd_welch`.
(Float64List, Float64List) getPsdWelch(
  Float64List data,
  int nfft,
  int overlap,
  int samplingRate,
  int window,
) => _psd(
  'get_psd_welch',
  data,
  nfft ~/ 2 + 1,
  (b, a, f) => dh.get_psd_welch(
    b,
    data.length,
    nfft,
    overlap,
    samplingRate,
    window,
    a,
    f,
  ),
);

/// `get_band_power`.
double getBandPower(
  Float64List ampl,
  Float64List freq,
  double start,
  double end,
) => using((arena) {
  final out = arena<Double>();
  checkExitCode(
    dh.get_band_power(
      doubleBuffer(arena, ampl),
      doubleBuffer(arena, freq),
      ampl.length,
      start,
      end,
      out,
    ),
    'get_band_power',
  );
  return out.value;
});

/// `get_custom_band_powers`: [data] is row-major `rows x cols`.
(Float64List, Float64List) getCustomBandPowers(
  Float64List data,
  int rows,
  int cols,
  Float64List starts,
  Float64List stops,
  int samplingRate,
  bool applyFilters,
) => using((arena) {
  final n = starts.length;
  final avg = arena<Double>(n);
  final std = arena<Double>(n);
  checkExitCode(
    dh.get_custom_band_powers(
      doubleBuffer(arena, data),
      rows,
      cols,
      doubleBuffer(arena, starts),
      doubleBuffer(arena, stops),
      n,
      samplingRate,
      applyFilters ? 1 : 0,
      avg,
      std,
    ),
    'get_custom_band_powers',
  );
  return (copyDoubles(avg, n), copyDoubles(std, n));
});

/// `get_csp`: [data] is row-major `epochs x channels x times`. Returns
/// filters (`channels x channels`, row-major) and eigenvalues.
(Float64List, Float64List) getCsp(
  Float64List data,
  Float64List labels,
  int epochs,
  int channels,
  int times,
) => using((arena) {
  final filters = arena<Double>(channels * channels);
  final eigen = arena<Double>(channels);
  checkExitCode(
    dh.get_csp(
      doubleBuffer(arena, data),
      doubleBuffer(arena, labels),
      epochs,
      channels,
      times,
      filters,
      eigen,
    ),
    'get_csp',
  );
  return (
    copyDoubles(filters, channels * channels),
    copyDoubles(eigen, channels),
  );
});

/// `perform_ica`: [data] is row-major `rows x cols`. Returns row-major
/// W (`c x c`), K (`c x rows`), A (`rows x c`), S (`c x cols`).
(Float64List, Float64List, Float64List, Float64List) performIca(
  Float64List data,
  int rows,
  int cols,
  int components,
) => using((arena) {
  final c = components;
  final w = arena<Double>(c * c);
  final k = arena<Double>(c * rows);
  final a = arena<Double>(rows * c);
  final s = arena<Double>(c * cols);
  checkExitCode(
    dh.perform_ica(doubleBuffer(arena, data), rows, cols, c, w, k, a, s),
    'perform_ica',
  );
  return (
    copyDoubles(w, c * c),
    copyDoubles(k, c * rows),
    copyDoubles(a, rows * c),
    copyDoubles(s, c * cols),
  );
});

// --- Scalars -----------------------------------------------------------------

/// `calc_stddev` over the whole array.
double calcStddev(Float64List data) =>
    _scalar('calc_stddev', data, (b, n, o) => dh.calc_stddev(b, 0, n, o));

/// `get_railed_percentage`.
double getRailedPercentage(Float64List data, int gain) => _scalar(
  'get_railed_percentage',
  data,
  (b, n, o) => dh.get_railed_percentage(b, n, gain, o),
);

/// `get_oxygen_level`.
double getOxygenLevel(
  Float64List ir,
  Float64List red,
  int samplingRate,
  double coef1,
  double coef2,
  double coef3,
) => using((arena) {
  final out = arena<Double>();
  checkExitCode(
    dh.get_oxygen_level(
      doubleBuffer(arena, ir),
      doubleBuffer(arena, red),
      ir.length,
      samplingRate,
      coef1,
      coef2,
      coef3,
      out,
    ),
    'get_oxygen_level',
  );
  return out.value;
});

/// `get_heart_rate`.
double getHeartRate(
  Float64List ir,
  Float64List red,
  int samplingRate,
  int fftSize,
) => using((arena) {
  final out = arena<Double>();
  checkExitCode(
    dh.get_heart_rate(
      doubleBuffer(arena, ir),
      doubleBuffer(arena, red),
      ir.length,
      samplingRate,
      fftSize,
      out,
    ),
    'get_heart_rate',
  );
  return out.value;
});

/// `get_activity_index`: one value per epoch of [period] samples.
Float64List getActivityIndex(
  Float64List x,
  Float64List y,
  Float64List z,
  int samplingRate,
  int period,
  double noiseX,
  double noiseY,
  double noiseZ,
) => using((arena) {
  final epochs = x.length ~/ period;
  final out = arena<Double>(epochs < 1 ? 1 : epochs);
  checkExitCode(
    dh.get_activity_index(
      doubleBuffer(arena, x),
      doubleBuffer(arena, y),
      doubleBuffer(arena, z),
      x.length,
      samplingRate,
      period,
      noiseX,
      noiseY,
      noiseZ,
      out,
    ),
    'get_activity_index',
  );
  return copyDoubles(out, epochs);
});

/// `get_nearest_power_of_two`.
int getNearestPowerOfTwo(int value) => readInt(
  'get_nearest_power_of_two',
  (out) => dh.get_nearest_power_of_two(value, out),
);

// --- Files -------------------------------------------------------------------

/// `write_file`: [data] is row-major `rows x cols`.
void writeFile(
  Float64List data,
  int rows,
  int cols,
  String fileName,
  String mode,
) => using((arena) {
  checkExitCode(
    dh.write_file(
      doubleBuffer(arena, data),
      rows,
      cols,
      cString(arena, fileName),
      cString(arena, mode),
    ),
    'write_file',
  );
});

/// `read_file`: returns row-major data and its shape.
(Float64List, int, int) readFile(String fileName) => using((arena) {
  final name = cString(arena, fileName);
  final count = readInt(
    'get_num_elements_in_file',
    (out) => dh.get_num_elements_in_file(name, out),
  );
  final buf = arena<Double>(count < 1 ? 1 : count);
  final rows = arena<Int>();
  final cols = arena<Int>();
  checkExitCode(dh.read_file(buf, rows, cols, name, count), 'read_file');
  return (copyDoubles(buf, rows.value * cols.value), rows.value, cols.value);
});

// --- Logging and version -----------------------------------------------------

/// `set_log_level_data_handler`.
void setLogLevel(int level) => checkExitCode(
  dh.set_log_level_data_handler(level),
  'set_log_level_data_handler',
);

/// `set_log_file_data_handler`.
void setLogFile(String path) => using((arena) {
  checkExitCode(
    dh.set_log_file_data_handler(cString(arena, path)),
    'set_log_file_data_handler',
  );
});

/// `log_message_data_handler`.
void logMessage(int level, String message) => using((arena) {
  checkExitCode(
    dh.log_message_data_handler(level, cString(arena, message)),
    'log_message_data_handler',
  );
});

/// `get_version_data_handler`.
String getVersion() => readString(
  'get_version_data_handler',
  dh.get_version_data_handler,
  maxLen: 64,
);
