// M0 hook spike: register the prebuilt BrainFlow Linux libs from a local dir
// (user-define `lib_dir`) as bundled code assets. The real hook will download.
import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

// Main libs get a stable asset name that Dart code binds to; helpers are
// bundled only so BoardController can dlopen them from its own directory.
const _linuxLibs = {
  'libBoardController.so': 'board_controller',
  'libDataHandler.so': 'data_handler',
  'libMLModule.so': 'ml_module',
  'libsimpleble-c.so': 'helper/simpleble',
  'libMuseLib.so': 'helper/muse',
  'libGanglionLib.so': 'helper/ganglion',
  'libBrainFlowBluetooth.so': 'helper/bluetooth',
  'libBrainBitLib.so': 'helper/brainbit',
};

const _androidLibs = {
  'libBoardController.so': 'board_controller',
  'libDataHandler.so': 'data_handler',
  'libMLModule.so': 'ml_module',
  'libsimpleble-c.so': 'helper/simpleble',
};
final _abi = {
  Architecture.arm64: 'arm64-v8a',
  Architecture.arm: 'armeabi-v7a',
  Architecture.ia32: 'x86',
  Architecture.x64: 'x86_64',
};

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;
    final code = input.config.code;
    final android = code.targetOS == OS.android;
    var dir = input.userDefines.path(android ? 'android_dir' : 'lib_dir');
    if (dir == null) throw StateError('set hooks.user_defines.$_pkg.lib_dir');
    if (android) dir = dir.resolve('${_abi[code.targetArchitecture]}/');
    final libs = android ? _androidLibs : _linuxLibs;
    for (final MapEntry(key: file, value: name) in libs.entries) {
      final uri = dir.resolve(file);
      if (!File.fromUri(uri).existsSync()) throw StateError('missing $uri');
      output.assets.code.add(CodeAsset(
        package: input.packageName,
        name: name,
        linkMode: DynamicLoadingBundled(),
        file: uri,
      ));
      output.dependencies.add(uri);
    }
  });
}

const _pkg = 'brainflow_hook_spike';
