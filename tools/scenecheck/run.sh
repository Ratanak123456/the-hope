#!/usr/bin/env bash
#
# Render the opening's own shots, and the welcome screen, from the real
# modules - a composition review without Roblox Studio.
#
#   ./tools/scenecheck/run.sh            both, into docs/visual-rebuild/scenecheck
#   ./tools/scenecheck/run.sh menu       just the welcome screen
#   ./tools/scenecheck/run.sh opening 06 just the shots whose tag contains "06"
#
# Read the caveats at the top of render.py before drawing conclusions: this
# shows geometry, framing and scale, never Roblox materials, lights or fog.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
LUAU="$ROOT/tools/.bin/luau"
OUT="${SCENECHECK_OUT:-$ROOT/docs/visual-rebuild/scenecheck}"
WHICH="${1:-both}"
FILTER="${2:-}"

render_set() {
  local name="$1"
  python3 "$HERE/build.py" "$name" >/dev/null
  "$LUAU" "$HERE/$name.generated.luau" | tail -n 1 > "$HERE/$name.json"
  python3 "$HERE/render.py" "$HERE/$name.json" "$OUT" ${FILTER:+"$FILTER"}
  python3 "$HERE/frame_report.py" "$HERE/$name.json" ${FILTER:+"$FILTER"} \
    > "$OUT/$name-framing.txt"
  # The dump is several megabytes of per-run scene data, not something the
  # repo should carry; the framing report and the frames are the output.
  rm -f "$HERE/$name.json"
}

mkdir -p "$OUT"
case "$WHICH" in
  menu)    render_set menu ;;
  opening) render_set opening ;;
  lineup)  render_set lineup ;;
  aegis)   render_set aegis ;;
  both)    render_set menu; render_set opening ;;
  *) echo "usage: run.sh [menu|opening|lineup|aegis|both] [tag filter]" >&2; exit 2 ;;
esac
echo "frames and framing reports in $OUT"
