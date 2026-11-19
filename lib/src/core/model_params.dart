import 'dart:convert';

import 'constants.g.dart';

/// Parameters of an `MLModel`, mirroring BrainFlow's `BrainFlowModelParams`.
///
/// Two models with equal params refer to the same native model.
class BrainFlowModelParams {
  /// Creates params for [metric] computed by [classifier].
  const BrainFlowModelParams(
    this.metric,
    this.classifier, {
    this.file = '',
    this.otherInfo = '',
    this.outputName = '',
    this.maxArraySize = 8192,
  });

  /// What to compute, e.g. mindfulness.
  final BrainFlowMetrics metric;

  /// How to compute it: built-in, a dynamic library or an ONNX model.
  final BrainFlowClassifiers classifier;

  /// Model file for `dynLibClassifier` / `onnxClassifier`.
  final String file;

  /// Classifier-specific extra information.
  final String otherInfo;

  /// Name of the ONNX output to read (default: the first one).
  final String outputName;

  /// Maximum number of values `predict` can return.
  final int maxArraySize;

  /// The JSON object BrainFlow's C API expects.
  Map<String, Object> toJson() => {
    'metric': metric.value,
    'classifier': classifier.value,
    'file': file,
    'other_info': otherInfo,
    'output_name': outputName,
    'max_array_size': maxArraySize,
  };

  /// [toJson] encoded as a string.
  String toJsonString() => jsonEncode(toJson());

  @override
  bool operator ==(Object other) =>
      other is BrainFlowModelParams && other.toJsonString() == toJsonString();

  @override
  int get hashCode => toJsonString().hashCode;

  @override
  String toString() => 'BrainFlowModelParams(${toJsonString()})';
}
