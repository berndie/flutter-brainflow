import 'dart:async';
import 'dart:isolate';

import '../core/board_data.dart';
import '../core/constants.g.dart';
import '../core/input_params.dart';
import 'board_shim.dart';

/// Lifecycle of a [BoardSession].
enum BoardSessionState {
  /// No native session.
  disconnected,

  /// [BoardSession.connect] is running.
  connecting,

  /// Session prepared, not streaming.
  ready,

  /// Streaming; [BoardSession.data] emits samples.
  streaming,
}

/// Asynchronous, UI-friendly wrapper around a [BoardShim].
///
/// Slow native calls (connecting a Bluetooth board can take seconds) run in a
/// short-lived isolate, so the UI isolate never blocks on them. While
/// streaming, the ring buffer is drained every [pollInterval] and the samples
/// are emitted on [data].
///
/// ```dart
/// final session = BoardSession(BoardIds.syntheticBoard);
/// await session.connect();
/// session.data().listen((block) => print(block));
/// await session.startStreaming();
/// // ...
/// await session.dispose();
/// ```
class BoardSession {
  /// Creates a session for [boardId]; nothing happens until [connect].
  BoardSession(
    BoardIds boardId, {
    BrainFlowInputParams inputParams = const BrainFlowInputParams(),
    this.pollInterval = const Duration(milliseconds: 50),
    this.bufferSize = 450000,
  }) : shim = BoardShim(boardId, inputParams);

  /// The underlying synchronous shim, for anything not covered here (board
  /// info, markers, config). Do not call its session lifecycle methods
  /// directly; use the ones on this class so [state] stays correct.
  final BoardShim shim;

  /// How often [data] is fed while streaming.
  final Duration pollInterval;

  /// Size of BrainFlow's ring buffer, in samples.
  final int bufferSize;

  BoardSessionState _state = BoardSessionState.disconnected;
  final _stateController = StreamController<BoardSessionState>.broadcast(
    sync: true,
  );
  final _dataControllers = <BrainFlowPresets, StreamController<BoardData>>{};
  Timer? _timer;
  bool _busy = false;
  bool _disposed = false;

  /// The current state.
  BoardSessionState get state => _state;

  /// Emits every state change.
  Stream<BoardSessionState> get states => _stateController.stream;

  /// Samples of [preset], emitted in blocks while streaming.
  ///
  /// A broadcast stream: only presets with listeners are polled, and samples
  /// that arrive while nobody listens are dropped (use
  /// `shim.getCurrentBoardData` to look back). Errors while polling are
  /// emitted as stream errors.
  Stream<BoardData> data({
    BrainFlowPresets preset = BrainFlowPresets.defaultPreset,
  }) {
    _checkNotDisposed();
    return _dataControllers
        .putIfAbsent(preset, StreamController<BoardData>.broadcast)
        .stream;
  }

  /// Prepares the native session (connects to the board).
  ///
  /// Requires [BoardSessionState.disconnected]. On failure the state returns
  /// to disconnected and the [BrainFlowException] is rethrown.
  Future<void> connect() => _transition(
    from: {BoardSessionState.disconnected},
    run: () async {
      _setState(BoardSessionState.connecting);
      try {
        await Isolate.run(shim.prepareSession);
      } catch (_) {
        _setState(BoardSessionState.disconnected);
        rethrow;
      }
      _setState(BoardSessionState.ready);
    },
  );

  /// Starts streaming and polling. Requires [BoardSessionState.ready].
  Future<void> startStreaming() => _transition(
    from: {BoardSessionState.ready},
    run: () async {
      await Isolate.run(_startStream(shim, bufferSize));
      _timer = Timer.periodic(pollInterval, (_) => _poll());
      _setState(BoardSessionState.streaming);
    },
  );

  /// Stops streaming; samples still in the buffer are emitted first.
  /// Requires [BoardSessionState.streaming].
  Future<void> stopStreaming() =>
      _transition(from: {BoardSessionState.streaming}, run: _stop);

  /// Stops streaming if needed and releases the native session. Does nothing
  /// when already disconnected.
  Future<void> disconnect() => _transition(
    from: {
      BoardSessionState.disconnected,
      BoardSessionState.ready,
      BoardSessionState.streaming,
    },
    run: _disconnect,
  );

  /// [disconnect]s and closes all streams. The session cannot be reused.
  Future<void> dispose() async {
    if (_disposed) return;
    try {
      await disconnect();
    } finally {
      _disposed = true;
      await _stateController.close();
      for (final c in _dataControllers.values) {
        await c.close();
      }
    }
  }

  Future<void> _stop() async {
    _timer?.cancel();
    _timer = null;
    _poll();
    await Isolate.run(shim.stopStream);
    _setState(BoardSessionState.ready);
  }

  Future<void> _disconnect() async {
    if (_state == BoardSessionState.disconnected) return;
    if (_state == BoardSessionState.streaming) await _stop();
    await Isolate.run(shim.releaseSession);
    _setState(BoardSessionState.disconnected);
  }

  void _poll() {
    for (final MapEntry(key: preset, value: controller)
        in _dataControllers.entries) {
      if (!controller.hasListener) continue;
      try {
        final block = shim.getBoardData(preset: preset);
        if (!block.isEmpty) controller.add(block);
      } catch (e, st) {
        controller.addError(e, st);
      }
    }
  }

  Future<void> _transition({
    required Set<BoardSessionState> from,
    required Future<void> Function() run,
  }) async {
    _checkNotDisposed();
    if (_busy) {
      throw StateError('Another BoardSession operation is in progress');
    }
    if (!from.contains(_state)) {
      throw StateError('Not allowed in state ${_state.name}');
    }
    _busy = true;
    try {
      await run();
    } finally {
      _busy = false;
    }
  }

  void _setState(BoardSessionState s) {
    if (s == _state) return;
    _state = s;
    _stateController.add(s);
  }

  void _checkNotDisposed() {
    if (_disposed) throw StateError('BoardSession is disposed');
  }
}

// Built outside the class so the closure only captures sendable values,
// not the session with its timer and stream controllers.
void Function() _startStream(BoardShim shim, int bufferSize) =>
    () => shim.startStream(bufferSize: bufferSize);
