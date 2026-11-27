# SimpleBLE looks these classes up by name via JNI; keep them in minified apps.
-keep class org.simpleble.android.bridge.** { *; }
# JNI entry point of the SimpleBLE preload shim (src/main/cpp).
-keepclasseswithmembernames class org.brainflow.flutter_brainflow.SimpleBlePreload {
    native <methods>;
}
