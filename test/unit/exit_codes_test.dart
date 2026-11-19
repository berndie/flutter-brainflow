import 'package:flutter_brainflow/flutter_brainflow.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps known exit codes', () {
    const e = BrainFlowException('prepare_session', 17);
    expect(e.code, BrainFlowExitCodes.generalError);
    expect(e.toString(), contains('prepare_session'));
    expect(e.toString(), contains('generalError (17)'));
  });

  test('tolerates unknown exit codes', () {
    const e = BrainFlowException('foo', 999);
    expect(e.code, isNull);
    expect(e.toString(), contains('999'));
  });

  test('generated enums round-trip their integer values', () {
    expect(BoardIds.fromValue(-1), BoardIds.syntheticBoard);
    expect(BoardIds.muse2Board.value, 38);
    expect(() => BoardIds.fromValue(123456), throwsArgumentError);
  });
}
