# Changelog

Versions track BrainFlow: `<ourVersion>+bf<brainflowVersion>` (from M6 on).

## Unreleased

- Native delivery via build hook: pinned BrainFlow 5.23.0 libraries are
  downloaded (SHA-256 verified) or taken from the `lib_dir` user-define.
  Linux x64 and Android (arm64, armv7, x86_64, x86).
- All BrainFlow enums (`BoardIds`, `BrainFlowPresets`, `LogLevels`, ...),
  generated from the vendored headers.
- `BoardShim`: synchronous 1:1 wrapper of BrainFlow's board controller
  (session lifecycle, data access, markers, config, streamers, board info,
  logging).
- `BoardSession`: async layer (connect/stream in background isolates,
  `Stream<BoardData>` per preset, `states` stream, `dispose`).
- `DataFilter`: filters, denoising, wavelets, FFT/PSD/Welch, band powers,
  CSP, ICA, PPG heart rate and SpO2, activity index, file read/write,
  logging.
- `MLModel` + `BrainFlowModelParams`: built-in mindfulness/restfulness,
  ONNX and dynamic-library classifiers.
- Example app: board picker, live EEG plot and band powers (Linux, Android).
- `BoardData`, `BoardDescription`, `BrainFlowInputParams`,
  `BrainFlowException`.
- MIT license for the package's own code; `THIRD_PARTY_NOTICES.md` covers
  BrainFlow, SimpleBLE and ONNX Runtime.
- Android: SimpleBLE's bridge classes are no longer vendored. Gradle extracts
  them at build time from the pinned BrainFlow AAR (Gradle property
  `flutter_brainflow.aar` for a local copy).
- Android: BLE boards (e.g. Muse 2) work from Flutter. A small plugin class
  preloads SimpleBLE on a Java thread so it finds its bridge classes, and
  loads `libsimpleble-c.so` so its JNI callbacks resolve. No app code needed.
