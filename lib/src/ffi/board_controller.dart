// Dart-typed wrappers over the board controller C API: plain ints, Strings
// and typed data in, exceptions on error. Used by `board/`; keeps pointers
// out of everything outside `ffi/`.
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'board_controller.g.dart' as bc;
import 'native_utils.dart';

// --- Session -----------------------------------------------------------------

/// Calls a session function `f(..., board_id, json_input_params)`.
void _session(
  String function,
  String json,
  int Function(Pointer<Char> json) call,
) => using((arena) {
  checkExitCode(call(cString(arena, json)), function);
});

/// `prepare_session`.
void prepareSession(int boardId, String json) =>
    _session('prepare_session', json, (j) => bc.prepare_session(boardId, j));

/// `start_stream`.
void startStream(int boardId, String json, int bufferSize, String streamer) =>
    using((arena) {
      checkExitCode(
        bc.start_stream(
          bufferSize,
          cString(arena, streamer),
          boardId,
          cString(arena, json),
        ),
        'start_stream',
      );
    });

/// `stop_stream`.
void stopStream(int boardId, String json) =>
    _session('stop_stream', json, (j) => bc.stop_stream(boardId, j));

/// `release_session`.
void releaseSession(int boardId, String json) =>
    _session('release_session', json, (j) => bc.release_session(boardId, j));

/// `release_all_sessions`.
void releaseAllSessions() =>
    checkExitCode(bc.release_all_sessions(), 'release_all_sessions');

/// `is_prepared`.
bool isPrepared(int boardId, String json) => using((arena) {
  final out = arena<Int>();
  checkExitCode(
    bc.is_prepared(out, boardId, cString(arena, json)),
    'is_prepared',
  );
  return out.value != 0;
});

/// `get_board_data_count`.
int getBoardDataCount(int boardId, String json, int preset) => using((arena) {
  final out = arena<Int>();
  checkExitCode(
    bc.get_board_data_count(preset, out, boardId, cString(arena, json)),
    'get_board_data_count',
  );
  return out.value;
});

/// `get_board_data`: removes [count] samples from the ring buffer and
/// returns them row-major (`numRows * count` values).
Float64List getBoardData(
  int boardId,
  String json,
  int preset,
  int count,
  int numRows,
) => using((arena) {
  final buf = arena<Double>(numRows * count);
  checkExitCode(
    bc.get_board_data(count, preset, buf, boardId, cString(arena, json)),
    'get_board_data',
  );
  return copyDoubles(buf, numRows * count);
});

/// `get_current_board_data`: up to [count] latest samples without removing
/// them. Returns the row-major values and the actual sample count.
(Float64List, int) getCurrentBoardData(
  int boardId,
  String json,
  int preset,
  int count,
  int numRows,
) => using((arena) {
  final buf = arena<Double>(numRows * count);
  final returned = arena<Int>();
  checkExitCode(
    bc.get_current_board_data(
      count,
      preset,
      buf,
      returned,
      boardId,
      cString(arena, json),
    ),
    'get_current_board_data',
  );
  return (copyDoubles(buf, numRows * returned.value), returned.value);
});

/// `insert_marker`.
void insertMarker(int boardId, String json, int preset, double value) =>
    _session(
      'insert_marker',
      json,
      (j) => bc.insert_marker(value, preset, boardId, j),
    );

/// `config_board`: returns the board's response.
String configBoard(int boardId, String json, String config) => using((arena) {
  final cConfig = cString(arena, config);
  final cJson = cString(arena, json);
  return readString(
    'config_board',
    (buf, len, max) => bc.config_board(cConfig, buf, len, max, boardId, cJson),
  );
});

/// `config_board_with_bytes`.
void configBoardWithBytes(int boardId, String json, Uint8List bytes) =>
    using((arena) {
      final buf = arena<Uint8>(bytes.isEmpty ? 1 : bytes.length);
      buf.asTypedList(bytes.length).setAll(0, bytes);
      checkExitCode(
        bc.config_board_with_bytes(
          buf.cast(),
          bytes.length,
          boardId,
          cString(arena, json),
        ),
        'config_board_with_bytes',
      );
    });

/// `add_streamer`.
void addStreamer(int boardId, String json, int preset, String streamer) =>
    using((arena) {
      checkExitCode(
        bc.add_streamer(
          cString(arena, streamer),
          preset,
          boardId,
          cString(arena, json),
        ),
        'add_streamer',
      );
    });

/// `delete_streamer`.
void deleteStreamer(int boardId, String json, int preset, String streamer) =>
    using((arena) {
      checkExitCode(
        bc.delete_streamer(
          cString(arena, streamer),
          preset,
          boardId,
          cString(arena, json),
        ),
        'delete_streamer',
      );
    });

// --- Logging and version -----------------------------------------------------

/// `set_log_level_board_controller`.
void setLogLevel(int level) => checkExitCode(
  bc.set_log_level_board_controller(level),
  'set_log_level_board_controller',
);

/// `set_log_file_board_controller`.
void setLogFile(String path) => using((arena) {
  checkExitCode(
    bc.set_log_file_board_controller(cString(arena, path)),
    'set_log_file_board_controller',
  );
});

/// `log_message_board_controller`.
void logMessage(int level, String message) => using((arena) {
  checkExitCode(
    bc.log_message_board_controller(level, cString(arena, message)),
    'log_message_board_controller',
  );
});

/// `get_version_board_controller`.
String getVersion() => readString(
  'get_version_board_controller',
  bc.get_version_board_controller,
  maxLen: 64,
);

// --- Board info (static, no session needed) ----------------------------------

/// `get_board_descr`: JSON string.
String getBoardDescr(int boardId, int preset) => readString(
  'get_board_descr',
  (buf, len, max) => bc.get_board_descr(boardId, preset, buf, len, max),
);

/// `get_device_name`.
String getDeviceName(int boardId, int preset) => readString(
  'get_device_name',
  (buf, len, max) => bc.get_device_name(boardId, preset, buf, len, max),
);

/// `get_eeg_names`: comma-separated.
String getEegNames(int boardId, int preset) => readString(
  'get_eeg_names',
  (buf, len, max) => bc.get_eeg_names(boardId, preset, buf, len, max),
);

/// `get_board_presets`.
List<int> getBoardPresets(int boardId) => readIntArray(
  'get_board_presets',
  (buf, len) => bc.get_board_presets(boardId, buf, len),
);

/// Single-int getters, keyed by C function name.
const singleIntGetters = <String, int Function(int, int, Pointer<Int>)>{
  'get_sampling_rate': bc.get_sampling_rate,
  'get_package_num_channel': bc.get_package_num_channel,
  'get_timestamp_channel': bc.get_timestamp_channel,
  'get_marker_channel': bc.get_marker_channel,
  'get_battery_channel': bc.get_battery_channel,
  'get_num_rows': bc.get_num_rows,
};

/// Channel-list getters, keyed by C function name.
const channelGetters =
    <String, int Function(int, int, Pointer<Int>, Pointer<Int>)>{
      'get_exg_channels': bc.get_exg_channels,
      'get_eeg_channels': bc.get_eeg_channels,
      'get_emg_channels': bc.get_emg_channels,
      'get_ecg_channels': bc.get_ecg_channels,
      'get_eog_channels': bc.get_eog_channels,
      'get_eda_channels': bc.get_eda_channels,
      'get_ppg_channels': bc.get_ppg_channels,
      'get_accel_channels': bc.get_accel_channels,
      'get_rotation_channels': bc.get_rotation_channels,
      'get_analog_channels': bc.get_analog_channels,
      'get_gyro_channels': bc.get_gyro_channels,
      'get_other_channels': bc.get_other_channels,
      'get_temperature_channels': bc.get_temperature_channels,
      'get_resistance_channels': bc.get_resistance_channels,
      'get_magnetometer_channels': bc.get_magnetometer_channels,
      'get_optical_channels': bc.get_optical_channels,
    };

/// Calls the single-int getter [function] (a key of [singleIntGetters]).
int getBoardInt(String function, int boardId, int preset) => readInt(
  function,
  (out) => singleIntGetters[function]!(boardId, preset, out),
);

/// Calls the channel-list getter [function] (a key of [channelGetters]).
List<int> getChannels(String function, int boardId, int preset) => readIntArray(
  function,
  (buf, len) => channelGetters[function]!(boardId, preset, buf, len),
);
