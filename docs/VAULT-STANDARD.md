# The vault standard

What makes a repo a *vault* here, why each rule exists, and how to bring an existing vault up to
the standard.

This was written by distilling four vaults that already existed — `notes-perpetuator`,
`notes-weown`, `notes-nik`, `notes-invest` — each of which had solved the same problems slightly
differently. Where they disagreed, this document picks one answer and says why.

---

## 1. A vault is Markdown that a human reads and an agent writes

Portable Markdown, YAML frontmatter, `[[wiki-links]]`. No content trapped in a format it cannot be
exported from. Git is present for durability and history, **not** as a review workflow — see §3.

## 2. `.obsidian/` is tracked, because an untracked one is not a vault you can clone

A vault whose config lives only on one Mac is a folder, not a repo. Track it, and a fresh clone —
on a laptop or a phone — opens with the right theme, the right hotkeys, and sync already running.

**Track:** `.obsidian/*.json` · `snippets/*.css` · `themes/<Theme>/` ·
`plugins/*/{main.js,manifest.json,styles.css}`

**Ignore:** `workspace.json`, `workspace-mobile.json` (per-machine pane layout — it churns on every
session and conflicts constantly across devices) · `plugins/*/data.json` (see §4).

### Why plugin binaries are vendored rather than fetched

The obvious design is a bootstrap script that downloads plugins on first clone. It fails on the
case that matters most: **Obsidian on mobile cannot run a script.** And `obsidian-git` is the
plugin that *does* the syncing — if it isn't already in the clone, there is no way to bring it in
on a phone. The chicken has to be in the egg.

Cost is ~3.7 MB per vault. The usual objection to vendoring — binaries silently rotting — is
answered by pinning (§5), not by avoiding it.

## 3. The `obsidian-git` plugin owns `main`

The plugin auto-commits every ~5 min and pushes every ~15 min. Everything else follows from that:

| Changing… | How |
|---|---|
| **Vault content** | Write the files. The plugin commits. **Never hand-commit** — a manual commit races the plugin and splits one logical change across two commits with useless messages. |
| **Vault configuration** | Ships like code: branch → `merge/<agent>` → one PR. |

**CI is report-only, always.** A workflow that commits fixes would fight the plugin for `main`. A
red run means *drift exists*; a human or agent fixes it locally and the next backup push clears
it. This is why `vault-hygiene.yml` never writes to the repo.

**Sync settings** — commit 5 min · push 15 min · pull 30 min · **pull-on-boot** · `syncMethod:
merge`. Pull-on-boot is what stops a phone edit and a desktop edit from colliding; merge (never
rebase) is what keeps the plugin's automatic conflict handling sane. `notes-perpetuator` runs with
pull-on-boot off — that is the older setting, not the standard.

## 4. Tracking config means guarding against secrets in config

This is the rule that earns the others. Once `.obsidian/` is in git, any plugin that writes a
credential into its settings writes it into your repo. **Copilot's `data.json` holds an API key.**

So `plugins/*/data.json` is git-ignored wholesale, with exactly one negated exception:
`plugins/obsidian-git/data.json` — it has no credential fields, and its sync cadence is precisely
the thing that must be versioned.

Never un-ignore a second one to make a setting stick. If a plugin's settings must be shared,
extract the non-secret subset into a tracked file and have the plugin read that.

`scripts/vault-check.sh` enforces all of it in CI:

1. no plugin `data.json` tracked except `obsidian-git`'s
2. no secret-shaped key (`api_key`, `token`, `secret`, `password`, `client_secret`, …) carrying a
   non-empty value in any tracked `.obsidian` file
3. no per-machine `workspace.json` tracked
4. every plugin enabled in `community-plugins.json` is actually vendored — otherwise a fresh clone
   opens without it and the failure is silent until someone notices sync stopped
5. the theme `appearance.json` selects is actually present

Each check was **negative-tested** — confirmed to fail when it should, not merely to pass when
everything is fine. A guard that has never gone red is not a guard.

## 5. Plugin and theme versions are pinned

`scripts/vault-plugins.sh` holds the pins and is the only sanctioned way to install or upgrade:

```bash
./scripts/vault-plugins.sh --check   # audit installed vs pinned; changes nothing
./scripts/vault-plugins.sh           # install/refresh at the pins
```

Upgrade = edit the pin → run → review the diff → commit. CI runs `--check`, so a vault cannot
quietly drift from its declared versions. Settings (`data.json`) are never touched by the script.

## 6. Each vault gets its own nightly CI minute

`vault-hygiene.yml` runs on every backup push *and* nightly. The nightly cron uses an off-minute,
unique per vault, so a fleet of vaults doesn't stampede the runner at `:00`:

| Vault | Nightly (UTC) |
|---|---|
| `notes-perpetuator` | `23 5` |
| `notes-nik` | `37 5` |
| `notes-invest` | `51 5` |

`vault-init.sh` assigns a new vault its own minute deterministically from the vault name.

---

## Retrofit checklist — bringing an existing vault to the standard

Observed drift as of 2026-08-11:

| Vault | Drift | Fix |
|---|---|---|
| `notes-weown` | `.gitignore` excludes **all** of `.obsidian/` — no config in git at all, so a clone opens as a bare vault with no theme, no plugins, no sync | adopt the ignore rules below; commit the config, snippets, theme, and plugin binaries |
| `notes-perpetuator` | tracks `.obsidian/workspace.json` (per-machine churn); vendors Copilot, whose `data.json` sits one `git add` away from the repo | untrack `workspace.json`; confirm `plugins/*/data.json` is ignored |
| `notes-nik` | tracks `.DS_Store` (×10) and `.obsidian/snippets/.DS_Store`; Minimal pinned at 8.1.2 while the others run 8.2.1; no `obsidian-git` plugin vendored at all | untrack `.DS_Store`; run `vault-plugins.sh` |

Steps, per vault:

1. Copy `scripts/vault-check.sh`, `scripts/vault-plugins.sh`, `.gitea/workflows/vault-hygiene.yml`
   (set its own cron minute per §6).
2. Adopt the `.gitignore` `.obsidian` block from this template.
3. Run `./scripts/vault-plugins.sh` to install/refresh at the pins.
4. Run `./scripts/vault-check.sh` and clear every finding.
5. Ship it as a config PR — not as a plugin auto-commit.

Untracking already-committed files is a **destructive-ish** step (`git rm --cached`) and stays a
human decision; the check reports them rather than fixing them.

---

## What this template deliberately does not do

- **No Copilot by default.** 5.3 MB, and its settings file is the exact secret-bearing case §4
  exists for. Install it per-vault if wanted; the ignore rules already contain it.
- **No content scaffolding.** Folder taxonomy is a per-vault decision; `CLAUDE.md` and `Landing.md`
  ship with the table stub and nothing more.
- **No vault linter.** `notes-perpetuator` and `notes-nik` share a `vault_lint.py` tuned to their
  own structure (SOP registers, `destiny:` frontmatter, root allowlists). That is content policy,
  not vault mechanics, and does not generalize. `vault-check.sh` covers only what *every* vault
  has: its Obsidian config.
