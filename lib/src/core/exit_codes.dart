import 'constants.g.dart';

/// Thrown when a BrainFlow native call returns a non-zero exit code.
///
/// Mirrors `BrainFlowError` of the Python binding.
class BrainFlowException implements Exception {
  /// Creates an exception for the native function [function] that returned
  /// [exitCode].
  const BrainFlowException(this.function, this.exitCode);

  /// Name of the C function that failed, e.g. `prepare_session`.
  final String function;

  /// The raw integer exit code returned by BrainFlow.
  final int exitCode;

  /// [exitCode] as an enum, or `null` if this BrainFlow version returned a
  /// code unknown to these bindings.
  BrainFlowExitCodes? get code {
    for (final c in BrainFlowExitCodes.values) {
      if (c.value == exitCode) return c;
    }
    return null;
  }

  @override
  String toString() =>
      'BrainFlowException: $function failed with '
      '${code?.name ?? 'unknown error'} ($exitCode)';
}
