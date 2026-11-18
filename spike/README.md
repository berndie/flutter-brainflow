# M0 spike (throwaway)

Proof-of-concept code from milestone M0. Findings are recorded in `../AGENTS.md`.
Delete this directory once M1 is in place.

- `m0/` – `dart run bin/spike.dart <dir-with-libBoardController.so>`: loads
  BrainFlow with `DynamicLibrary.open`, streams the synthetic board, uses
  `Isolate.run` for prepare/release.
- `m0_hook/` – build hook that registers prebuilt libs as code assets from
  local dirs (`hooks.user_defines` in pubspec), `@Native` bindings.
- `app/` – minimal Flutter app depending on `m0_hook`, used to verify Linux
  bundle and Android APK packaging (`flutter build apk`, `flutter build linux`).

The `lib_dir`/`android_dir` paths in the pubspecs point at an extracted
BrainFlow 5.23.0 `compiled_libs.tar` and `brainflow-android.aar` (`jni/`).
