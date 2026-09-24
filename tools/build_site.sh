#!/usr/bin/env bash
# Builds the static playtest site: one folder per MVP plus a landing page.
#   tools/build_site.sh [path/to/godot]      → build/site/
# HTML prototypes are copied as they are (symlinks resolved); Godot prototypes
# are exported with the "Web" preset from their export_presets.cfg. Needs the
# Godot web export templates for the exact engine version.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${1:-${GODOT:-godot}}"
OUT="$ROOT/build/site"
HTML_MVPS=(mvp_beta mvp_ceta mvp_delta)
GODOT_MVPS=(mvp_epsilon mvp_zeta)

# Headless Godot idles forever on a script parse error instead of exiting.
run_godot() {
	if command -v timeout >/dev/null 2>&1; then
		timeout 600 "$GODOT" "$@"
	else
		"$GODOT" "$@"
	fi
}

rm -rf "$OUT"
mkdir -p "$OUT"

for mvp in "${HTML_MVPS[@]}"; do
	echo "== $mvp (HTML)"
	cp -RL "$ROOT/$mvp" "$OUT/$mvp"
done

for mvp in "${GODOT_MVPS[@]}"; do
	echo "== $mvp (Godot → Web)"
	mkdir -p "$OUT/$mvp"
	# Fresh checkouts have no .godot/ import cache yet.
	run_godot --headless --path "$ROOT/$mvp" --import
	run_godot --headless --path "$ROOT/$mvp" --export-release "Web" "$OUT/$mvp/index.html"
	test -s "$OUT/$mvp/index.wasm" || { echo "export of $mvp produced no wasm" >&2; exit 1; }
done

cp "$ROOT/site/index.html" "$OUT/index.html"
touch "$OUT/.nojekyll"
du -sh "$OUT"/* | sed 's|'"$OUT"'/||'
