# flutter_brainflow example

Pick a board, connect, and watch the EEG channels live (last 5 s, each
channel centered and auto-scaled).

```sh
flutter run -d linux        # or an Android device (minSdk 31)
flutter test                # drives the app with the synthetic board
```

The synthetic board needs no hardware. For real boards:

| Board | Input |
| --- | --- |
| `muse2Board`, `museSBoard`, `ganglionNativeBoard` | BLE; MAC address optional (first device found otherwise) |
| `cytonBoard` | serial port, e.g. `/dev/ttyUSB0` |

## Manual hardware checks

Not covered by CI; record results in `../AGENTS.md`.

1. **Linux, BLE board** (e.g. Muse 2): needs BlueZ and `libdbus-1.so.3`.
   Connect, Start: traces appear in under ~10 s, Disconnect releases the
   device (it can be connected again without restarting the app).
2. **Android, synthetic board**: confirms the libraries load on a device.
3. **Android, BLE board**: grant the *Nearby devices* permission in the system
   settings first (the example does not request it at runtime). Confirms
   SimpleBLE finds its Java bridge classes; if connect fails with a
   `ClassNotFoundException` in `adb logcat`, see the Android gotcha in
   `../AGENTS.md`.
