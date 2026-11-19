import 'dart:typed_data';

import '../core/constants.g.dart';
import '../core/model_params.dart';
import '../ffi/ml_module.dart' as native;

/// A metric/classifier, mirroring BrainFlow's `MLModel`
/// (<https://brainflow.readthedocs.io/en/stable/UserAPI.html>).
///
/// ```dart
/// final bands = DataFilter.getAvgBandPowers(data, eegRows, rate, true);
/// final model = MLModel(const BrainFlowModelParams(
///   BrainFlowMetrics.mindfulness,
///   BrainFlowClassifiers.defaultClassifier,
/// ))..prepare();
/// final score = model.predict(bands.avg).first; // 0..1
/// model.release();
/// ```
///
/// The native model is identified by its params, so this object only holds
/// plain values (it can be sent to another isolate).
class MLModel {
  /// Creates a model; call [prepare] before [predict].
  MLModel(this.modelParams) : _json = modelParams.toJsonString();

  /// The model's parameters.
  final BrainFlowModelParams modelParams;

  final String _json;

  /// Loads the model.
  void prepare() => native.prepare(_json);

  /// Runs the model on a feature vector, e.g. the averaged band powers for
  /// the built-in mindfulness/restfulness metrics.
  Float64List predict(Float64List data) =>
      native.predict(_json, data, modelParams.maxArraySize);

  /// Frees the model.
  void release() => native.release(_json);

  /// Frees all prepared models.
  static void releaseAll() => native.releaseAll();

  /// Sets the log level of the ML module.
  static void setLogLevel(LogLevels level) => native.setLogLevel(level.value);

  /// Logs at info level and above.
  static void enableMlLogger() => setLogLevel(LogLevels.levelInfo);

  /// Logs everything (trace level).
  static void enableDevMlLogger() => setLogLevel(LogLevels.levelTrace);

  /// Disables logging.
  static void disableMlLogger() => setLogLevel(LogLevels.levelOff);

  /// Redirects the ML module log to the file at [path].
  static void setLogFile(String path) => native.setLogFile(path);

  /// Writes [message] to the ML module log.
  static void logMessage(LogLevels level, String message) =>
      native.logMessage(level.value, message);

  /// Version of the native ML module library, e.g. `5.23.0`.
  static String getVersion() => native.getVersion();
}
