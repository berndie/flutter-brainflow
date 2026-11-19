// Marshalling helpers shared by the Dart-typed wrappers in this directory.
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../core/exit_codes.dart';

/// Throws [BrainFlowException] if [exitCode] is not `STATUS_OK`.
void checkExitCode(int exitCode, String function) {
  if (exitCode != 0) throw BrainFlowException(function, exitCode);
}

/// Allocates [value] as a NUL-terminated UTF-8 C string in [arena].
Pointer<Char> cString(Arena arena, String value) =>
    value.toNativeUtf8(allocator: arena).cast();

/// Calls a C function that fills a `char*` buffer of [maxLen] bytes and
/// reports the written length, and returns the result as a Dart string.
String readString(
  String function,
  int Function(Pointer<Char> buf, Pointer<Int> len, int maxLen) call, {
  int maxLen = 16384,
}) => using((arena) {
  final buf = arena<Char>(maxLen);
  final len = arena<Int>();
  checkExitCode(call(buf, len, maxLen), function);
  return buf.cast<Utf8>().toDartString(length: len.value);
});

/// Calls a C function that fills an `int*` array and reports its length.
List<int> readIntArray(
  String function,
  int Function(Pointer<Int> buf, Pointer<Int> len) call, {
  int maxLen = 512,
}) => using((arena) {
  final buf = arena<Int>(maxLen);
  final len = arena<Int>();
  checkExitCode(call(buf, len), function);
  return List.unmodifiable([for (var i = 0; i < len.value; i++) buf[i]]);
});

/// Calls a C function that writes a single `int` result.
int readInt(String function, int Function(Pointer<Int> out) call) =>
    using((arena) {
      final out = arena<Int>();
      checkExitCode(call(out), function);
      return out.value;
    });

/// Copies [values] into a native `double` buffer allocated in [arena].
Pointer<Double> doubleBuffer(Arena arena, Float64List values) {
  final buf = arena<Double>(values.isEmpty ? 1 : values.length);
  buf.asTypedList(values.length).setAll(0, values);
  return buf;
}

/// Copies [length] doubles out of native memory into Dart memory.
Float64List copyDoubles(Pointer<Double> buf, int length) =>
    Float64List.fromList(buf.asTypedList(length));
