# simpleble-bridge.jar

Copied unmodified from `libs/simpleble-bridge.jar` inside
`brainflow-android.aar` of BrainFlow 5.23.0 (SHA-256
`3a26cecf8ccb5497d39537b4787e4b2a6a3c296563aca7480999efee56fccda1`).

It contains `org.simpleble.android.bridge.{ScanCallback,BluetoothGattCallback}`,
which SimpleBLE's native Android backend (`libsimpleble-c.so`) uses through JNI.
SimpleBLE is part of BrainFlow's third-party code; see BrainFlow's license files.

`tool/update_brainflow.sh` refreshes this file when BrainFlow is bumped.
