// What the build hook downloads and bundles. Single source of truth for the
// BrainFlow version; `tool/update_brainflow.sh` rewrites the constants below.
//
// Must match the headers in third_party/brainflow/include/.

import 'package:code_assets/code_assets.dart';

const brainflowVersion = '5.23.0';

/// A downloadable release archive.
class ReleaseArchive {
  const ReleaseArchive(this.fileName, this.sha256, {required this.isZip});

  final String fileName;
  final String sha256;
  final bool isZip;

  Uri get url => Uri.parse(
    'https://github.com/brainflow-dev/brainflow/releases/download/'
    '$brainflowVersion/$fileName',
  );
}

const compiledLibs = ReleaseArchive(
  'compiled_libs.tar',
  '4fab554557a2673abf4da68710cf88255180034e66c88694b523184130022de2',
  isZip: false,
);

const androidAar = ReleaseArchive(
  'brainflow-android.aar',
  '23891a006b0dae3ee1ed4ce96f888e9098ad894d7b3cf3e4128b2acce1f1c9da',
  isZip: true,
);

/// Asset names that Dart code binds to with `@Native(assetId: ...)`.
/// Everything else is a helper that BrainFlow dlopens from its own directory;
/// those get a `helper/` asset name only so they are bundled next to it.
const boardControllerAsset = 'board_controller';
const dataHandlerAsset = 'data_handler';
const mlModuleAsset = 'ml_module';

/// Libraries to bundle for one target: archive + (path in archive -> asset
/// name). The bundled file name is the basename of the path in the archive,
/// which matters because BrainFlow dlopens helpers by file name.
class TargetLibs {
  const TargetLibs(this.archive, this.files);

  final ReleaseArchive archive;
  final Map<String, String> files;
}

/// Supported targets. Linux: core libs + BLE helpers + ONNX runtime (MIT).
/// Vendor SDK helpers (g.tec Unicorn, ANT Neuro eego, Synchroni, ...) are not
/// bundled; provide them yourself via the `lib_dir` user-define.
TargetLibs? targetLibs(OS os, Architecture arch) => switch ((os, arch)) {
  (OS.linux, Architecture.x64) => const TargetLibs(compiledLibs, {
    'libBoardController.so': boardControllerAsset,
    'libDataHandler.so': dataHandlerAsset,
    'libMLModule.so': mlModuleAsset,
    'libsimpleble-c.so': 'helper/simpleble',
    'libMuseLib.so': 'helper/muse',
    'libGanglionLib.so': 'helper/ganglion',
    'libBrainBitLib.so': 'helper/brainbit',
    'libBrainFlowBluetooth.so': 'helper/bluetooth',
    'libonnxruntime_x64.so': 'helper/onnxruntime',
  }),
  (OS.android, _) when androidAbis.containsKey(arch) => TargetLibs(androidAar, {
    for (final MapEntry(key: lib, value: asset) in const {
      'libBoardController.so': boardControllerAsset,
      'libDataHandler.so': dataHandlerAsset,
      'libMLModule.so': mlModuleAsset,
      'libsimpleble-c.so': 'helper/simpleble',
    }.entries)
      'jni/${androidAbis[arch]}/$lib': asset,
  }),
  _ => null,
};

final androidAbis = {
  Architecture.arm64: 'arm64-v8a',
  Architecture.arm: 'armeabi-v7a',
  Architecture.x64: 'x86_64',
  Architecture.ia32: 'x86',
};
