import 'package:flutter_brainflow/flutter_brainflow.dart';
import 'package:flutter_test/flutter_test.dart';

const _synthetic = BoardIds.syntheticBoard;

void main() {
  setUpAll(BoardShim.disableBoardLogger);
  tearDown(BoardShim.releaseAllSessions);

  test('lifecycle, states and data stream', () async {
    final session = BoardSession(
      _synthetic,
      pollInterval: const Duration(milliseconds: 20),
    );
    final states = <BoardSessionState>[];
    session.states.listen(states.add);

    await session.connect();
    expect(session.state, BoardSessionState.ready);
    expect(session.shim.isPrepared, isTrue);

    final blocks = <BoardData>[];
    final sub = session.data().listen(blocks.add);
    await session.startStreaming();
    while (blocks.fold(0, (n, b) => n + b.numSamples) < 50) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(blocks.every((b) => !b.isEmpty), isTrue);
    expect(blocks.first.numRows, BoardShim.getNumRows(_synthetic));

    // Samples are consecutive across blocks (package counter increments).
    final all = BoardData.concat(blocks.first.numRows, blocks);
    final pkg = all.row(BoardShim.getPackageNumChannel(_synthetic));
    for (var i = 1; i < pkg.length; i++) {
      expect((pkg[i] - pkg[i - 1]) % 256, 1, reason: 'sample $i');
    }

    await session.stopStreaming();
    expect(session.state, BoardSessionState.ready);
    await session.disconnect();
    expect(session.shim.isPrepared, isFalse);
    await sub.cancel();
    await session.dispose();

    expect(states, [
      BoardSessionState.connecting,
      BoardSessionState.ready,
      BoardSessionState.streaming,
      BoardSessionState.ready,
      BoardSessionState.disconnected,
    ]);
  });

  test('auxiliary preset has its own stream', () async {
    final session = BoardSession(_synthetic);
    await session.connect();
    final aux = session
        .data(preset: BrainFlowPresets.auxiliaryPreset)
        .first
        .timeout(const Duration(seconds: 5));
    await session.startStreaming();
    expect(
      (await aux).numRows,
      BoardShim.getNumRows(
        _synthetic,
        preset: BrainFlowPresets.auxiliaryPreset,
      ),
    );
    await session.dispose();
  });

  test('dispose while streaming releases the session', () async {
    final session = BoardSession(_synthetic);
    await session.connect();
    await session.startStreaming();
    await session.dispose();
    expect(session.shim.isPrepared, isFalse);
    expect(session.connect, throwsStateError);
    await session.dispose(); // idempotent
  });

  test('invalid transitions throw StateError', () async {
    final session = BoardSession(_synthetic);
    expect(session.startStreaming, throwsStateError);
    expect(session.stopStreaming, throwsStateError);
    await session.disconnect(); // no-op when disconnected
    final connecting = session.connect();
    expect(session.connect, throwsStateError, reason: 'busy');
    await connecting;
    expect(session.connect, throwsStateError);
    await session.dispose();
  });

  test('connect failure rethrows and returns to disconnected', () async {
    final session = BoardSession(
      BoardIds.playbackFileBoard,
      inputParams: const BrainFlowInputParams(
        file: '/nonexistent/recording.csv',
        masterBoard: _synthetic,
      ),
    );
    await expectLater(session.connect(), throwsA(isA<BrainFlowException>()));
    expect(session.state, BoardSessionState.disconnected);
    await session.dispose();
  });
}
