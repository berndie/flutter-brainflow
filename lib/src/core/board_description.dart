import 'dart:convert';

/// A board's data layout for one preset, parsed from BrainFlow's
/// `get_board_descr` JSON.
///
/// Channel lists are row indices into `BoardData`; a board that has no
/// channels of a kind gets an empty list (or `null` for single channels).
class BoardDescription {
  /// Parses the JSON object returned by `get_board_descr`.
  factory BoardDescription.fromJson(Map<String, Object?> json) {
    List<int> ints(String key) => [
      for (final v in (json[key] as List<Object?>?) ?? const []) v! as int,
    ];
    final names = json['eeg_names'] as String?;
    return BoardDescription._(
      raw: Map.unmodifiable(json),
      name: json['name'] as String? ?? '',
      samplingRate: json['sampling_rate'] as int?,
      numRows: json['num_rows'] as int?,
      packageNumChannel: json['package_num_channel'] as int?,
      timestampChannel: json['timestamp_channel'] as int?,
      markerChannel: json['marker_channel'] as int?,
      batteryChannel: json['battery_channel'] as int?,
      eegNames: names == null || names.isEmpty ? const [] : names.split(','),
      eegChannels: ints('eeg_channels'),
      exgChannels: ints('exg_channels'),
      emgChannels: ints('emg_channels'),
      ecgChannels: ints('ecg_channels'),
      eogChannels: ints('eog_channels'),
      edaChannels: ints('eda_channels'),
      ppgChannels: ints('ppg_channels'),
      accelChannels: ints('accel_channels'),
      gyroChannels: ints('gyro_channels'),
      rotationChannels: ints('rotation_channels'),
      magnetometerChannels: ints('magnetometer_channels'),
      analogChannels: ints('analog_channels'),
      temperatureChannels: ints('temperature_channels'),
      resistanceChannels: ints('resistance_channels'),
      opticalChannels: ints('optical_channels'),
      otherChannels: ints('other_channels'),
    );
  }

  /// Parses the JSON string returned by `get_board_descr`.
  factory BoardDescription.parse(String json) =>
      BoardDescription.fromJson(jsonDecode(json) as Map<String, Object?>);

  const BoardDescription._({
    required this.raw,
    required this.name,
    required this.samplingRate,
    required this.numRows,
    required this.packageNumChannel,
    required this.timestampChannel,
    required this.markerChannel,
    required this.batteryChannel,
    required this.eegNames,
    required this.eegChannels,
    required this.exgChannels,
    required this.emgChannels,
    required this.ecgChannels,
    required this.eogChannels,
    required this.edaChannels,
    required this.ppgChannels,
    required this.accelChannels,
    required this.gyroChannels,
    required this.rotationChannels,
    required this.magnetometerChannels,
    required this.analogChannels,
    required this.temperatureChannels,
    required this.resistanceChannels,
    required this.opticalChannels,
    required this.otherChannels,
  });

  /// The full JSON, including keys not modelled here.
  final Map<String, Object?> raw;

  /// Device name, e.g. `Synthetic`.
  final String name;

  /// Sampling rate in Hz.
  final int? samplingRate;

  /// Number of rows in `BoardData`.
  final int? numRows;

  /// Row of the package counter.
  final int? packageNumChannel;

  /// Row of the timestamps (seconds since the Unix epoch).
  final int? timestampChannel;

  /// Row of the markers inserted with `insertMarker`.
  final int? markerChannel;

  /// Row of the battery level.
  final int? batteryChannel;

  /// Electrode names of [eegChannels], e.g. `['TP9', 'AF7', ...]`.
  final List<String> eegNames;

  /// EEG rows.
  final List<int> eegChannels;

  /// ExG rows.
  final List<int> exgChannels;

  /// EMG rows.
  final List<int> emgChannels;

  /// ECG rows.
  final List<int> ecgChannels;

  /// EOG rows.
  final List<int> eogChannels;

  /// EDA rows.
  final List<int> edaChannels;

  /// PPG rows.
  final List<int> ppgChannels;

  /// Accelerometer rows.
  final List<int> accelChannels;

  /// Gyroscope rows.
  final List<int> gyroChannels;

  /// Rotation rows.
  final List<int> rotationChannels;

  /// Magnetometer rows.
  final List<int> magnetometerChannels;

  /// Analog rows.
  final List<int> analogChannels;

  /// Temperature rows.
  final List<int> temperatureChannels;

  /// Resistance rows.
  final List<int> resistanceChannels;

  /// Optical rows.
  final List<int> opticalChannels;

  /// Other rows.
  final List<int> otherChannels;

  @override
  String toString() => 'BoardDescription(${jsonEncode(raw)})';
}
