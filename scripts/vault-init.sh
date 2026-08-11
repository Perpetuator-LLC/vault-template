#!/usr/bin/env bash
# Personalize a vault freshly generated from vault-template. Run once, from the vault root:
#
#   ./scripts/vault-init.sh "My Vault Name"
#
# Idempotent — safe to re-run; anything already personalized is left alone.
#
# What it does:
#   1. substitutes {{VAULT_NAME}} into CLAUDE.md, AGENTS.md, Landing.md
#   2. gives the vault its own nightly CI minute (derived from the name, so it's stable)
#   3. replaces the template's README.md with a vault stub
#   4. runs the hygiene check so you learn immediately if something is off
set -uo pipefail

cd "$(dirname "$0")/.." || exit 2

VAULT_NAME="${1:-}"
if [ -z "$VAULT_NAME" ]; then
  echo "usage: ./scripts/vault-init.sh \"My Vault Name\"" >&2
  exit 2
fi

changed=0
sub() {  # $1 = file — substitute the vault name in place
  [ -f "$1" ] || return 0
  if grep -q '{{VAULT_NAME}}' "$1"; then
    python3 - "$1" "$VAULT_NAME" <<'PY'
import sys
path, name = sys.argv[1], sys.argv[2]
with open(path, encoding='utf-8') as fh:
    body = fh.read()
with open(path, 'w', encoding='utf-8') as fh:
    fh.write(body.replace('{{VAULT_NAME}}', name))
PY
    echo "  named    $1"
    changed=1
  else
    echo "  ok       $1 (already personalized)"
  fi
}

echo "== 1. vault name =="
sub CLAUDE.md
sub AGENTS.md
sub Landing.md

echo "== 2. nightly CI minute =="
WF=".gitea/workflows/vault-hygiene.yml"
if [ -f "$WF" ] && grep -q '{{CRON_SLOT}}' "$WF"; then
  # deterministic from the vault name so re-running never reshuffles it
  MINUTE=$(printf '%s' "$VAULT_NAME" | cksum | awk '{print $1 % 60}')
  python3 - "$WF" "$MINUTE" <<'PY'
import re, sys
path, minute = sys.argv[1], sys.argv[2]
with open(path, encoding='utf-8') as fh:
    body = fh.read()
body = re.sub(r'- cron: "\d+ 5 \* \* \*"\s*# \{\{CRON_SLOT\}\}',
              f'- cron: "{minute} 5 * * *"', body)
with open(path, 'w', encoding='utf-8') as fh:
    fh.write(body)
PY
  echo "  set      nightly run at 05:$(printf '%02d' "$MINUTE") UTC"
  changed=1
else
  echo "  ok       $WF (already personalized)"
fi

echo "== 3. README =="
if [ -f README.md ] && grep -q 'VAULT-TEMPLATE-MARKER' README.md; then
  cat > README.md <<EOF
# $VAULT_NAME

An Obsidian knowledge vault. Open this folder in Obsidian and enable plugins — theme, snippets,
and sync are already configured.

Git is an **automated backup channel** here: the \`obsidian-git\` plugin auto-commits and pushes
\`main\` on its own. Write notes freely; don't hand-commit them. Configuration changes
(\`.obsidian/\`, \`scripts/\`, \`.gitea/\`) ship like code — branch → PR.

- Entry point: [Landing.md](Landing.md)
- Agent instructions: [CLAUDE.md](CLAUDE.md)
- Vault standard and rationale: [docs/VAULT-STANDARD.md](docs/VAULT-STANDARD.md)

## Maintenance

\`\`\`bash
./scripts/vault-check.sh            # hygiene + secret guard
./scripts/vault-plugins.sh --check  # plugin/theme versions vs the pins
\`\`\`
EOF
  echo "  wrote    README.md for \"$VAULT_NAME\""
  changed=1
else
  echo "  ok       README.md (already personalized)"
fi

echo "== 4. hygiene check =="
./scripts/vault-check.sh
rc=$?

echo
if [ "$changed" -eq 1 ]; then
  echo "vault-init: done. Review the diff, then commit:"
  echo "  git add -u && git commit -m 'Initialize $VAULT_NAME vault'"
else
  echo "vault-init: nothing to do — this vault is already initialized."
fi
echo "Next: open the folder in Obsidian and choose 'Trust author and enable plugins'."
exit "$rc"
