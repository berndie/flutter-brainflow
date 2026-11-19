# flutter_brainflow

Dart/Flutter bindings for [BrainFlow](https://brainflow.org): acquire, parse
and analyze EEG, EMG, ECG and other biosensor data from
[many boards](https://brainflow.readthedocs.io/en/stable/SupportedBoards.html).

> Status: early development, not on pub.dev yet. See `AGENTS.md` for the plan.

Uses `dart:ffi` against BrainFlow's C API. The native libraries (BrainFlow
5.23.0) are bundled automatically by a build hook; there is no platform
channel code.

| Platform | Status |
| --- | --- |
| Linux x64 | supported |
| Android (minSdk 31) | builds and packages; not yet verified on a device |
| macOS, Windows | planned |

## Usage

```dart
import 'package:flutter_brainflow/flutter_brainflow.dart';

final board = BoardShim(BoardIds.syntheticBoard);
board.prepareSession();
board.startStream();
// ... later
final data = board.getBoardData(); // removes the samples from the buffer
final eeg = data.rows(BoardShim.getEegChannels(BoardIds.syntheticBoard));
board.releaseSession();
```

Names follow BrainFlow's Python binding in Dart style
(`get_board_data` → `getBoardData`, `SYNTHETIC_BOARD` → `syntheticBoard`), so
the [BrainFlow docs](https://brainflow.readthedocs.io/) apply directly.
Errors throw `BrainFlowException`.

`BoardShim` calls block; `prepareSession` can take seconds for Bluetooth
boards. In a Flutter app use `BoardSession`, which runs slow calls in a
background isolate and streams the data:

```dart
final session = BoardSession(
  BoardIds.muse2Board,
  inputParams: const BrainFlowInputParams(timeout: 15),
);
await session.connect();
final eegRows = BoardShim.getEegChannels(BoardIds.muse2Board);
session.data().listen((block) => plot(block.rows(eegRows)));
await session.startStreaming();
// ...
await session.dispose(); // stops and releases the board
```

In debug builds, call `BoardShim.releaseAllSessions()` at startup: after a
hot restart the native library still holds the previous run's sessions.

Signal processing works on rows (`Float64List`); in-place functions modify
the row inside the `BoardData`:

```dart
final rate = BoardShim.getSamplingRate(BoardIds.syntheticBoard);
for (final row in data.rows(eegRows)) {
  DataFilter.detrend(row, DetrendOperations.constant);
  DataFilter.performBandpass(row, rate, 1, 40, 4, FilterTypes.butterworth, 0);
}
final bands = DataFilter.getAvgBandPowers(data, eegRows, rate, true);
print('alpha: ${bands.avg[2]}');
```

See `example/` for a complete app.

## Native libraries

By default the build hook downloads the BrainFlow release archives once into
`~/.cache/flutter_brainflow` and bundles the libraries your target needs. To
use your own build instead, add to your **app's** `pubspec.yaml`:

```yaml
hooks:
  user_defines:
    flutter_brainflow:
      lib_dir: path/to/brainflow/libs   # Android: <lib_dir>/<abi>/ if present
      # download_cache: path/to/cache   # alternative download location
```

On Linux, Bluetooth boards also need `libdbus-1.so.3` (BLE via BlueZ) and
`libbluetooth.so.3` (classic Bluetooth) on the system.

Vendor SDK helpers (g.tec Unicorn, ANT Neuro eego, ...) are not bundled;
provide them via `lib_dir`.

## License

Not chosen yet (no `LICENSE` file). BrainFlow itself is MIT licensed; see
`third_party/brainflow/include/LICENSE`.
