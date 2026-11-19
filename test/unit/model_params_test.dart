import 'package:flutter_brainflow/flutter_brainflow.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('serializes all fields like the Python binding', () {
    const p = BrainFlowModelParams(
      BrainFlowMetrics.restfulness,
      BrainFlowClassifiers.onnxClassifier,
      file: 'model.onnx',
    );
    expect(p.toJson(), {
      'metric': 1,
      'classifier': 2,
      'file': 'model.onnx',
      'other_info': '',
      'output_name': '',
      'max_array_size': 8192,
    });
    expect(
      p,
      const BrainFlowModelParams(
        BrainFlowMetrics.restfulness,
        BrainFlowClassifiers.onnxClassifier,
        file: 'model.onnx',
      ),
    );
  });
}
