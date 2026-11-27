package org.brainflow.flutter_brainflow;

import androidx.annotation.NonNull;
import io.flutter.embedding.engine.plugins.FlutterPlugin;

/**
 * Android part of flutter_brainflow. Everything else goes through FFI; this
 * class only exists so {@link SimpleBlePreload} runs on a Java thread when an
 * engine starts, before Dart can prepare a BLE board.
 */
public final class FlutterBrainflowPlugin implements FlutterPlugin {
    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        SimpleBlePreload.run();
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {}
}
