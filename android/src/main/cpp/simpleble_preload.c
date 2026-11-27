// Makes SimpleBLE (inside BrainFlow) find its Java bridge classes.
//
// SimpleBLE resolves org.simpleble.android.bridge.* with JNI FindClass once,
// when its Android backend is first used, and caches them. BrainFlow first
// uses it in prepare_session, which flutter_brainflow calls from a Dart
// thread. That thread has no Java frames, so FindClass uses the system class
// loader, which can't see the app's classes, and the app aborts with
// ClassNotFoundException. Called from a JNI method on a Java thread,
// FindClass uses the class loader of the method's class (the app's), so
// triggering that first use from here caches the classes for every thread.
//
// libsimpleble-c.so comes from the build hook's native assets, which CMake
// can't link against, so it is opened at runtime.
#include <android/log.h>
#include <dlfcn.h>
#include <jni.h>

#define TAG "simpleble_preload"

JNIEXPORT jboolean JNICALL
Java_org_brainflow_flutter_1brainflow_SimpleBlePreload_nativePreload(JNIEnv *env,
                                                        jclass clazz) {
  (void)clazz;
  void *lib = dlopen("libsimpleble-c.so", RTLD_NOW);
  if (lib == NULL) {
    __android_log_print(ANDROID_LOG_WARN, TAG, "dlopen failed: %s",
                        dlerror());
    return JNI_FALSE;
  }
  // Any adapter call constructs SimpleBLE's Android backend, which preloads
  // the bridge classes. It needs no Bluetooth permission.
  size_t (*adapter_get_count)(void) =
      (size_t (*)(void))dlsym(lib, "simpleble_adapter_get_count");
  if (adapter_get_count == NULL) {
    __android_log_print(ANDROID_LOG_WARN, TAG, "dlsym failed: %s",
                        dlerror());
    return JNI_FALSE;
  }
  size_t count = adapter_get_count();
  if ((*env)->ExceptionCheck(env)) {
    (*env)->ExceptionDescribe(env);
    (*env)->ExceptionClear(env);
    return JNI_FALSE;
  }
  __android_log_print(ANDROID_LOG_INFO, TAG, "preloaded, %zu adapter(s)",
                      count);
  // The library stays loaded (BrainFlow uses it later), so no dlclose.
  return JNI_TRUE;
}
