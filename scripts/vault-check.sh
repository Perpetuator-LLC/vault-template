#!/usr/bin/env bash
# Vault hygiene check — guards the risk introduced by tracking .obsidian/ in git.
#
# REPORT-AND-FAIL, never fixes: the vault's git is owned by the obsidian-git plugin,
# so CI must not commit. A red run means "drift exists" — fix locally, let the next
# backup push clear it.
#
# Run from the vault root:  ./scripts/vault-check.sh
set -uo pipefail

cd "$(dirname "$0")/.." || exit 2
fail=0
warn=0

err()  { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; fail=$((fail + 1)); }
note() { printf '  \033[33mWARN\033[0m  %s\n' "$1"; warn=$((warn + 1)); }
ok()   { printf '  \033[32m ok \033[0m  %s\n' "$1"; }

tracked() { git ls-files "$@"; }

echo "== 1. plugin settings files (may carry API keys) =="
# Only obsidian-git's data.json is allowed in git: it has no credential fields and its
# sync cadence must be versioned. Copilot & friends store API keys in theirs.
stray=$(tracked '.obsidian/plugins/*/data.json' | grep -v '^\.obsidian/plugins/obsidian-git/data\.json$' || true)
if [ -n "$stray" ]; then
  while IFS= read -r f; do err "tracked plugin data.json (may hold a secret): $f"; done <<< "$stray"
else
  ok "no plugin data.json tracked except obsidian-git"
fi

echo "== 2. secret-shaped values in tracked .obsidian config =="
hits=0
while IFS= read -r f; do
  [ -f "$f" ] || continue
  # a secret-ish key with a NON-empty string value
  if grep -Eq '"(api[_-]?key|apiKey|token|secret|password|passphrase|client[_-]?secret)"[[:space:]]*:[[:space:]]*"[^"]+"' "$f"; then
    err "secret-shaped key with a value in tracked file: $f"
    hits=$((hits + 1))
  fi
done < <(tracked '.obsidian/*.json' '.obsidian/**/*.json')
[ "$hits" -eq 0 ] && ok "no secret-shaped values in tracked .obsidian config"

echo "== 3. per-machine state must not be tracked =="
for pat in '.obsidian/workspace.json' '.obsidian/workspace-mobile.json'; do
  if [ -n "$(tracked "$pat")" ]; then
    err "per-machine state tracked (churns every session): $pat"
  fi
done
ds=$(tracked '*.DS_Store' | wc -l | tr -d ' ')
[ "$ds" != "0" ] && note "$ds tracked .DS_Store file(s) — untrack with: git rm --cached '*.DS_Store'"
[ "$fail" -eq 0 ] && ok "no workspace state tracked"

echo "== 4. every enabled community plugin is actually vendored =="
if [ -f .obsidian/community-plugins.json ]; then
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    if [ -f ".obsidian/plugins/$id/main.js" ] && [ -f ".obsidian/plugins/$id/manifest.json" ]; then
      ver=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("version","?"))' ".obsidian/plugins/$id/manifest.json" 2>/dev/null || echo '?')
      ok "$id ($ver)"
    else
      err "enabled in community-plugins.json but not vendored: $id — a fresh clone (esp. mobile) will open without it"
    fi
  done < <(python3 -c 'import json;print("\n".join(json.load(open(".obsidian/community-plugins.json"))))' 2>/dev/null)
fi

echo "== 5. theme present =="
theme=$(python3 -c 'import json;print(json.load(open(".obsidian/appearance.json")).get("cssTheme",""))' 2>/dev/null || echo '')
if [ -n "$theme" ]; then
  if [ -f ".obsidian/themes/$theme/theme.css" ]; then ok "theme $theme vendored"
  else err "appearance.json selects theme '$theme' but .obsidian/themes/$theme/theme.css is missing"; fi
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "vault-check: $fail failure(s), $warn warning(s)"
  exit 1
fi
echo "vault-check: clean ($warn warning(s))"
exit 0
