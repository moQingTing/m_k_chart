#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "$script_dir/.." && pwd)"
flutter_bin="${FLUTTER_BIN:-flutter}"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "P9 build gate requires macOS because it includes iOS builds." >&2
  exit 1
fi

cd "$project_root/example"

"$flutter_bin" build apk --profile
"$flutter_bin" build apk --release
"$flutter_bin" build ios --profile --no-codesign
"$flutter_bin" build ios --release --no-codesign
"$flutter_bin" build web --profile
"$flutter_bin" build web --release
