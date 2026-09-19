<!-- VAULT-TEMPLATE-MARKER: scripts/vault-init.sh replaces this file in a generated vault -->
# vault-template

The starting point for a **git-synced Obsidian vault**. Generate from this repo and you get a
vault that opens ready to use — theme, snippets, hotkeys, and `obsidian-git` already configured
and already syncing — on desktop *and* on a phone.

Distilled from the four vaults that came before it (`the company vault`, `a client vault`,
`the personal vault`, `the investing vault`), which had each solved this differently and drifted apart.

---

## Use it

1. **Gitea → Use this template** (or *New Repository → Repository Template → `vault-template`*).
2. Clone, then personalize:

```bash
./scripts/vault-init.sh "My Vault Name"
```

That substitutes the vault name into `CLAUDE.md` / `Landing.md`, replaces this README with a vault
stub, assigns the vault its own nightly CI minute, and runs the hygiene check.

3. Open the folder in Obsidian → **Trust author and enable plugins**.

That is the whole setup. `obsidian-git` is already configured, so the vault begins auto-committing
and pushing on its own.

---

## What's in the box

| | |
|---|---|
| **Theme** | Minimal 8.2.1 (`@kepano`) |
| **Snippets** | `obsidian.css` (dark palette, hidden frontmatter, 60em measure), `line-numbers.css` |
| **Plugins** | `obsidian-git` 2.38.0 · `obsidian-tasks-plugin` 8.2.2 · `numerals` 1.5.5 |
| **Sync cadence** | commit 5 min · push 15 min · pull 30 min · pull-on-boot · merge (never rebase) |
| **Editor** | vim mode, line numbers, `Mod+[` / `Mod+]` navigation, Letter-size PDF export |
| **CI** | `vault-hygiene` — runs the checks on every backup push + nightly, report-only |

Not included by default: **Copilot**. It is 5.3 MB and stores an API key in its `data.json`.
**Leaving it out is a security control, not a size optimization** — obsidian-git has been observed
committing files that `.gitignore` excludes by name (see
[docs/VAULT-STANDARD.md §4](docs/VAULT-STANDARD.md)), so an ignore rule will not reliably keep a
credential-bearing settings file out of a vault that has the plugin installed.

---

## The two decisions this template makes for you

### 1. Plugin binaries are vendored into git

Not fetched by a bootstrap script. **Obsidian on mobile cannot run a script**, and without
`obsidian-git` already present in the clone there is no way to sync the vault on a phone at all —
the chicken has to be in the egg. Cost: ~3.7 MB per vault.

The tradeoff that usually kills vendoring — binaries silently going stale — is handled by pinning:

```bash
./scripts/vault-plugins.sh --check   # installed vs pinned, changes nothing
./scripts/vault-plugins.sh           # install/refresh at the pins
```

Upgrades are: edit the pin → run → review the diff → commit. CI fails on drift, so a vault cannot
quietly fall behind.

### 2. Config is tracked; state and secrets are not

Tracking `.obsidian/` is what makes a fresh clone usable. It also means a plugin can write a
secret into a tracked file — Copilot's `data.json` **does** hold an API key. So:

| | |
|---|---|
| **Tracked** | `.obsidian/*.json`, `snippets/`, `themes/`, `plugins/*/{main.js,manifest.json,styles.css}` |
| **Ignored** | `workspace*.json` (per-machine pane layout, churns every session), `plugins/*/data.json` |
| **The one exception** | `plugins/obsidian-git/data.json` — no credential fields, and its sync cadence must be versioned |

⚠️ **The ignore rule is intent, not enforcement** — obsidian-git has been caught staging a file
`.gitignore` excluded by name. The real controls are *not installing credential-storing plugins* and
*the check below*. See [docs/VAULT-STANDARD.md §4](docs/VAULT-STANDARD.md).

`scripts/vault-check.sh` enforces this rather than trusting it:

1. no plugin `data.json` tracked except `obsidian-git`'s
2. no secret-shaped key with a value in any tracked `.obsidian` file
3. no per-machine `workspace.json` tracked
4. every plugin enabled in `community-plugins.json` is actually vendored — otherwise a fresh
   clone (especially mobile) opens without it
5. the theme `appearance.json` selects is actually present

All five were negative-tested: each fails when it should, not merely passes when things are fine.

---

## After the vault is live: git belongs to the plugin

`obsidian-git` auto-commits and pushes `main` by itself. This changes how agents and humans work
in the repo, and it is the single most common way to get burned:

| Changing… | How |
|---|---|
| **Vault content** (notes) | Just write the files. The plugin commits them. **Never hand-commit** — you race the plugin and split one change across two commits. |
| **Vault configuration** (`.obsidian/`, `scripts/`, `.gitea/`, `CLAUDE.md`) | Config ships like code: branch → `merge/<agent>` → one PR. |

CI is report-only for the same reason: a workflow that commits would fight the plugin. A red run
means *drift exists* — fix it locally and let the next backup push clear it.

`CLAUDE.md` carries this rule into every generated vault so the next agent inherits it.

---

## Files

```
.obsidian/          config, snippets, theme, vendored plugins
scripts/
  vault-init.sh     personalize a freshly generated vault (run once)
  vault-check.sh    hygiene + secret guard (CI + local)
  vault-plugins.sh  pinned plugin/theme install & drift audit
.gitea/workflows/
  vault-hygiene.yml report-only CI
docs/
  VAULT-STANDARD.md what makes a vault a vault here, and why each rule exists
CLAUDE.md           agent tripwire layer (templated)
AGENTS.md           pointer for non-Claude agents
Landing.md          vault entry point (templated)
```

See **[docs/VAULT-STANDARD.md](docs/VAULT-STANDARD.md)** for the reasoning behind each rule and
the checklist for bringing an *existing* vault up to this standard.
