#!/usr/bin/env bash
# Regenerate the bundle and run the North Pole cast verification offline.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
python3 "$HERE/build.py" >/dev/null
exec "$ROOT/tools/.bin/luau" "$HERE/bundle.generated.luau"
