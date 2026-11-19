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
- `BoardData`, `BoardDescription`, `BrainFlowInputParams`,
  `BrainFlowException`.
