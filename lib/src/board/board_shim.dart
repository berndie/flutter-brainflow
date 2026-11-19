import 'dart:typed_data';

import '../core/board_data.dart';
import '../core/board_description.dart';
import '../core/constants.g.dart';
import '../core/exit_codes.dart';
import '../core/input_params.dart';
import '../ffi/board_controller.dart' as native;

/// Synchronous access to one board, mirroring BrainFlow's `BoardShim`
/// (<https://brainflow.readthedocs.io/en/stable/UserAPI.html>).
///
/// All calls block the calling isolate; `prepareSession` can take seconds for
/// Bluetooth boards. Session state lives in the native library and is shared
/// by all isolates, so a [BoardShim] (which only holds plain values) can be
/// sent to another isolate and used there.
///
/// Errors are reported as [BrainFlowException].
class BoardShim {
  /// Creates a shim for [boardId] connected with [inputParams].
  ///
  /// For `BoardIds.streamingBoard` and `BoardIds.playbackFileBoard`,
  /// [BrainFlowInputParams.masterBoard] must name the board whose data is
  /// streamed or played back.
  BoardShim(this.boardId, [this.inputParams = const BrainFlowInputParams()])
    : masterBoardId = _masterBoard(boardId, inputParams),
      _json = inputParams.toJsonString();

  static BoardIds _masterBoard(BoardIds id, BrainFlowInputParams params) {
    if (id != BoardIds.streamingBoard && id != BoardIds.playbackFileBoard) {
      return id;
    }
    if (params.masterBoard == BoardIds.noBoard) {
      throw BrainFlowException(
        'BoardShim',
        BrainFlowExitCodes.invalidArgumentsError.value,
      );
    }
    return params.masterBoard;
  }

  /// The board this shim talks to.
  final BoardIds boardId;

  /// The board that defines the data layout: [boardId] itself, or the
  /// master board for streaming/playback boards. Use it with the static info
  /// getters. Same as `get_board_id()` in the Python binding.
  final BoardIds masterBoardId;

  /// Connection parameters.
  final BrainFlowInputParams inputParams;

  final String _json;

  // --- Session ---------------------------------------------------------------

  /// Connects to the board and prepares it for streaming.
  void prepareSession() => native.prepareSession(boardId.value, _json);

  /// Starts streaming into a ring buffer of [bufferSize] samples.
  ///
  /// [streamerParams] optionally streams to a file or multicast group as
  /// well, e.g. `file://data.csv:w`; see [addStreamer].
  void startStream({int bufferSize = 450000, String streamerParams = ''}) =>
      native.startStream(boardId.value, _json, bufferSize, streamerParams);

  /// Stops streaming. Data already in the buffer stays readable.
  void stopStream() => native.stopStream(boardId.value, _json);

  /// Disconnects and frees the session, including its buffer.
  void releaseSession() => native.releaseSession(boardId.value, _json);

  /// Whether [prepareSession] has been called (and not released).
  bool get isPrepared => native.isPrepared(boardId.value, _json);

  /// Number of samples currently in the ring buffer of [preset].
  int getBoardDataCount({
    BrainFlowPresets preset = BrainFlowPresets.defaultPreset,
  }) => native.getBoardDataCount(boardId.value, _json, preset.value);

  /// Removes and returns all samples from the ring buffer, or at most
  /// [numSamples] (oldest first).
  BoardData getBoardData({
    int? numSamples,
    BrainFlowPresets preset = BrainFlowPresets.defaultPreset,
  }) {
    if (numSamples != null && numSamples < 1) {
      throw ArgumentError.value(numSamples, 'numSamples', 'must be >= 1');
    }
    var count = getBoardDataCount(preset: preset);
    if (numSamples != null && numSamples < count) count = numSamples;
    final rows = getNumRows(masterBoardId, preset: preset);
    if (count == 0) return BoardData.empty(rows);
    final data = native.getBoardData(
      boardId.value,
      _json,
      preset.value,
      count,
      rows,
    );
    return BoardData(rows, count, data);
  }

  /// Returns up to [numSamples] of the latest samples without removing them
  /// from the ring buffer.
  BoardData getCurrentBoardData(
    int numSamples, {
    BrainFlowPresets preset = BrainFlowPresets.defaultPreset,
  }) {
    if (numSamples < 1) {
      throw ArgumentError.value(numSamples, 'numSamples', 'must be >= 1');
    }
    final rows = getNumRows(masterBoardId, preset: preset);
    final (data, count) = native.getCurrentBoardData(
      boardId.value,
      _json,
      preset.value,
      numSamples,
      rows,
    );
    return BoardData(rows, count, data);
  }

  /// Writes [value] into the marker channel of the next sample.
  void insertMarker(
    double value, {
    BrainFlowPresets preset = BrainFlowPresets.defaultPreset,
  }) => native.insertMarker(boardId.value, _json, preset.value, value);

  /// Sends a board-specific [config] command and returns the response.
  String configBoard(String config) =>
      native.configBoard(boardId.value, _json, config);

  /// Sends raw [bytes] to the board.
  void configBoardWithBytes(Uint8List bytes) =>
      native.configBoardWithBytes(boardId.value, _json, bytes);

  /// Additionally streams [preset] data to [streamerParams], e.g.
  /// `file://data.csv:w` (`:a` appends) or
  /// `streaming_board://225.1.1.1:6677`.
  void addStreamer(
    String streamerParams, {
    BrainFlowPresets preset = BrainFlowPresets.defaultPreset,
  }) => native.addStreamer(boardId.value, _json, preset.value, streamerParams);

  /// Removes a streamer added with [addStreamer].
  void deleteStreamer(
    String streamerParams, {
    BrainFlowPresets preset = BrainFlowPresets.defaultPreset,
  }) =>
      native.deleteStreamer(boardId.value, _json, preset.value, streamerParams);

  /// Releases every prepared session in this process.
  ///
  /// Useful after a hot restart, when sessions of the previous run are still
  /// open in the native library.
  static void releaseAllSessions() => native.releaseAllSessions();

  // --- Logging and version ---------------------------------------------------

  /// Sets the log level of the board controller.
  static void setLogLevel(LogLevels level) => native.setLogLevel(level.value);

  /// Logs at info level and above.
  static void enableBoardLogger() => setLogLevel(LogLevels.levelInfo);

  /// Logs everything (trace level).
  static void enableDevBoardLogger() => setLogLevel(LogLevels.levelTrace);

  /// Disables logging.
  static void disableBoardLogger() => setLogLevel(LogLevels.levelOff);

  /// Redirects the board controller log to the file at [path].
  static void setLogFile(String path) => native.setLogFile(path);

  /// Writes [message] to the board controller log.
  static void logMessage(LogLevels level, String message) =>
      native.logMessage(level.value, message);

  /// Version of the native BrainFlow library, e.g. `5.23.0`.
  static String getVersion() => native.getVersion();

  // --- Board info ------------------------------------------------------------

  /// The data layout of [boardId] for [preset].
  static BoardDescription getBoardDescr(
    BoardIds boardId, {
    BrainFlowPresets preset = BrainFlowPresets.defaultPreset,
  }) =>
      BoardDescription.parse(native.getBoardDescr(boardId.value, preset.value));

  /// Presets [boardId] supports.
  static List<BrainFlowPresets> getBoardPresets(BoardIds boardId) => [
    for (final p in native.getBoardPresets(boardId.value))
      BrainFlowPresets.fromValue(p),
  ];

  /// Device name, e.g. `Synthetic`.
  static String getDeviceName(
    BoardIds boardId, {
    BrainFlowPresets preset = BrainFlowPresets.defaultPreset,
  }) => native.getDeviceName(boardId.value, preset.value);

  /// Electrode names of the EEG channels, e.g. `['TP9', 'AF7', ...]`.
  static List<String> getEegNames(
    BoardIds boardId, {
    BrainFlowPresets preset = BrainFlowPresets.defaultPreset,
  }) => native.getEegNames(boardId.value, preset.value).split(',');

  static int _int(String fn, BoardIds id, BrainFlowPresets preset) =>
      native.getBoardInt(fn, id.value, preset.value);

  static List<int> _channels(String fn, BoardIds id, BrainFlowPresets p) =>
      native.getChannels(fn, id.value, p.value);

  /// Sampling rate in Hz.
  static int getSamplingRate(
    BoardIds boardId, {
    BrainFlowPresets preset = BrainFlowPresets.defaultPreset,
  }) => _int('get_sampling_rate', boardId, preset);

  /// Number of rows in [BoardData].
  static int getNumRows(
    BoardIds boardId, {
    BrainFlowPresets preset = BrainFlowPresets.defaultPreset,
  }) => _int('get_num_rows', boardId, preset);

  /// Row of the package counter.
  static int getPackageNumChannel(
    BoardIds boardId, {
    BrainFlowPresets preset = BrainFlowPresets.defaultPreset,
  }) => _int('get_package_num_channel', boardId, preset);

  /// Row of the timestamps (seconds since the Unix epoch).
  static int getTimestampChannel(
    BoardIds boardId, {
    BrainFlowPresets preset = BrainFlowPresets.defaultPreset,
  }) => _int('get_timestamp_channel', boardId, preset);

  /// Row of the markers.
  static int getMarkerChannel(
    BoardIds boardId, {
    BrainFlowPresets preset = BrainFlowPresets.defaultPreset,
  }) => _int('get_marker_channel', boardId, preset);

  /// Row of the battery level.
  static int getBatteryChannel(
    BoardIds boardId, {
    BrainFlowPresets preset = BrainFlowPresets.defaultPreset,
  }) => _int('get_battery_channel', boardId, preset);

  /// ExG rows.
  static List<int> getExgChannels(
    BoardIds boardId, {
    BrainFlowPresets preset = BrainFlowPresets.defaultPreset,
  }) => _channels('get_exg_channels', boardId, preset);

  /// EEG rows.
  static List<int> getEegChannels(
    BoardIds boardId, {
    BrainFlowPresets preset = BrainFlowPresets.defaultPreset,
  }) => _channels('get_eeg_channels', boardId, preset);

  /// EMG rows.
  static List<int> getEmgChannels(
    BoardIds boardId, {
    BrainFlowPresets preset = BrainFlowPresets.defaultPreset,
  }) => _channels('get_emg_channels', boardId, preset);

  /// ECG rows.
  static List<int> getEcgChannels(
    BoardIds boardId, {
    BrainFlowPresets preset = BrainFlowPresets.defaultPreset,
  }) => _channels('get_ecg_channels', boardId, preset);

  /// EOG rows.
  static List<int> getEogChannels(
    BoardIds boardId, {
    BrainFlowPresets preset = BrainFlowPresets.defaultPreset,
  }) => _channels('get_eog_channels', boardId, preset);

  /// EDA rows.
  static List<int> getEdaChannels(
    BoardIds boardId, {
    BrainFlowPresets preset = BrainFlowPresets.defaultPreset,
  }) => _channels('get_eda_channels', boardId, preset);

  /// PPG rows.
  static List<int> getPpgChannels(
    BoardIds boardId, {
    BrainFlowPresets preset = BrainFlowPresets.defaultPreset,
  }) => _channels('get_ppg_channels', boardId, preset);

  /// Accelerometer rows.
  static List<int> getAccelChannels(
    BoardIds boardId, {
    BrainFlowPresets preset = BrainFlowPresets.defaultPreset,
  }) => _channels('get_accel_channels', boardId, preset);

  /// Rotation rows.
  static List<int> getRotationChannels(
    BoardIds boardId, {
    BrainFlowPresets preset = BrainFlowPresets.defaultPreset,
  }) => _channels('get_rotation_channels', boardId, preset);

  /// Analog rows.
  static List<int> getAnalogChannels(
    BoardIds boardId, {
    BrainFlowPresets preset = BrainFlowPresets.defaultPreset,
  }) => _channels('get_analog_channels', boardId, preset);

  /// Gyroscope rows.
  static List<int> getGyroChannels(
    BoardIds boardId, {
    BrainFlowPresets preset = BrainFlowPresets.defaultPreset,
  }) => _channels('get_gyro_channels', boardId, preset);

  /// Other rows.
  static List<int> getOtherChannels(
    BoardIds boardId, {
    BrainFlowPresets preset = BrainFlowPresets.defaultPreset,
  }) => _channels('get_other_channels', boardId, preset);

  /// Temperature rows.
  static List<int> getTemperatureChannels(
    BoardIds boardId, {
    BrainFlowPresets preset = BrainFlowPresets.defaultPreset,
  }) => _channels('get_temperature_channels', boardId, preset);

  /// Resistance rows.
  static List<int> getResistanceChannels(
    BoardIds boardId, {
    BrainFlowPresets preset = BrainFlowPresets.defaultPreset,
  }) => _channels('get_resistance_channels', boardId, preset);

  /// Magnetometer rows.
  static List<int> getMagnetometerChannels(
    BoardIds boardId, {
    BrainFlowPresets preset = BrainFlowPresets.defaultPreset,
  }) => _channels('get_magnetometer_channels', boardId, preset);

  /// Optical rows.
  static List<int> getOpticalChannels(
    BoardIds boardId, {
    BrainFlowPresets preset = BrainFlowPresets.defaultPreset,
  }) => _channels('get_optical_channels', boardId, preset);
}
