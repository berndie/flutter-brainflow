// M0 spike: load libBoardController with DynamicLibrary.open, stream the
// synthetic board for a few seconds and also do the slow calls from another
// isolate to confirm session state is process-global.
//
// Usage: dart run bin/spike.dart <dir-containing-libBoardController.so>
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

typedef _SessionC = Int32 Function(Int32 boardId, Pointer<Utf8> params);
typedef _SessionD = int Function(int boardId, Pointer<Utf8> params);
typedef _StartC =
    Int32 Function(
      Int32 bufferSize,
      Pointer<Utf8> streamer,
      Int32 boardId,
      Pointer<Utf8> p,
    );
typedef _StartD =
    int Function(
      int bufferSize,
      Pointer<Utf8> streamer,
      int boardId,
      Pointer<Utf8> p,
    );
typedef _CountC =
    Int32 Function(
      Int32 preset,
      Pointer<Int32> result,
      Int32 boardId,
      Pointer<Utf8> p,
    );
typedef _CountD =
    int Function(
      int preset,
      Pointer<Int32> result,
      int boardId,
      Pointer<Utf8> p,
    );
typedef _DataC =
    Int32 Function(
      Int32 count,
      Int32 preset,
      Pointer<Double> buf,
      Int32 boardId,
      Pointer<Utf8> p,
    );
typedef _DataD =
    int Function(
      int count,
      int preset,
      Pointer<Double> buf,
      int boardId,
      Pointer<Utf8> p,
    );
typedef _RowsC = Int32 Function(Int32 boardId, Int32 preset, Pointer<Int32> r);
typedef _RowsD = int Function(int boardId, int preset, Pointer<Int32> r);
typedef _VersionC =
    Int32 Function(Pointer<Utf8> buf, Pointer<Int32> len, Int32 max);
typedef _VersionD =
    int Function(Pointer<Utf8> buf, Pointer<Int32> len, int max);
typedef _LogC = Int32 Function(Int32 level);
typedef _LogD = int Function(int level);

const syntheticBoard = -1;
const defaultPreset = 0;
// BrainFlow rejects partial JSON: every field must be present (see
// BrainFlowInputParams in the Python binding). master_board -100 = NO_BOARD.
const params = '{"serial_port":"","mac_address":"","ip_address":"",'
    '"ip_address_aux":"","ip_address_anc":"","ip_port":0,"ip_port_aux":0,'
    '"ip_port_anc":0,"ip_protocol":0,"other_info":"","timeout":0,'
    '"serial_number":"","file":"","file_aux":"","file_anc":"",'
    '"master_board":-100}';

class Bf {
  Bf(String dir) : lib = DynamicLibrary.open('$dir/libBoardController.so');
  final DynamicLibrary lib;

  late final prepare = lib.lookupFunction<_SessionC, _SessionD>(
    'prepare_session',
  );
  late final release = lib.lookupFunction<_SessionC, _SessionD>(
    'release_session',
  );
  late final stop = lib.lookupFunction<_SessionC, _SessionD>('stop_stream');
  late final start = lib.lookupFunction<_StartC, _StartD>('start_stream');
  late final count = lib.lookupFunction<_CountC, _CountD>(
    'get_board_data_count',
  );
  late final data = lib.lookupFunction<_DataC, _DataD>('get_board_data');
  late final rows = lib.lookupFunction<_RowsC, _RowsD>('get_num_rows');
  late final version = lib.lookupFunction<_VersionC, _VersionD>(
    'get_version_board_controller',
  );
  late final logLevel = lib.lookupFunction<_LogC, _LogD>(
    'set_log_level_board_controller',
  );
}

void check(String what, int code) {
  if (code != 0) throw StateError('$what failed with exit code $code');
}

Future<void> main(List<String> args) async {
  final dir = args.single;
  final bf = Bf(dir);

  using((a) {
    final buf = a<Uint8>(64).cast<Utf8>();
    final len = a<Int32>();
    check('version', bf.version(buf, len, 64));
    print('BrainFlow version: ${buf.toDartString(length: len.value)}');
  });
  check('log level', bf.logLevel(2)); // INFO

  // prepare_session from a *different* isolate (simulates Isolate.run for the
  // slow BLE connect), everything else from the main isolate.
  final sw = Stopwatch()..start();
  await _runInIsolate(dir, prepare: true);
  print('prepare_session in helper isolate: ${sw.elapsedMilliseconds} ms');

  final p = params.toNativeUtf8();
  final empty = ''.toNativeUtf8();
  try {
    check('start_stream', bf.start(45000, empty, syntheticBoard, p));
    final numRows = using((a) {
      final r = a<Int32>();
      check('get_num_rows', bf.rows(syntheticBoard, defaultPreset, r));
      return r.value;
    });
    print('num rows: $numRows');

    var total = 0;
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final chunk = using((a) {
        final c = a<Int32>();
        check('count', bf.count(defaultPreset, c, syntheticBoard, p));
        final n = c.value;
        if (n == 0) return Float64List(0);
        final buf = a<Double>(numRows * n);
        check(
          'get_board_data',
          bf.data(n, defaultPreset, buf, syntheticBoard, p),
        );
        return Float64List.fromList(buf.asTypedList(numRows * n));
      });
      final n = chunk.length ~/ numRows;
      total += n;
      // Row-major: row r, sample s at chunk[r * n + s]. Row 0 = package num.
      final firstPkg = n > 0 ? chunk[0] : double.nan;
      final eeg1 = n > 0 ? chunk[1 * n] : double.nan;
      print('poll $i: $n samples (pkg0=$firstPkg, eeg1[0]=$eeg1)');
    }
    print('total samples in ~2 s: $total (synthetic board is 250 Hz)');
    check('stop_stream', bf.stop(syntheticBoard, p));
  } finally {
    // release from another isolate too
    await _runInIsolate(dir, prepare: false);
    malloc.free(p);
    malloc.free(empty);
  }
  print('OK');
}

// Top-level so the Isolate.run closure captures only a String and a bool:
// DynamicLibrary/Pointer objects cannot be sent between isolates.
void _inIsolate(String dir, {required bool prepare}) {
  final bf = Bf(dir);
  final p = params.toNativeUtf8();
  try {
    check(
      prepare ? 'prepare_session (isolate)' : 'release_session (isolate)',
      prepare ? bf.prepare(syntheticBoard, p) : bf.release(syntheticBoard, p),
    );
  } finally {
    malloc.free(p);
  }
}

// The closure must be created here, not in main(): a closure captures its
// whole enclosing context, and main's context holds the DynamicLibrary.
Future<void> _runInIsolate(String dir, {required bool prepare}) =>
    Isolate.run(() => _inIsolate(dir, prepare: prepare));
