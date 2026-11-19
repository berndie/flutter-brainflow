import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_brainflow/flutter_brainflow.dart';

import 'band_powers.dart';
import 'signal_buffer.dart';
import 'signal_plot.dart';

void main() {
  // After a hot restart the native library still holds the previous run's
  // sessions; release them so connecting again works.
  if (kDebugMode) BoardShim.releaseAllSessions();
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'flutter_brainflow',
    theme: ThemeData(colorSchemeSeed: Colors.indigo),
    darkTheme: ThemeData(
      colorSchemeSeed: Colors.indigo,
      brightness: Brightness.dark,
    ),
    home: const LiveEegPage(),
  );
}

/// Boards offered in the picker. Any [BoardIds] works with the library.
const _boards = [
  BoardIds.syntheticBoard,
  BoardIds.muse2Board,
  BoardIds.museSBoard,
  BoardIds.ganglionNativeBoard,
  BoardIds.cytonBoard,
];

class LiveEegPage extends StatefulWidget {
  const LiveEegPage({super.key});

  @override
  State<LiveEegPage> createState() => _LiveEegPageState();
}

class _LiveEegPageState extends State<LiveEegPage> {
  static const _windowSeconds = 5;

  BoardIds _boardId = BoardIds.syntheticBoard;
  final _serialPort = TextEditingController();
  final _macAddress = TextEditingController();

  BoardSession? _session;
  StreamSubscription<BoardData>? _dataSub;
  StreamSubscription<BoardSessionState>? _stateSub;
  SignalBuffer _buffer = SignalBuffer(0, 2);
  List<int> _eegRows = const [];
  List<String> _eegNames = const [];
  int _samplingRate = 0;
  BandPowers? _bandPowers;
  DateTime _lastBandPowers = DateTime(0);
  String? _error;

  BoardSessionState get _state =>
      _session?.state ?? BoardSessionState.disconnected;

  @override
  void dispose() {
    _teardown();
    _serialPort.dispose();
    _macAddress.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _error = null);
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _connect() => _run(() async {
    final descr = BoardShim.getBoardDescr(_boardId);
    _eegRows = descr.eegChannels;
    _eegNames = descr.eegNames.length == _eegRows.length
        ? descr.eegNames
        : [for (final r in _eegRows) 'ch$r'];
    _samplingRate = descr.samplingRate ?? 250;
    _buffer = SignalBuffer(_eegRows.length, _samplingRate * _windowSeconds);
    _bandPowers = null;

    final session = BoardSession(
      _boardId,
      inputParams: BrainFlowInputParams(
        serialPort: _serialPort.text.trim(),
        macAddress: _macAddress.text.trim(),
      ),
    );
    _session = session;
    _stateSub = session.states.listen((_) {
      if (mounted) setState(() {});
    });
    _dataSub = session.data().listen(
      (block) {
        _buffer.addAll(block.rows(_eegRows));
        _updateBandPowers();
      },
      onError: (Object e) {
        if (mounted) setState(() => _error = '$e');
      },
    );
    try {
      await session.connect();
    } catch (_) {
      await _teardown();
      rethrow;
    }
  });

  /// Recomputes band powers over the plotted window, at most twice a second.
  void _updateBandPowers() {
    final now = DateTime.now();
    if (now.difference(_lastBandPowers) < const Duration(milliseconds: 500) ||
        _buffer.length < 2 * _samplingRate) {
      return;
    }
    _lastBandPowers = now;
    final window = _buffer.toBoardData();
    final powers = DataFilter.getAvgBandPowers(
      window,
      [for (var c = 0; c < window.numRows; c++) c],
      _samplingRate,
      true,
    );
    setState(() => _bandPowers = powers);
  }

  Future<void> _start() => _run(() => _session!.startStreaming());

  Future<void> _stop() => _run(() => _session!.stopStreaming());

  Future<void> _disconnect() => _run(_teardown);

  Future<void> _teardown() async {
    final session = _session;
    _session = null;
    await _dataSub?.cancel();
    await _stateSub?.cancel();
    _dataSub = null;
    _stateSub = null;
    await session?.dispose();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    final disconnected = state == BoardSessionState.disconnected;
    return Scaffold(
      appBar: AppBar(
        title: const Text('flutter_brainflow'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: Text('BrainFlow ${BoardShim.getVersion()}')),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownMenu<BoardIds>(
                  initialSelection: _boardId,
                  enabled: disconnected,
                  label: const Text('Board'),
                  onSelected: (b) => setState(() => _boardId = b ?? _boardId),
                  dropdownMenuEntries: [
                    for (final b in _boards)
                      DropdownMenuEntry(value: b, label: b.name),
                  ],
                ),
                if (_boardId != BoardIds.syntheticBoard) ...[
                  SizedBox(
                    width: 180,
                    child: TextField(
                      controller: _serialPort,
                      enabled: disconnected,
                      decoration: const InputDecoration(
                        labelText: 'Serial port',
                        hintText: '/dev/ttyUSB0',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 200,
                    child: TextField(
                      controller: _macAddress,
                      enabled: disconnected,
                      decoration: const InputDecoration(
                        labelText: 'MAC address (optional)',
                      ),
                    ),
                  ),
                ],
                ..._buttons(state),
                Chip(label: Text(state.name)),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            if (!disconnected)
              Text(
                '${_eegRows.length} EEG channels at $_samplingRate Hz, '
                'last $_windowSeconds s',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            Expanded(
              child: disconnected
                  ? const Center(child: Text('Pick a board and connect.'))
                  : SignalPlot(buffer: _buffer, labels: _eegNames),
            ),
            if (!disconnected) ...[
              const SizedBox(height: 16),
              BandPowerBars(powers: _bandPowers),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buttons(BoardSessionState state) => switch (state) {
    BoardSessionState.disconnected => [
      FilledButton(onPressed: _connect, child: const Text('Connect')),
    ],
    BoardSessionState.connecting => [
      const SizedBox.square(
        dimension: 24,
        child: CircularProgressIndicator(strokeWidth: 3),
      ),
    ],
    BoardSessionState.ready => [
      FilledButton(onPressed: _start, child: const Text('Start')),
      OutlinedButton(onPressed: _disconnect, child: const Text('Disconnect')),
    ],
    BoardSessionState.streaming => [
      FilledButton(onPressed: _stop, child: const Text('Stop')),
      OutlinedButton(onPressed: _disconnect, child: const Text('Disconnect')),
    ],
  };
}
