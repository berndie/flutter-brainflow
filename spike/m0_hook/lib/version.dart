import 'dart:ffi';

import 'package:ffi/ffi.dart';

@Native<Int32 Function(Pointer<Utf8>, Pointer<Int32>, Int32)>(
  symbol: 'get_version_board_controller',
  assetId: 'package:brainflow_hook_spike/board_controller',
)
external int _getVersion(Pointer<Utf8> buf, Pointer<Int32> len, int max);

@Native<Int32 Function(Int32, Pointer<Utf8>)>(
  symbol: 'prepare_session',
  assetId: 'package:brainflow_hook_spike/board_controller',
)
external int prepareSession(int boardId, Pointer<Utf8> params);

@Native<Int32 Function(Int32, Pointer<Utf8>)>(
  symbol: 'release_session',
  assetId: 'package:brainflow_hook_spike/board_controller',
)
external int releaseSession(int boardId, Pointer<Utf8> params);

String brainflowVersion() => using((a) {
      final buf = a<Uint8>(64).cast<Utf8>();
      final len = a<Int32>();
      final rc = _getVersion(buf, len, 64);
      if (rc != 0) throw StateError('exit code $rc');
      return buf.toDartString(length: len.value);
    });
