import 'dart:typed_data';

import 'package:flutter_brainflow/flutter_brainflow.dart';
import 'package:flutter_test/flutter_test.dart';

BoardData _matrix(int rows, int samples, [double offset = 0]) => BoardData(
  rows,
  samples,
  Float64List.fromList([
    for (var r = 0; r < rows; r++)
      for (var s = 0; s < samples; s++) r * 100 + s + offset,
  ]),
);

void main() {
  test('row and at index row-major data', () {
    final d = _matrix(3, 4);
    expect(d.row(1), [100, 101, 102, 103]);
    expect(d.at(2, 3), 203);
    expect(d.rows([0, 2]).map((r) => r.first), [0, 200]);
    expect(d.isEmpty, isFalse);
  });

  test('row is a view, not a copy', () {
    final d = _matrix(2, 2);
    d.row(1)[0] = -1;
    expect(d.at(1, 0), -1);
  });

  test('out of range indices throw', () {
    final d = _matrix(2, 2);
    expect(() => d.row(2), throwsRangeError);
    expect(() => d.at(0, 2), throwsRangeError);
  });

  test('empty', () {
    final d = BoardData.empty(5);
    expect(d.isEmpty, isTrue);
    expect(d.numRows, 5);
    expect(d.row(4), isEmpty);
  });

  test('concat appends along the sample axis', () {
    final d = BoardData.concat(2, [
      _matrix(2, 2),
      BoardData.empty(2),
      _matrix(2, 1, 10),
    ]);
    expect(d.numSamples, 3);
    expect(d.row(0), [0, 1, 10]);
    expect(d.row(1), [100, 101, 110]);
    expect(() => BoardData.concat(3, [_matrix(2, 1)]), throwsArgumentError);
  });
}
