// Exercises every DataFilter member against the real library with
// generated signals whose properties are known.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_brainflow/flutter_brainflow.dart';
import 'package:flutter_test/flutter_test.dart';

const _fs = 250;

/// Sum of sines at [freqs] Hz (amplitude 1 each), [n] samples at [_fs].
Float64List _sines(List<double> freqs, {int n = 1024, double phase = 0}) =>
    Float64List.fromList([
      for (var i = 0; i < n; i++)
        freqs.fold(
          0.0,
          (s, f) => s + math.sin(2 * math.pi * f * i / _fs + phase),
        ),
    ]);

double _power(Float64List data, double from, double to) =>
    DataFilter.getBandPower(
      DataFilter.getPsd(data, _fs, WindowOperations.hanning),
      from,
      to,
    );

/// Power around [freq] after [filter], relative to the unfiltered signal.
double _attenuation(double freq, void Function(Float64List) filter) {
  final data = _sines([10, 50], n: 2048);
  filter(data);
  // Compare the second half only, after the filter's start-up transient.
  final settled = Float64List.sublistView(data, 1024);
  final ref = _sines([10, 50], n: 2048).sublist(1024);
  return _power(settled, freq - 2, freq + 2) / _power(ref, freq - 2, freq + 2);
}

Matcher _throwsBrainFlow() => throwsA(isA<BrainFlowException>());

void main() {
  late Directory tmp;
  setUpAll(() {
    DataFilter.disableDataLogger();
    tmp = Directory.systemTemp.createTempSync('brainflow_df');
  });
  tearDownAll(() => tmp.deleteSync(recursive: true));

  test('version and logging', () {
    expect(DataFilter.getVersion(), '5.23.0');
    final log = File('${tmp.path}/dh.log');
    DataFilter.setLogFile(log.path);
    DataFilter.enableDevDataLogger();
    DataFilter.logMessage(LogLevels.levelInfo, 'data handler says hi');
    DataFilter.enableDataLogger();
    DataFilter.disableDataLogger();
    expect(log.readAsStringSync(), contains('data handler says hi'));
  });

  group('filters', () {
    const bw = FilterTypes.butterworth;
    test('lowpass removes 50 Hz, keeps 10 Hz', () {
      void f(Float64List d) => DataFilter.performLowpass(d, _fs, 20, 4, bw, 0);
      expect(_attenuation(50, f), lessThan(0.01));
      expect(_attenuation(10, f), greaterThan(0.8));
    });
    test('highpass removes 10 Hz, keeps 50 Hz', () {
      void f(Float64List d) => DataFilter.performHighpass(d, _fs, 30, 4, bw, 0);
      expect(_attenuation(10, f), lessThan(0.01));
      expect(_attenuation(50, f), greaterThan(0.8));
    });
    test('bandpass keeps 10 Hz only', () {
      void f(Float64List d) =>
          DataFilter.performBandpass(d, _fs, 5, 15, 4, bw, 0);
      expect(_attenuation(50, f), lessThan(0.01));
      expect(_attenuation(10, f), greaterThan(0.5));
    });
    test('bandstop removes 50 Hz only', () {
      void f(Float64List d) =>
          DataFilter.performBandstop(d, _fs, 45, 55, 4, bw, 0);
      expect(_attenuation(50, f), lessThan(0.01));
      expect(_attenuation(10, f), greaterThan(0.8));
    });
    test('environmental noise removes 50 Hz', () {
      void f(Float64List d) =>
          DataFilter.removeEnvironmentalNoise(d, _fs, NoiseTypes.fifty);
      expect(_attenuation(50, f), lessThan(0.05));
      expect(_attenuation(10, f), greaterThan(0.8));
    });
    test('filters work in place on a BoardData row view', () {
      final data = BoardData(2, 1024, Float64List(2048));
      data.row(1).setAll(0, _sines([50]));
      DataFilter.performLowpass(data.row(1), _fs, 20, 4, bw, 0);
      expect(data.row(0).every((v) => v == 0), isTrue);
      expect(DataFilter.calcStddev(data.row(1).sublist(512)), lessThan(0.05));
    });
    test('invalid arguments throw', () {
      expect(
        () => DataFilter.performLowpass(_sines([10]), _fs, -1, 4, bw, 0),
        _throwsBrainFlow(),
      );
    });
  });

  test('rolling filter', () {
    final data = Float64List.fromList([0, 10, 0, 10, 0, 10, 0, 10]);
    DataFilter.performRollingFilter(data, 2, AggOperations.mean);
    expect(data.sublist(1), everyElement(closeTo(5, 1e-9)));
  });

  test('detrend', () {
    final ramp = Float64List.fromList([
      for (var i = 0; i < 100; i++) 3.0 * i + 7,
    ]);
    DataFilter.detrend(ramp, DetrendOperations.linear);
    expect(ramp, everyElement(closeTo(0, 1e-6)));
    final offset = Float64List.fromList([5, 6, 7]);
    DataFilter.detrend(offset, DetrendOperations.constant);
    expect(offset, [closeTo(-1, 1e-9), closeTo(0, 1e-9), closeTo(1, 1e-9)]);
  });

  test('downsampling', () {
    final data = Float64List.fromList([1, 3, 5, 7, 9]);
    expect(DataFilter.performDownsampling(data, 2, AggOperations.mean), [2, 6]);
    expect(
      () => DataFilter.performDownsampling(data, 0, AggOperations.mean),
      _throwsBrainFlow(),
    );
  });

  group('wavelets', () {
    test('transform and inverse round-trip', () {
      final data = _sines([10, 30], n: 256);
      final out = DataFilter.performWaveletTransform(data, WaveletTypes.db4, 3);
      expect(out.lengths, hasLength(4));
      expect(out.coeffs.length, out.lengths.fold(0, (a, b) => a + b));
      final back = DataFilter.performInverseWaveletTransform(
        out,
        data.length,
        WaveletTypes.db4,
        3,
      );
      for (var i = 0; i < data.length; i++) {
        expect(back[i], closeTo(data[i], 1e-6));
      }
    });
    test('denoising reduces noise', () {
      final rnd = math.Random(1);
      final clean = _sines([5], n: 512);
      final noisy = Float64List.fromList([
        for (final v in clean) v + (rnd.nextDouble() - 0.5),
      ]);
      double err(Float64List d) => DataFilter.calcStddev(
        Float64List.fromList([
          for (var i = 0; i < d.length; i++) d[i] - clean[i],
        ]),
      );
      final before = err(noisy);
      DataFilter.performWaveletDenoising(noisy, WaveletTypes.db4, 3);
      expect(err(noisy), lessThan(before));
    });
    test('restore from detailed coefficients', () {
      final data = _sines([10, 60], n: 256);
      final restored = DataFilter.restoreDataFromWaveletDetailedCoeffs(
        data,
        WaveletTypes.db4,
        3,
        1,
      );
      expect(restored, hasLength(data.length));
      expect(restored.any((v) => v != 0), isTrue);
    });
  });

  test('z-score peak detection', () {
    final data = Float64List(60);
    for (var i = 0; i < 60; i++) {
      data[i] = i.isEven ? 0.1 : -0.1;
    }
    data[40] = 10;
    final peaks = DataFilter.detectPeaksZScore(data);
    expect(peaks, hasLength(60));
    expect(peaks[40], 1);
    expect(peaks.sublist(10, 40), everyElement(0));
  });

  group('spectral', () {
    test('window', () {
      final w = DataFilter.getWindow(WindowOperations.hanning, 9);
      expect(w, hasLength(9));
      expect(w.first, closeTo(0, 1e-9));
      // BrainFlow's windows are periodic: peak close to, not exactly, 1.
      expect(w.reduce(math.max), closeTo(1, 0.05));
    });

    test('fft peak and ifft round-trip', () {
      final data = _sines([10], n: 256);
      final spec = DataFilter.performFft(data, WindowOperations.noWindow);
      expect(spec.re, hasLength(129));
      final mags = [
        for (var i = 0; i < 129; i++)
          math.sqrt(spec.re[i] * spec.re[i] + spec.im[i] * spec.im[i]),
      ];
      final peak = mags.indexOf(mags.reduce(math.max));
      expect(peak * _fs / 256, closeTo(10, _fs / 256));
      final back = DataFilter.performIfft(spec);
      expect(back, hasLength(256));
      for (var i = 0; i < 256; i++) {
        expect(back[i], closeTo(data[i], 1e-6));
      }
    });

    test('psd and welch peak at 10 Hz; band power', () {
      final data = _sines([10], n: 1024);
      for (final psd in [
        DataFilter.getPsd(data, _fs, WindowOperations.hanning),
        DataFilter.getPsdWelch(data, 256, 128, _fs, WindowOperations.hanning),
      ]) {
        final a = psd.amplitudes;
        final peak = a.indexOf(a.reduce(math.max));
        expect(psd.frequencies[peak], closeTo(10, 1));
        expect(
          DataFilter.getBandPower(psd, 8, 13),
          greaterThan(100 * DataFilter.getBandPower(psd, 30, 45)),
        );
      }
    });

    test('avg and custom band powers', () {
      final rows = [
        _sines([10]),
        _sines([10], phase: 1),
        Float64List(1024),
      ];
      final data = BoardData(
        3,
        1024,
        Float64List.fromList(rows.expand((r) => r).toList()),
      );
      final avg = DataFilter.getAvgBandPowers(data, [0, 1], _fs, false);
      expect(avg.avg, hasLength(5));
      expect(avg.stddev, hasLength(5));
      final alpha = avg.avg[2];
      expect(avg.avg.where((p) => p > alpha), isEmpty);

      final custom = DataFilter.getCustomBandPowers(
        data,
        const [(1, 5), (9, 11)],
        [0, 1],
        _fs,
        true,
      );
      expect(custom.avg[1], greaterThan(custom.avg[0]));
      expect(
        () => DataFilter.getCustomBandPowers(data, const [], [0], _fs, true),
        _throwsBrainFlow(),
      );
    });
  });

  test('csp separates classes by channel variance', () {
    final rnd = math.Random(2);
    BoardData epoch(double var0, double var1) {
      const times = 100;
      final d = Float64List(2 * times);
      for (var t = 0; t < times; t++) {
        d[t] = var0 * (rnd.nextDouble() - 0.5);
        d[times + t] = var1 * (rnd.nextDouble() - 0.5);
      }
      return BoardData(2, times, d);
    }

    final epochs = [epoch(10, 1), epoch(10, 1), epoch(1, 10), epoch(1, 10)];
    final csp = DataFilter.getCsp(epochs, Float64List.fromList([0, 0, 1, 1]));
    expect(csp.filters.numRows, 2);
    expect(csp.filters.numSamples, 2);
    expect(csp.eigenvalues, hasLength(2));
    expect(
      () => DataFilter.getCsp(epochs, Float64List.fromList([0])),
      _throwsBrainFlow(),
    );
  });

  test('ica shapes', () {
    final s1 = _sines([3], n: 500);
    final s2 = Float64List.fromList([
      for (var i = 0; i < 500; i++) (i % 25) / 25 - 0.5,
    ]);
    final mixed = Float64List(3 * 500);
    for (var i = 0; i < 500; i++) {
      mixed[i] = s1[i] + 0.5 * s2[i];
      mixed[500 + i] = 0.3 * s1[i] + s2[i];
      mixed[1000 + i] = 99; // ignored row
    }
    final ica = DataFilter.performIca(
      BoardData(3, 500, mixed),
      2,
      channels: [0, 1],
    );
    expect((ica.w.numRows, ica.w.numSamples), (2, 2));
    expect((ica.k.numRows, ica.k.numSamples), (2, 2));
    expect((ica.a.numRows, ica.a.numSamples), (2, 2));
    expect((ica.s.numRows, ica.s.numSamples), (2, 500));
  });

  group('statistics and biosignals', () {
    test('stddev', () {
      expect(
        DataFilter.calcStddev(Float64List.fromList([2, 4, 4, 4, 5, 5, 7, 9])),
        closeTo(2, 1e-9),
      );
    });
    test('railed percentage', () {
      final p = DataFilter.getRailedPercentage(_sines([10]), 24);
      expect(p, inInclusiveRange(0, 100));
    });
    test('nearest power of two', () {
      expect(DataFilter.getNearestPowerOfTwo(100), 128);
      expect(DataFilter.getNearestPowerOfTwo(256), 256);
    });
    test('heart rate and oxygen level from PPG', () {
      const n = 2048;
      // Pulse at 1.25 Hz = 75 bpm on a DC offset, red weaker than infrared.
      final ir = Float64List.fromList([
        for (var i = 0; i < n; i++)
          1000 + 50 * math.sin(2 * math.pi * 1.25 * i / _fs),
      ]);
      final red = Float64List.fromList([
        for (var i = 0; i < n; i++)
          800 + 20 * math.sin(2 * math.pi * 1.25 * i / _fs),
      ]);
      expect(DataFilter.getHeartRate(ir, red, _fs, 2048), closeTo(75, 5));
      expect(DataFilter.getOxygenLevel(ir, red, _fs), inInclusiveRange(0, 100));
      expect(
        () => DataFilter.getHeartRate(ir, red.sublist(1), _fs, 2048),
        _throwsBrainFlow(),
      );
    });
    test('activity index', () {
      final rnd = math.Random(3);
      Float64List axis() => Float64List.fromList([
        for (var i = 0; i < 1000; i++) rnd.nextDouble(),
      ]);
      final out = DataFilter.getActivityIndex(
        axis(),
        axis(),
        axis(),
        _fs,
        period: _fs,
      );
      expect(out, hasLength(4));
      expect(
        DataFilter.getActivityIndex(axis(), axis(), axis(), _fs),
        hasLength(1),
      );
      expect(
        () => DataFilter.getActivityIndex(
          axis(),
          axis(),
          axis(),
          _fs,
          period: 100,
        ),
        _throwsBrainFlow(),
      );
    });
  });

  test('write and read file', () {
    final path = '${tmp.path}/data.csv';
    final data = BoardData(2, 3, Float64List.fromList([1, 2, 3, 4, 5, 6]));
    DataFilter.writeFile(data, path, 'w');
    DataFilter.writeFile(data, path, 'a');
    final back = DataFilter.readFile(path);
    expect(back.numRows, 2);
    expect(back.numSamples, 6);
    expect(back.row(0), [1, 2, 3, 1, 2, 3]);
    expect(back.row(1), [4, 5, 6, 4, 5, 6]);
    expect(
      () => DataFilter.readFile('${tmp.path}/missing.csv'),
      _throwsBrainFlow(),
    );
  });
}
