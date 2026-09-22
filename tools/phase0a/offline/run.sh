#!/usr/bin/env bash
# Regenerate the bundle and run the Phase 0.A offline verification.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
LUAU="$ROOT/tools/.bin/luau"
if [ ! -x "$LUAU" ]; then
  echo "Fetching the Luau CLI..."
  curl -sL -o "$ROOT/tools/.bin/luau.zip" \
    https://github.com/luau-lang/luau/releases/latest/download/luau-ubuntu.zip
  unzip -oq "$ROOT/tools/.bin/luau.zip" -d "$ROOT/tools/.bin"
  chmod +x "$LUAU"
fi
python3 "$HERE/build.py" >/dev/null
exec "$LUAU" "$HERE/bundle.generated.luau"
