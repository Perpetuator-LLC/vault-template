---
type: landing
description: "Vault entry point — the map of {{VAULT_NAME}}. Pointers only; every area's canon lives in its own folder."
---

# 🧭 {{VAULT_NAME}} — Landing

<!-- The short way into this vault. Keep it to pointers: every area's canon lives in its own
     folder, and duplicating it here guarantees the copy goes stale. -->

## 🕒 Recently Edited

*Pin this page. This is the newest-first view of everything touched in the vault — per Nik's
standing directive (2026-08-23): **every vault gets a landing page, and the landing page carries a
recent-files Base sorted most-recently-edited first**, because "every time I open the vault I can
see the recent pages you edited, which is 99% of what I care to look at."*

```base
filters:
  and:
    - file.ext == "md"
    - '!file.folder.endsWith("Templates")'
formulas:
  last_modified: file.mtime.format("MM/DD HH:mm")
properties:
  file.folder:
    displayName: Folder
  formula.last_modified:
    displayName: Modified
views:
  - type: table
    name: Everything
    order:
      - file.name
      - formula.last_modified
      - file.folder
    sort:
      - property: file.mtime
        direction: DESC
    limit: 30
  - type: table
    name: Docs only (no journals/threads)
    filters:
      and:
        - '!file.path.contains("Journal")'
        - '!file.path.contains("Thread")'
    order:
      - file.name
      - formula.last_modified
      - file.folder
    sort:
      - property: file.mtime
        direction: DESC
    limit: 30
```

<!-- Keep BOTH views. "Everything" is the true recency answer; "Docs only" exists because
     nightly ingest engines write journal entries continuously and would otherwise flood the
     list. Reference implementation: notes-perpetuator/Landing.md. -->

## Start here

| If you want to… | Go to |
|---|---|
| _(add the vault's real entry points)_ | |

## Areas

<!-- One line per top-level folder: what it holds and what rule governs it. -->

## Vault mechanics

Git is an **automated backup channel** here: the `obsidian-git` plugin auto-commits and pushes
`main` on its own. Write notes freely; don't hand-commit them. Configuration changes
(`.obsidian/`, `scripts/`, `.gitea/`) ship like code — branch → PR.

Details: [CLAUDE.md](CLAUDE.md) · standard and rationale: [docs/VAULT-STANDARD.md](docs/VAULT-STANDARD.md)
