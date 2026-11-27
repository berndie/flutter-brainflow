package org.brainflow.flutter_brainflow;

import android.util.Log;

/**
 * Makes SimpleBLE (BLE inside BrainFlow) work from Flutter: loads it via
 * System.loadLibrary so its JNI callbacks resolve, and lets it find its Java
 * bridge classes before BrainFlow first uses it from a Dart thread, where JNI
 * only sees the system class loader. See src/main/cpp/simpleble_preload.c.
 */
final class SimpleBlePreload {
    private static final String TAG = "SimpleBlePreload";
    private static boolean done;

    private SimpleBlePreload() {}

    /**
     * Idempotent (several engines may attach, e.g. a foreground service);
     * call on a Java thread before any BLE board is prepared.
     */
    static synchronized void run() {
        if (done) return;
        try {
            // Registers SimpleBLE with ART so the bridge classes' native
            // callbacks (Java_org_simpleble_...) resolve; BrainFlow's dlopen
            // alone doesn't. Same soname, so BrainFlow reuses this copy.
            System.loadLibrary("simpleble-c");
            System.loadLibrary("simpleble_preload");
            done = nativePreload();
        } catch (Throwable e) {
            Log.w(TAG, "SimpleBLE preload failed", e);
        }
    }

    private static native boolean nativePreload();
}
