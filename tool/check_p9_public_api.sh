#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "$script_dir/.." && pwd)"
flutter_bin="${FLUTTER_BIN:-flutter}"

cd "$project_root"
"$flutter_bin" test \
  test/architecture/public_api_surface_test.dart \
  test/architecture/sdk_candidate_surface_test.dart \
  test/architecture/sdk_facade_contract_test.dart \
  test/architecture/p9_release_documentation_test.dart
