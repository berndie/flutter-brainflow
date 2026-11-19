// Dart-typed wrappers over the ML module C API.
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'ml_module.g.dart' as ml;
import 'native_utils.dart';

/// `prepare`.
void prepare(String json) => using((arena) {
  checkExitCode(ml.prepare(cString(arena, json)), 'prepare');
});

/// `release`.
void release(String json) => using((arena) {
  checkExitCode(ml.release(cString(arena, json)), 'release');
});

/// `release_all`.
void releaseAll() => checkExitCode(ml.release_all(), 'release_all');

/// `predict`: at most [maxOutput] values.
Float64List predict(String json, Float64List data, int maxOutput) =>
    using((arena) {
      final out = arena<Double>(maxOutput < 1 ? 1 : maxOutput);
      final len = arena<Int>();
      checkExitCode(
        ml.predict(
          doubleBuffer(arena, data),
          data.length,
          out,
          len,
          cString(arena, json),
        ),
        'predict',
      );
      return copyDoubles(out, len.value);
    });

/// `set_log_level_ml_module`.
void setLogLevel(int level) =>
    checkExitCode(ml.set_log_level_ml_module(level), 'set_log_level_ml_module');

/// `set_log_file_ml_module`.
void setLogFile(String path) => using((arena) {
  checkExitCode(
    ml.set_log_file_ml_module(cString(arena, path)),
    'set_log_file_ml_module',
  );
});

/// `log_message_ml_module`.
void logMessage(int level, String message) => using((arena) {
  checkExitCode(
    ml.log_message_ml_module(level, cString(arena, message)),
    'log_message_ml_module',
  );
});

/// `get_version_ml_module`.
String getVersion() =>
    readString('get_version_ml_module', ml.get_version_ml_module, maxLen: 64);
