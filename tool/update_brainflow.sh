#!/usr/bin/env bash
# Bump the pinned BrainFlow version.
#
#   tool/update_brainflow.sh 5.24.0
#
# Downloads the release headers and archives, updates hook/brainflow_release.dart
# (version + SHA-256), refreshes android/libs/simpleble-bridge.jar and
# regenerates the Dart bindings and enums. Review the diff afterwards: new
# functions in the headers need wrapping, changed signatures need fixing.
set -euo pipefail

version="${1:?usage: $0 <brainflow-version>}"
root="$(cd "$(dirname "$0")/.." && pwd)"
raw="https://raw.githubusercontent.com/brainflow-dev/brainflow/${version}"
rel="https://github.com/brainflow-dev/brainflow/releases/download/${version}"
cache="${HOME}/.cache/flutter_brainflow/${version}"

echo "==> Headers"
inc="${root}/third_party/brainflow/include"
for f in src/board_controller/inc/board_controller.h \
         src/board_controller/inc/board_info_getter.h \
         src/data_handler/inc/data_handler.h \
         src/ml/inc/ml_module.h \
         src/utils/inc/shared_export.h \
         src/utils/inc/brainflow_constants.h; do
  curl -fsSL -o "${inc}/$(basename "$f")" "${raw}/${f}"
done
curl -fsSL -o "${inc}/LICENSE" "${raw}/LICENSE"

echo "==> Release archives (into ${cache}, reused by the build hook)"
mkdir -p "${cache}"
for f in compiled_libs.tar brainflow-android.aar; do
  if [ ! -f "${cache}/${f}" ]; then
    curl -fL --progress-bar -o "${cache}/${f}.part" "${rel}/${f}"
    mv "${cache}/${f}.part" "${cache}/${f}"
  fi
done
sha_tar="$(sha256sum "${cache}/compiled_libs.tar" | cut -d' ' -f1)"
sha_aar="$(sha256sum "${cache}/brainflow-android.aar" | cut -d' ' -f1)"

echo "==> hook/brainflow_release.dart"
release="${root}/hook/brainflow_release.dart"
sed -i -E "s/^const brainflowVersion = '.*';/const brainflowVersion = '${version}';/" "${release}"
# The SHA-256 is the line after each archive's file name.
sed -i -E "/'compiled_libs.tar',/{n;s/'[0-9a-f]{64}'/'${sha_tar}'/}" "${release}"
sed -i -E "/'brainflow-android.aar',/{n;s/'[0-9a-f]{64}'/'${sha_aar}'/}" "${release}"

echo "==> android/libs/simpleble-bridge.jar"
unzip -o -q -j "${cache}/brainflow-android.aar" libs/simpleble-bridge.jar -d "${root}/android/libs"
sha_jar="$(sha256sum "${root}/android/libs/simpleble-bridge.jar" | cut -d' ' -f1)"
sed -i -E "s/BrainFlow [0-9][0-9.]* \(SHA-256/BrainFlow ${version} (SHA-256/; s/\`[0-9a-f]{64}\`/\`${sha_jar}\`/" \
  "${root}/android/libs/README.md"

echo "==> Regenerate bindings and enums"
cd "${root}"
dart run tool/ffigen.dart
dart run tool/generate_constants.dart

echo
echo "Done. Also update the version expected in test/native/smoke_test.dart,"
echo "then run: flutter analyze && flutter test"
