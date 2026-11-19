// Verifies that the build hook bundles BrainFlow and that @Native bindings
// resolve. Uses the raw generated bindings on purpose.
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:flutter_brainflow/src/ffi/board_controller.g.dart' as bc;
import 'package:flutter_brainflow/src/ffi/data_handler.g.dart' as dh;
import 'package:flutter_brainflow/src/ffi/ml_module.g.dart' as ml;
import 'package:flutter_test/flutter_test.dart';

String _version(int Function(Pointer<Char>, Pointer<Int>, int) get) =>
    using((arena) {
      final buf = arena<Char>(64);
      final len = arena<Int>();
      expect(get(buf, len, 64), 0);
      return buf.cast<Utf8>().toDartString(length: len.value);
    });

void main() {
  test('all three BrainFlow libraries load and report the pinned version', () {
    expect(_version(bc.get_version_board_controller), '5.23.0');
    expect(_version(dh.get_version_data_handler), '5.23.0');
    expect(_version(ml.get_version_ml_module), '5.23.0');
  });
}
