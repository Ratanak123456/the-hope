#!/usr/bin/env bash
# Optional static analysis for the Luau sources.
#
# Downloads luau-lsp (open source, MIT) and Roblox's type definitions into
# tools/.bin on first run, then type-checks and lints everything under src/.
# Nothing here is required to build or play the game - delete it if you like.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/tools/.bin"
mkdir -p "$BIN"

if [ ! -x "$BIN/luau-lsp" ]; then
  echo "Fetching luau-lsp..."
  curl -sL -o "$BIN/lsp.zip" \
    https://github.com/JohnnyMorganz/luau-lsp/releases/latest/download/luau-lsp-linux-x86_64.zip
  unzip -oq "$BIN/lsp.zip" -d "$BIN"
  chmod +x "$BIN/luau-lsp"
fi

if [ ! -f "$BIN/globalTypes.d.luau" ]; then
  echo "Fetching Roblox type definitions..."
  curl -sL -o "$BIN/globalTypes.d.luau" \
    https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.PluginSecurity.d.luau
fi

echo '{ "languageMode": "nonstrict" }' > "$BIN/.luaurc"
echo '{ "luau-lsp.require.mode": "relativeToFile" }' > "$BIN/settings.json"

cd "$ROOT"
rojo sourcemap default.project.json -o "$BIN/sourcemap.json" >/dev/null

"$BIN/luau-lsp" analyze \
  --definitions="$BIN/globalTypes.d.luau" \
  --sourcemap="$BIN/sourcemap.json" \
  --base-luaurc="$BIN/.luaurc" \
  --settings="$BIN/settings.json" \
  $(find src -name '*.lua')

echo "No diagnostics."
