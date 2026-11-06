#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
flutter create --project-name webos_remote --org vn.local.webosremote --platforms android,windows,macos,linux .
# flutter create generates its sample widget test; our UI has a dedicated test.
if [ -f test/widget_test.dart ] && grep -q 'Counter increments smoke test' test/widget_test.dart; then
  rm test/widget_test.dart
fi
python3 scripts/platform_permissions.py
flutter pub get
flutter analyze
flutter test
