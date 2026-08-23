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

### ⚠️ But `.gitignore` is intent, not enforcement — the plugin stages ignored files

**Do not build your protection on the ignore rule.** Verified in `notes-invest` on 2026-08-12:

```
9a5b761  vault backup: 2026-08-12 13:07:05   <- ADDED .obsidian/workspace.json
683fb93  Merge pull request #1 (vault setup) <- its parent
```

That is obsidian-git's **first auto-commit after the setup landed**, and it added
`.obsidian/workspace.json` while **line 20 of `.gitignore` at that same commit excluded the path by
name**. Confirmed via `git log --diff-filter=A` and by reading `.gitignore` at the adding commit.

The consequence is not about pane layouts. **A gitignored `plugins/*/data.json` holding an API key
would be committed the same way.** So the controls, in descending order of how much they are worth:

1. **Do not install a credential-storing plugin into a git-synced vault.** This is the only control
   that holds without the plugin's cooperation, and it is why **Copilot is excluded from this
   template's baseline** — that exclusion is the primary mitigation, not a size optimization.
2. **`scripts/vault-check.sh`, which reads `git ls-files`** — what is *actually tracked*, not what
   the rules claim. It caught this exact drift. But it is **detective, not preventive**: when it
   fires, the file is already committed and pushed. If that file held a key, rotation is already
   required.
3. **`.gitignore`** — keep it, it expresses the intent and it does stop a human `git add .`. Do not
   count on it against the plugin.

Related fleet ticket: `perpetuator/mcp#179`.

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

## 7. Every vault has a landing page, and it carries a recent-files Base

**Directive (Nik, 2026-08-23).** Every vault we create has a landing page, and that landing page
includes a **Base listing files sorted most-recently-edited first**. His reasoning: *"this lets me
pin that page and every time I open the vault I can see the recent pages you edited, which is 99% of
what I care to look at."*

That makes the landing page an **operational surface, not a table of contents** — the one pinned tab
that answers "what changed?" without a search. `Landing.md` in this template carries the reference
implementation; copy it verbatim rather than re-deriving the Base syntax.

**Two views ship, and both are load-bearing:**

- **Everything** — the honest recency answer, no exclusions beyond `Templates/`.
- **Docs only (no journals/threads)** — because nightly ingest engines write journal entries
  continuously, and without this view a vault with active ingest shows nothing but its own exhaust.

⚠️ **Do not port the older "exclude SOPs" filter** some vaults carry (`sop_id.isEmpty()`). It was
written for a different purpose and it hides exactly the documents most likely to have just been
edited — a freshly-amended SOP is invisible in a view that filters SOPs out. Live specimens found
during the 2026-08-23 rollout: `notes-invest` and `notes-nik`.

⚠️ **Check the BASE-LEVEL `filters:` block, not just each view's.** In the reference vault the
`sop_id.isEmpty()` exclusion sits at the **top level** of the base — so it applies to *every* view in
it, including ones whose own `filters:` look clean. **That location is the more dangerous one**,
because someone auditing a view sees only the view's filters and concludes it is fine. Read both
levels before declaring a Base a recency view.

⚠️ **Sealed content: ship `Everything` unfiltered — except paths under an explicit seal, excluded
and documented in place.** The general rule, and it is the one that gets missed: **an exclusion at
the seal must be mirrored in every ENUMERATING surface, Bases included.** A Base is not a viewer of
content; it is an *index over paths and titles*, and an index leaks what the content itself is
protecting. Precedent, measured rather than theorised: **mcp#277** (P1, closed) — `vault_index`
surfaced path, title and description for **all 642** `pii_classification: raw` entries while the
bodies were correctly protected; its own finding was *"a perfect raw marker leaks anyway if the index
built over it is readable."* **Copy its remedy shape: count, never name** — a sealed area renders as a
count, not as rows.

⚠️ **The inline "do not remove this filter" note is a REQUIREMENT, not decoration.** A seal filter
looks like exactly the kind of thing a conformance pass tidies away — *"the standard says ship
Everything unfiltered"* — and removing it **silently unseals the folder** with no error and no
diff anyone reads as dangerous. The note is what stops a correct-looking cleanup from being a
disclosure. Reference implementation: the `notes-nik` estate exclusion.

⚠️ **Verify every wiki-link target exists in YOUR vault before shipping.** A landing page ported
verbatim inherits the source vault's links, and they die silently in the destination — the reference
vault's `[[SOPs/README]]` is live there and dead in any vault without that index doc. *(Caught by the
weown lane mid-application; the notes-nik lane adapted around it independently — twice in one
rollout, which is what makes it a standard line rather than a note.)* The Base block itself carries
no wiki-links precisely so that copying **it** is safe; the hazard is copying the whole page.

**Verify it, don't assume it renders:** a malformed Base block silently shows an error where the
table should be. Parse every ```` ```base ```` block as YAML after editing the landing page.

## 8. Every lane has a `DASHBOARD.md`, and chat carries only deltas

**Directive (Nik, 2026-08-23).** Chat loops scroll pending questions out of view, and re-printing
them every turn wastes tokens and his attention. **The document is the surface; chat carries the
delta.** So every lane keeps a **living** `DASHBOARD.md`, and his own master page aggregates across
lanes (`Engagements/Internal/State/Nik.md` in the Perpetuator vault — the cockpit was already the
designed home for this).

**Shape** — see `DASHBOARD.md` in this template:

1. **Pending on Nik, in priority order** — highest first.
2. **Active work for the lane** — what it is doing and what blocks it.
3. **Deeper** — thin pointers only.

**Five properties, and each has a failure it prevents:**

- **Latest-wins, edited IN PLACE, rows deleted when done.** ⛔ **Named anti-pattern: the
  ORCHESTRATOR-BOARD's banner-stack** — a page that grows by prepending dated blocks becomes a log,
  and a log cannot be read for current state. Same defect mcp#303 recorded for State docs being
  turned into run journals.
- **Every pending row is ANSWERABLE FROM THE PAGE.** State the question *and its options* inline; the
  link is for the reasoning, not the answer. A row reading *"D5's disposition"* is a **label** — it is
  the agent's index of its own documents, and it makes the human do the reading. If he must open the
  link to learn what his choices are, the row has failed. *(This is the `operating-canon` self-
  containment rule applied to a document instead of a message.)*
- **Priority order is real, not decorative.** Security and anything blocking other lanes outrank
  confirmations and review requests.
- **"PENDING ON NIK" MEANS ACTIONABLE BY HIM *NOW*.** A **decided-but-unexecuted** item is not
  pending on him — it waits on an **event**, and it belongs in *Active work* **with its trigger
  named** ("waits on: X answered", "waits on: the #261 re-scope"). *(Ruled 2026-08-23 on the `nik`
  lane's check.)* Otherwise the pending list stops meaning *"what is waiting on you"* and becomes
  *"everything unfinished"* — at which point he has to re-triage it every time he opens the page,
  which is the work the dashboard exists to remove. This is the `operating-canon` comms split —
  `## 👤 You` versus `## ⏭️ Later (blocked on …)` — applied to a document instead of a message.
- ⭐ **NAME WHICH DOCUMENT HOLDS THE HISTORY BEFORE WRITING THE ONE THAT MUST NOT.** *(Contributed by
  the `inference` lane from its port, 2026-08-23 — live in its page as `STATE.md` keeps the
  newest-first record, `DASHBOARD.md` says only what is true now, rows deleted when done.)* **This is
  the property that keeps the other three true over time.** "Latest-wins, don't append" is a
  discipline everyone intends and nobody sustains, because deleting a row feels like destroying
  information — so the row gets kept "just for now", and the page becomes a log. Once history has a
  **named home**, deletion is a *move*, not a loss, and the discipline survives contact with a busy
  week. ⛔ Note the anti-pattern this standard names — the ORCHESTRATOR-BOARD banner-stack — **also
  started as good intentions**; it decayed for exactly this reason. A lane that cannot name where its
  history lives has not finished adopting this standard.

**Placement:** vault lanes keep `DASHBOARD.md` at the vault root beside `Landing.md`. **Repo lanes
(`mcp`, `cc-be`, `rp-fe`, …) keep it at the repo root**, same shape — the standard is about the
surface, not about being a vault. Link it from `Landing.md`/`README.md` so it is one click from the
pinned page.

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
