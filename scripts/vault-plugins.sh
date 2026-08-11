#!/usr/bin/env bash
# Install / refresh the vault's Obsidian plugins + theme at PINNED versions.
#
# Plugin binaries are vendored into git on purpose: Obsidian on mobile cannot run a
# bootstrap script, and without obsidian-git already present there is no way to sync
# the vault on a phone at all. This script is how those vendored copies get created
# and upgraded — edit the PINS below, run it, review the diff, commit.
#
#   ./scripts/vault-plugins.sh            # install/refresh everything at the pins
#   ./scripts/vault-plugins.sh --check    # report installed vs pinned, change nothing
#
# Settings (.obsidian/plugins/*/data.json) are never touched.
set -uo pipefail

cd "$(dirname "$0")/.." || exit 2

# --- PINS: plugin-id  github-repo  version ----------------------------------
PLUGINS=(
  "obsidian-git|Vinzent03/obsidian-git|2.38.0"
  "obsidian-tasks-plugin|obsidian-tasks-group/obsidian-tasks|8.2.2"
  "numerals|gtg922r/obsidian-numerals|1.5.5"
)
# --- theme: name  github-repo  version --------------------------------------
THEME_NAME="Minimal"
THEME_REPO="kepano/obsidian-minimal"
THEME_VERSION="8.2.1"

CHECK=0
[ "${1:-}" = "--check" ] && CHECK=1

installed_version() {  # $1 = manifest path
  [ -f "$1" ] || { echo "-"; return; }
  python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("version","?"))' "$1" 2>/dev/null || echo '?'
}

fetch() {  # $1 = url, $2 = dest ; returns non-zero on any failure (incl. 404)
  curl -fsSL --retry 2 --max-time 60 -o "$2" "$1"
}

rc=0

for entry in "${PLUGINS[@]}"; do
  IFS='|' read -r id repo version <<< "$entry"
  dir=".obsidian/plugins/$id"
  have=$(installed_version "$dir/manifest.json")

  if [ "$have" = "$version" ]; then
    printf '  ok      %-24s %s\n' "$id" "$version"
    continue
  fi
  if [ "$CHECK" -eq 1 ]; then
    printf '  DRIFT   %-24s installed=%s pinned=%s\n' "$id" "$have" "$version"
    rc=1
    continue
  fi

  printf '  install %-24s %s -> %s\n' "$id" "$have" "$version"
  mkdir -p "$dir"
  base="https://github.com/$repo/releases/download/$version"
  tmp=$(mktemp -d)
  for f in main.js manifest.json styles.css; do
    if fetch "$base/$f" "$tmp/$f"; then
      cp "$tmp/$f" "$dir/$f"
    elif [ "$f" = "styles.css" ]; then
      :  # optional asset — not every plugin ships one
    else
      echo "    ERROR: could not download $f from $base" >&2
      rc=1
    fi
  done
  rm -rf "$tmp"
done

# --- theme ------------------------------------------------------------------
tdir=".obsidian/themes/$THEME_NAME"
have=$(installed_version "$tdir/manifest.json")
if [ "$have" = "$THEME_VERSION" ]; then
  printf '  ok      %-24s %s\n' "theme:$THEME_NAME" "$THEME_VERSION"
elif [ "$CHECK" -eq 1 ]; then
  printf '  DRIFT   %-24s installed=%s pinned=%s\n' "theme:$THEME_NAME" "$have" "$THEME_VERSION"
  rc=1
else
  printf '  install %-24s %s -> %s\n' "theme:$THEME_NAME" "$have" "$THEME_VERSION"
  mkdir -p "$tdir"
  tbase="https://github.com/$THEME_REPO/releases/download/$THEME_VERSION"
  for f in theme.css manifest.json; do
    fetch "$tbase/$f" "$tdir/$f" || { echo "    ERROR: could not download $f from $tbase" >&2; rc=1; }
  done
fi

echo
if [ "$rc" -ne 0 ] && [ "$CHECK" -eq 1 ]; then
  echo "vault-plugins: drift vs pins — run without --check to install"
elif [ "$rc" -ne 0 ]; then
  echo "vault-plugins: finished with errors"
else
  echo "vault-plugins: all at pinned versions"
fi
exit "$rc"
