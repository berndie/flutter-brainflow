import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_brainflow/flutter_brainflow.dart';
import 'package:flutter_test/flutter_test.dart';

const _mindfulness = BrainFlowModelParams(
  BrainFlowMetrics.mindfulness,
  BrainFlowClassifiers.defaultClassifier,
);

void main() {
  setUpAll(MLModel.disableMlLogger);
  tearDown(MLModel.releaseAll);

  test('version and logging', () {
    expect(MLModel.getVersion(), '5.23.0');
    final dir = Directory.systemTemp.createTempSync('brainflow_ml');
    addTearDown(() => dir.deleteSync(recursive: true));
    final log = File('${dir.path}/ml.log');
    MLModel.setLogFile(log.path);
    MLModel.enableDevMlLogger();
    MLModel.logMessage(LogLevels.levelInfo, 'ml says hi');
    MLModel.enableMlLogger();
    MLModel.disableMlLogger();
    expect(log.readAsStringSync(), contains('ml says hi'));
  });

  test('built-in mindfulness and restfulness on synthetic band powers', () {
    // Band powers of real-ish synthetic EEG, as in BrainFlow's examples.
    final bands = Float64List.fromList([0.3, 0.2, 0.25, 0.15, 0.1]);
    for (final metric in [
      BrainFlowMetrics.mindfulness,
      BrainFlowMetrics.restfulness,
    ]) {
      final model = MLModel(
        BrainFlowModelParams(metric, BrainFlowClassifiers.defaultClassifier),
      )..prepare();
      final out = model.predict(bands);
      expect(out, hasLength(1));
      expect(out.first, inInclusiveRange(0, 1));
      model.release();
    }
  });

  test('predict before prepare and double prepare fail', () {
    final model = MLModel(_mindfulness);
    expect(
      () => model.predict(Float64List(5)),
      throwsA(
        isA<BrainFlowException>().having(
          (e) => e.code,
          'code',
          BrainFlowExitCodes.classifierIsNotPreparedError,
        ),
      ),
    );
    model.prepare();
    expect(
      model.prepare,
      throwsA(
        isA<BrainFlowException>().having(
          (e) => e.code,
          'code',
          BrainFlowExitCodes.anotherClassifierIsPreparedError,
        ),
      ),
    );
    model.release();
  });

  test('onnx classifier with a missing model file fails cleanly', () {
    final model = MLModel(
      const BrainFlowModelParams(
        BrainFlowMetrics.userDefined,
        BrainFlowClassifiers.onnxClassifier,
        file: '/nonexistent/model.onnx',
      ),
    );
    expect(model.prepare, throwsA(isA<BrainFlowException>()));
  });

  test('onnx classifier runs a real model (bundled onnxruntime loads)', () {
    final dir = Directory.systemTemp.createTempSync('brainflow_onnx');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/identity.onnx')
      ..writeAsBytesSync(_identityModel(5));
    final model = MLModel(
      BrainFlowModelParams(
        BrainFlowMetrics.userDefined,
        BrainFlowClassifiers.onnxClassifier,
        file: file.path,
      ),
    )..prepare();
    final out = model.predict(Float64List.fromList([1, 2, 3, 4, 5]));
    expect(out, [1, 2, 3, 4, 5]);
    model.release();
  });

  test('releaseAll', () {
    final model = MLModel(_mindfulness)..prepare();
    MLModel.releaseAll();
    expect(
      () => model.predict(Float64List(5)),
      throwsA(isA<BrainFlowException>()),
    );
  });
}

// --- A minimal ONNX model, protobuf-encoded by hand -------------------------
// Identity: float input "x" of shape [1, n] -> output "y". Field numbers are
// from onnx.proto (ModelProto, GraphProto, NodeProto, ValueInfoProto, ...).

List<int> _varint(int v) {
  final out = <int>[];
  while (v >= 0x80) {
    out.add((v & 0x7f) | 0x80);
    v >>= 7;
  }
  return out..add(v);
}

List<int> _int(int field, int v) => [..._varint(field << 3), ..._varint(v)];

List<int> _bytes(int field, List<int> v) => [
  ..._varint(field << 3 | 2),
  ..._varint(v.length),
  ...v,
];

List<int> _str(int field, String v) => _bytes(field, v.codeUnits);

List<int> _valueInfo(String name, int n) => [
  ..._str(1, name),
  ..._bytes(2, [
    // TypeProto.tensor_type
    ..._bytes(1, [
      ..._int(1, 1), // elem_type FLOAT
      ..._bytes(2, [..._bytes(1, _int(1, 1)), ..._bytes(1, _int(1, n))]),
    ]),
  ]),
];

Uint8List _identityModel(int n) => Uint8List.fromList([
  ..._int(1, 7), // ir_version
  ..._str(2, 'flutter_brainflow_test'), // producer_name
  ..._bytes(7, [
    // graph
    ..._bytes(1, [..._str(1, 'x'), ..._str(2, 'y'), ..._str(4, 'Identity')]),
    ..._str(2, 'g'),
    ..._bytes(11, _valueInfo('x', n)),
    ..._bytes(12, _valueInfo('y', n)),
  ]),
  ..._bytes(8, _int(2, 13)), // opset_import { version: 13 }
]);
