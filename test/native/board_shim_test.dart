// Exercises every BoardShim member against the real library, using the
// synthetic board (no hardware) and the playback file board.
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_brainflow/flutter_brainflow.dart';
import 'package:flutter_test/flutter_test.dart';

const _synthetic = BoardIds.syntheticBoard;

Matcher _throwsBrainFlow(BrainFlowExitCodes code) =>
    throwsA(isA<BrainFlowException>().having((e) => e.code, 'code', code));

Future<void> _waitForSamples(BoardShim board, int count) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (board.getBoardDataCount() < count) {
    if (DateTime.now().isAfter(deadline)) fail('timed out waiting for data');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  late Directory tmp;

  setUpAll(() {
    BoardShim.disableBoardLogger();
    tmp = Directory.systemTemp.createTempSync('brainflow_test');
  });
  tearDownAll(() => tmp.deleteSync(recursive: true));
  tearDown(BoardShim.releaseAllSessions);

  group('info getters', () {
    test('version', () => expect(BoardShim.getVersion(), '5.23.0'));

    test('description matches the single getters', () {
      final d = BoardShim.getBoardDescr(_synthetic);
      expect(d.name, 'Synthetic');
      expect(BoardShim.getDeviceName(_synthetic), d.name);
      expect(BoardShim.getSamplingRate(_synthetic), d.samplingRate);
      expect(BoardShim.getNumRows(_synthetic), d.numRows);
      expect(BoardShim.getPackageNumChannel(_synthetic), d.packageNumChannel);
      expect(BoardShim.getTimestampChannel(_synthetic), d.timestampChannel);
      expect(BoardShim.getMarkerChannel(_synthetic), d.markerChannel);
      expect(BoardShim.getBatteryChannel(_synthetic), d.batteryChannel);
      expect(BoardShim.getEegNames(_synthetic), d.eegNames);
      expect(d.eegNames, hasLength(16));
    });

    test('presets', () {
      expect(
        BoardShim.getBoardPresets(_synthetic),
        unorderedEquals([
          BrainFlowPresets.defaultPreset,
          BrainFlowPresets.auxiliaryPreset,
        ]),
      );
      final aux = BoardShim.getBoardDescr(
        _synthetic,
        preset: BrainFlowPresets.auxiliaryPreset,
      );
      expect(aux.name, 'SyntheticAux');
      expect(
        BoardShim.getOtherChannels(
          _synthetic,
          preset: BrainFlowPresets.auxiliaryPreset,
        ),
        aux.otherChannels,
      );
    });

    // Each channel getter agrees with the description; kinds the board does
    // not have throw UNSUPPORTED_BOARD_ERROR.
    final getters = <String, List<int> Function(BoardIds)>{
      'eeg_channels': BoardShim.getEegChannels,
      'emg_channels': BoardShim.getEmgChannels,
      'ecg_channels': BoardShim.getEcgChannels,
      'eog_channels': BoardShim.getEogChannels,
      'eda_channels': BoardShim.getEdaChannels,
      'ppg_channels': BoardShim.getPpgChannels,
      'accel_channels': BoardShim.getAccelChannels,
      'rotation_channels': BoardShim.getRotationChannels,
      'analog_channels': BoardShim.getAnalogChannels,
      'gyro_channels': BoardShim.getGyroChannels,
      'other_channels': BoardShim.getOtherChannels,
      'temperature_channels': BoardShim.getTemperatureChannels,
      'resistance_channels': BoardShim.getResistanceChannels,
      'magnetometer_channels': BoardShim.getMagnetometerChannels,
      'optical_channels': BoardShim.getOpticalChannels,
    };
    test('exg channels are the union of EEG, EMG, ECG and EOG', () {
      for (final board in [_synthetic, BoardIds.muse2Board]) {
        final d = BoardShim.getBoardDescr(board);
        final union = {
          ...d.eegChannels,
          ...d.emgChannels,
          ...d.ecgChannels,
          ...d.eogChannels,
        }.toList()..sort();
        expect(BoardShim.getExgChannels(board), union);
      }
    });

    for (final board in [_synthetic, BoardIds.muse2Board]) {
      for (final MapEntry(key: key, value: get) in getters.entries) {
        test('${board.name} $key', () {
          final raw = BoardShim.getBoardDescr(board).raw[key];
          if (raw == null) {
            expect(
              () => get(board),
              _throwsBrainFlow(BrainFlowExitCodes.unsupportedBoardError),
            );
          } else {
            expect(get(board), raw);
          }
        });
      }
    }
  });

  group('logging', () {
    test('log file, levels and messages', () {
      final file = File('${tmp.path}/board.log');
      BoardShim.setLogFile(file.path);
      BoardShim.enableDevBoardLogger();
      BoardShim.logMessage(LogLevels.levelInfo, 'hello from dart');
      BoardShim.enableBoardLogger();
      BoardShim.setLogLevel(LogLevels.levelWarn);
      BoardShim.disableBoardLogger();
      expect(file.readAsStringSync(), contains('hello from dart'));
    });
  });

  group('session', () {
    test('streaming board needs a master board', () {
      expect(
        () => BoardShim(BoardIds.streamingBoard),
        _throwsBrainFlow(BrainFlowExitCodes.invalidArgumentsError),
      );
      expect(BoardShim(_synthetic).masterBoardId, _synthetic);
    });

    test('calls before prepareSession fail', () {
      final board = BoardShim(_synthetic);
      expect(board.isPrepared, isFalse);
      expect(
        board.startStream,
        _throwsBrainFlow(BrainFlowExitCodes.boardNotCreatedError),
      );
    });

    test('full lifecycle with synthetic board', () async {
      final board = BoardShim(_synthetic);
      board.prepareSession();
      expect(board.isPrepared, isTrue);
      expect(
        BoardShim(_synthetic).prepareSession,
        _throwsBrainFlow(BrainFlowExitCodes.anotherBoardIsCreatedError),
      );

      board.startStream(bufferSize: 10000);
      await _waitForSamples(board, 20);
      board.insertMarker(42);
      await _waitForSamples(board, 60);

      final rows = BoardShim.getNumRows(_synthetic);
      final current = board.getCurrentBoardData(10);
      expect(current.numRows, rows);
      expect(current.numSamples, 10);
      final count = board.getBoardDataCount();
      expect(count, greaterThanOrEqualTo(60));

      final some = board.getBoardData(numSamples: 5);
      expect(some.numSamples, 5);
      final rest = board.getBoardData();
      expect(rest.numSamples, greaterThanOrEqualTo(count - 5));

      final markers = BoardData.concat(rows, [
        some,
        rest,
      ]).row(BoardShim.getMarkerChannel(_synthetic));
      expect(markers.where((m) => m != 0), [42]);

      final ts = rest.row(BoardShim.getTimestampChannel(_synthetic));
      final now = DateTime.now().millisecondsSinceEpoch / 1000;
      expect(ts.last, closeTo(now, 5));

      board.stopStream();
      board.releaseSession();
      expect(board.isPrepared, isFalse);
    });

    test('reading data needs a started stream; argument checks', () {
      final board = BoardShim(_synthetic)..prepareSession();
      final noBuffer = _throwsBrainFlow(
        BrainFlowExitCodes.invalidArgumentsError,
      );
      expect(board.getBoardData, noBuffer);
      expect(() => board.getCurrentBoardData(5), noBuffer);
      expect(() => board.getBoardData(numSamples: 0), throwsArgumentError);
      expect(() => board.getCurrentBoardData(0), throwsArgumentError);
    });

    test('configBoard and configBoardWithBytes', () {
      final board = BoardShim(_synthetic)..prepareSession();
      // The synthetic board accepts any config and raw bytes.
      expect(board.configBoard('x'), isA<String>());
      board.configBoardWithBytes(Uint8List.fromList([1, 2, 3]));
    });

    test('a session prepared in another isolate is visible here', () async {
      final board = BoardShim(_synthetic);
      await Isolate.run(board.prepareSession);
      expect(board.isPrepared, isTrue);
      await Isolate.run(board.releaseSession);
      expect(board.isPrepared, isFalse);
    });

    test('releaseAllSessions', () {
      final board = BoardShim(_synthetic)..prepareSession();
      BoardShim.releaseAllSessions();
      expect(board.isPrepared, isFalse);
    });

    test(
      'record with a file streamer, then replay with playback board',
      () async {
        final file = '${tmp.path}/recording.csv';
        final board = BoardShim(_synthetic)..prepareSession();
        board.addStreamer('file://$file:w');
        board.startStream();
        await _waitForSamples(board, 100);
        board.stopStream();
        board.deleteStreamer('file://$file:w');
        final recorded = board.getBoardData();
        board.releaseSession();

        final lines = File(file).readAsLinesSync();
        expect(lines.length, recorded.numSamples);

        final playback = BoardShim(
          BoardIds.playbackFileBoard,
          BrainFlowInputParams(file: file, masterBoard: _synthetic),
        );
        expect(playback.masterBoardId, _synthetic);
        playback.prepareSession();
        playback.startStream();
        await _waitForSamples(playback, 20);
        final replayed = playback.getBoardData();
        playback.releaseSession();

        expect(replayed.numRows, recorded.numRows);
        final eeg = BoardShim.getEegChannels(_synthetic).first;
        for (var s = 0; s < 10; s++) {
          expect(replayed.at(eeg, s), closeTo(recorded.at(eeg, s), 1e-3));
        }
      },
    );
  });
}
