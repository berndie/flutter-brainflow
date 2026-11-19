// Build hook: bundles the BrainFlow shared libraries as native code assets.
//
// By default the pinned BrainFlow release archives are downloaded (verified by
// SHA-256) into a download cache that survives `flutter clean`:
//   - `hooks.user_defines.flutter_brainflow.download_cache`, if set, else
//   - `$HOME/.cache/flutter_brainflow` (`%LOCALAPPDATA%` on Windows), else
//   - the hook's shared output directory.
//
// Alternatively, `hooks.user_defines.flutter_brainflow.lib_dir` points at a
// directory with prebuilt libraries (e.g. your own BrainFlow build). Every
// shared library in it is bundled; for Android, `<lib_dir>/<abi>/` is used if
// it exists. User-defines are read from the app's (workspace root) pubspec:
//
//   hooks:
//     user_defines:
//       flutter_brainflow:
//         lib_dir: path/to/brainflow/libs
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:code_assets/code_assets.dart';
import 'package:crypto/crypto.dart';
import 'package:hooks/hooks.dart';

import 'brainflow_release.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;
    final code = input.config.code;
    final os = code.targetOS;
    final arch = code.targetArchitecture;

    final Map<String, Uri> libs; // asset name -> file
    final libDir = input.userDefines.path('lib_dir');
    if (libDir != null) {
      libs = _libsFromDir(libDir, os, arch);
    } else {
      final target = targetLibs(os, arch);
      if (target == null) {
        throw UnsupportedError(
          'flutter_brainflow has no prebuilt BrainFlow libraries for '
          '$os/$arch. Supported: linux/x64 and android. Set '
          'hooks.user_defines.flutter_brainflow.lib_dir to use your own.',
        );
      }
      final archive = await _download(target.archive, _cacheDir(input));
      libs = _extract(
        archive,
        target,
        input.outputDirectoryShared.resolve('brainflow-$brainflowVersion/'),
        '${os.name}-${arch.name}',
      );
    }

    for (final MapEntry(key: name, value: file) in libs.entries) {
      output.assets.code.add(
        CodeAsset(
          package: input.packageName,
          name: name,
          linkMode: DynamicLoadingBundled(),
          file: file,
        ),
      );
      output.dependencies.add(file);
    }
  });
}

// --- lib_dir override -------------------------------------------------------

const _mainAssets = {
  'BoardController': boardControllerAsset,
  'DataHandler': dataHandlerAsset,
  'MLModule': mlModuleAsset,
};

Map<String, Uri> _libsFromDir(Uri libDir, OS os, Architecture arch) {
  var dir = Directory.fromUri(libDir);
  final abi = androidAbis[arch];
  if (os == OS.android && abi != null) {
    final abiDir = Directory.fromUri(libDir.resolve('$abi/'));
    if (abiDir.existsSync()) dir = abiDir;
  }
  if (!dir.existsSync()) throw StateError('lib_dir ${dir.path} does not exist');

  final libs = <String, Uri>{};
  for (final file in dir.listSync().whereType<File>()) {
    final base = file.uri.pathSegments.last;
    if (!_isSharedLib(base, os)) continue;
    final main = _mainAssets.entries
        .where((e) => base == os.dylibFileName(e.key))
        .firstOrNull;
    libs[main?.value ?? 'helper/$base'] = file.absolute.uri;
  }
  if (!libs.containsKey(boardControllerAsset)) {
    throw StateError(
      'lib_dir ${dir.path} has no ${os.dylibFileName('BoardController')}',
    );
  }
  return libs;
}

bool _isSharedLib(String name, OS os) => switch (os) {
  OS.windows => name.endsWith('.dll'),
  OS.macOS || OS.iOS => name.endsWith('.dylib'),
  _ => name.endsWith('.so'),
};

// --- download + extract ------------------------------------------------------

Uri _cacheDir(BuildInput input) {
  final custom = input.userDefines.path('download_cache');
  if (custom != null) return custom;
  final env = Platform.environment;
  final base = Platform.isWindows ? env['LOCALAPPDATA'] : env['HOME'];
  if (base != null && base.isNotEmpty) {
    final sub = Platform.isWindows
        ? 'flutter_brainflow'
        : '.cache/flutter_brainflow';
    return Directory(base).uri.resolve('$sub/');
  }
  return input.outputDirectoryShared.resolve('download/');
}

/// Downloads [archive] into [cacheDir] (once, guarded by a file lock because
/// hooks for several architectures may run concurrently) and verifies it.
Future<File> _download(ReleaseArchive archive, Uri cacheDir) async {
  final dir = Directory.fromUri(cacheDir.resolve('$brainflowVersion/'))
    ..createSync(recursive: true);
  final file = File.fromUri(dir.uri.resolve(archive.fileName));
  final lock = await File.fromUri(
    dir.uri.resolve('${archive.fileName}.lock'),
  ).open(mode: FileMode.write);
  await lock.lock(FileLock.blockingExclusive);
  try {
    if (file.existsSync() && await _sha256(file) == archive.sha256) {
      return file;
    }
    final partial = File('${file.path}.part');
    final client = HttpClient()
      ..findProxy = HttpClient.findProxyFromEnvironment;
    try {
      final response = await (await client.getUrl(archive.url)).close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'HTTP ${response.statusCode} downloading ${archive.url}',
        );
      }
      await response.pipe(partial.openWrite());
    } finally {
      client.close();
    }
    final actual = await _sha256(partial);
    if (actual != archive.sha256) {
      partial.deleteSync();
      throw StateError(
        'Checksum mismatch for ${archive.url}: expected ${archive.sha256}, '
        'got $actual',
      );
    }
    partial.renameSync(file.path);
    return file;
  } finally {
    await lock.unlock();
    await lock.close();
  }
}

Future<String> _sha256(File file) async =>
    (await sha256.bind(file.openRead()).first).toString();

/// Extracts the files of [target] from [archiveFile] into
/// `<outDir>/<targetName>/`, skipping work if a previous run completed.
Map<String, Uri> _extract(
  File archiveFile,
  TargetLibs target,
  Uri outDir,
  String targetName,
) {
  final dir = Directory.fromUri(outDir.resolve('$targetName/'));
  final result = {
    for (final MapEntry(key: path, value: asset) in target.files.entries)
      asset: dir.uri.resolve(path.split('/').last),
  };
  final done = File.fromUri(dir.uri.resolve('.complete'));
  if (done.existsSync() && done.readAsStringSync() == archiveFile.path) {
    return result;
  }

  dir.createSync(recursive: true);
  final input = InputFileStream(archiveFile.path);
  try {
    final archive = target.archive.isZip
        ? ZipDecoder().decodeStream(input)
        : TarDecoder().decodeStream(input);
    final missing = {...target.files.keys};
    for (final entry in archive.files) {
      final name = entry.name.startsWith('./')
          ? entry.name.substring(2)
          : entry.name;
      if (!entry.isFile || !missing.remove(name)) continue;
      final out = File.fromUri(dir.uri.resolve(name.split('/').last));
      final output = OutputFileStream(out.path);
      entry.writeContent(output);
      output.closeSync();
    }
    if (missing.isNotEmpty) {
      throw StateError('${archiveFile.path} lacks ${missing.join(', ')}');
    }
  } finally {
    input.closeSync();
  }
  done.writeAsStringSync(archiveFile.path);
  return result;
}
