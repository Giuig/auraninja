#!/usr/bin/env bash
# Ensures libflutter_soloud_plugin.so is built without a GNU Build ID,
# which is required for byte-for-byte reproducible builds (IzzyOnDroid / F-Droid).
#
# The upstream flutter_soloud CMakeLists.txt does not include this flag, so it
# gets wiped every time the vendored package is updated. This script re-applies
# the patch idempotently — safe to run multiple times.

set -euo pipefail

CMAKE="third_party/flutter_soloud/android/CMakeLists.txt"

if ! grep -q 'build-id=none' "$CMAKE"; then
  echo "Patching $CMAKE: adding -Wl,--build-id=none"
  cat >> "$CMAKE" <<'EOF'

# Support Android 15 16k page size
target_link_options("${PLUGIN_NAME}" PRIVATE "-Wl,-z,max-page-size=16384")
# Disable GNU Build ID so the binary is byte-for-byte reproducible across
# machines — required for F-Droid / IzzyOnDroid distribution.
target_link_options("${PLUGIN_NAME}" PRIVATE "-Wl,--build-id=none")
EOF
  echo "Patch applied."
else
  echo "$CMAKE already patched, skipping."
fi
