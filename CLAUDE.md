---
type: agent-instructions
description: "Always-resident operating instructions for the {{VAULT_NAME}} vault — the thin tripwire layer; procedures live in their own docs and load on demand."
---

# {{VAULT_NAME}} — Claude Instructions

This is the **thin, always-resident tripwire layer** for this vault: invariants an agent could
break before knowing to look them up. Everything procedural lives elsewhere and loads on demand.
This file is the vault-specific layer over the global governance baseline — on conflict, the more
specific rule here wins **for this vault**.

## What this repository is

An **Obsidian knowledge vault** — Markdown notes with wiki-links and frontmatter, not code.

## ⛔ The obsidian-git plugin owns `main` — do not commit vault content

Git here is an **automated backup channel**, not a review workflow. The `obsidian-git` plugin
auto-commits every ~5 min and pushes every ~15 min, directly to `main`.

| You are changing… | How |
|---|---|
| **Vault content** (notes) | Just write the files. The plugin commits and pushes them. **Do not `git commit`** — you will race the plugin and split one logical change across two commits. |
| **Vault configuration** (`.obsidian/`, `scripts/`, `.gitea/`, this file, `.gitignore`) | Config ships like code: branch → `merge/<agent>` → **one PR** for human review. |

A conflict from the plugin's auto-merge is repaired in the working tree, never with a force-push.

## Setup invariants (what the config guarantees)

- `.obsidian/` is **tracked** so a fresh clone — desktop *or* mobile — opens ready to use.
  Plugin binaries are vendored deliberately: mobile Obsidian cannot run a bootstrap script, and
  without `obsidian-git` already in the clone there is no way to sync the vault on a phone.
- **`plugins/*/data.json` is git-ignored** — plugin settings can hold API keys (Copilot's does).
  The single exception, `obsidian-git/data.json`, has no credential fields and its sync cadence
  must be versioned. `scripts/vault-check.sh` enforces both halves in CI; never un-ignore another
  one to "make a setting stick".
- Plugin/theme versions are **pinned** in `scripts/vault-plugins.sh`. Upgrade by editing the pin,
  running the script, and reviewing the diff — never by hand-copying a binary in.
- CI (`.gitea/workflows/vault-hygiene.yml`) is **report-only**. It must never commit: the plugin
  owns `main`. A red run means drift exists — fix locally, let the next backup push clear it.

## Writing in this vault

- **Route before create.** Find the existing canon and update it; a parallel file is the exception
  and needs a reason. Rich canons, thin pointers.
- **Markdown + frontmatter + `[[wiki-links]]`.** Never trap content in a format it can't leave.
- **History is append-only.** Correct an immutable record (journal, dated report, decision) by
  appending a dated update, never by rewriting it.
- **Secrets never enter the vault.** Not in a note, not in frontmatter, not in a code fence. Store
  path references only.
- Scratch that must not become canon goes in `.workspace/` (git-ignored).

## Vault structure

<!-- Replace with this vault's folder map. Aim for ≤8 top-level folders. -->

| Folder | Purpose |
|---|---|
| `Attachments/` | Binary attachments (Obsidian's configured attachment folder) |
