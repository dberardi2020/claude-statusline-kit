# Tickets

The backlog. Board-first: a lightweight tracker until a real one is warranted. IDs are `CSK-NNNN`, uppercase, never reused.

**What is *not* here:** the steps to *take the repo public* — secrets scan, private-content sweep, the flip. Those are a **pre-flight checklist run once when the project is ready**, kept as a separate release runbook, not backlog. This board tracks *building the product*.

Rows are pointers; anything needing more than a sentence has a block in **Details**, below the board.

## In progress

*(none)*

## On deck

*(none — nothing committed yet. The obvious candidate cluster is the parity trio: CSK-0012 and CSK-0013 decide the behaviour, then CSK-0014 encodes it in fixtures.)*

## Blocked

*(none)*

## Backlog

| ID | Pri | Type | Title |
|---|---|---|---|
| [CSK-0001](#csk-0001) | P2 | Feature | A family of management skills/commands — install / update / repair / uninstall |
| [CSK-0007](#csk-0007) | P2 | Chore | Branch-segment test coverage |
| [CSK-0011](#csk-0011) | P2 | Bug | Line 1 is nearly empty until the first message is sent |
| [CSK-0012](#csk-0012) | P2 | Bug | Rate-limit segment drop condition diverges between the two scripts |
| [CSK-0014](#csk-0014) | P2 | Chore | Fixtures never exercise partial rate-limit or absent-cwd payloads |
| [CSK-0002](#csk-0002) | P3 | Feature | Truecolor status colours |
| [CSK-0003](#csk-0003) | P3 | Feature | Builder / wizard — pick segments and a layout, generate the script |
| [CSK-0004](#csk-0004) | P3 | Chore | Git-Bash + Windows-jq CI leg |
| [CSK-0005](#csk-0005) | P3 | Chore | No local macOS PowerShell coverage |
| [CSK-0006](#csk-0006) | P3 | Bug | `statusline-command.sh` hangs on a Windows path outside a repo |
| [CSK-0008](#csk-0008) | P3 | Chore | PowerShell lacks bash's bare-invocation usage guard |
| [CSK-0009](#csk-0009) | P3 | Chore | Install writes an unbounded pile of `settings.json` backups |
| [CSK-0010](#csk-0010) | P3 | Chore | Move `docs/tickets/` to GitHub Projects |
| [CSK-0013](#csk-0013) | P3 | Bug | Empty-directory placeholder differs between the scripts |

## Done

*(none)*

## Details

### CSK-0001 — A family of management skills/commands {#csk-0001}
**P2 · Feature · tooling**

`install`, `update`, `reinstall`, `uninstall`, `repair`. Today setup is a single `--install` / `-Install` self-install; there's no first-class way to *update* an installed copy (pull + re-copy into `~/.claude`), *repair* a broken config (re-point `statusLine`, fix a mangled `settings.json`, restore from a `.bak`), or cleanly *uninstall* (remove the `statusLine` entry, the script, and backups). A discoverable family — Claude Code skills and/or CLI verbs — would cover the whole lifecycle. Mirrors Terminal Launcher **TLA-0020**.

### CSK-0002 — Truecolor status colours {#csk-0002}
**P3 · Feature · ux**

Green/yellow/red use palette-indexed ANSI (32/33/31), which each terminal maps to its own RGB, so the kit renders as different shades across terminals (notably muted on Windows Terminal's default theme) next to the pinned bright-white. Switch to 24-bit truecolor (`\033[38;2;R;G;Bm`) with the exact hues from `statusline.html` (green `#3f9d52`, yellow `#c79413`, red `#cf4a54`) so both terminals — and the HTML doc — match. Add a truecolor golden/fixture to keep parity.

### CSK-0003 — Builder / wizard {#csk-0003}
**P3 · Feature · tooling**

Pick segments and a layout, generate the script (the roadmap's catalogue + generator). The self-install path's safe `settings.json` merge is the seed to reuse.

### CSK-0004 — Git-Bash + Windows-jq CI leg {#csk-0004}
**P3 · Chore · tests**

CI runs bash only on Linux, so the Windows-`jq.exe` CRLF path (guarded by the `tr -d '\r'` defensive strip) has no coverage. A render-only Git-Bash + Chocolatey-jq job would lock it. Tests an unsupported config (Windows users run `statusline.ps1`), so low priority.

### CSK-0005 — No local macOS PowerShell coverage {#csk-0005}
**P3 · Chore · tests**

There's no `pwsh` on the Mac, so `run.ps1` is verified only in CI and on the PC. Either install PowerShell on the Mac for a local parity run, or accept CI as the source of truth for the PS leg. This is the reason several parity findings below are marked *by code inspection only*.

### CSK-0006 — `statusline-command.sh` hangs on a Windows path outside a repo {#csk-0006}
**P3 · Bug · compat**

The branch walk is `while [ -n "$git_dir" ] && [ "$git_dir" != "/" ]`, but on a Windows-style cwd `dirname` goes `C:/Users` → `C:` → `.` → `.` and never reaches `/`, so the loop never terminates (confirmed: `exit=124` under `timeout`, no output). Unix is unaffected — `dirname` there reaches `/` and the loop exits (verified against a POSIX path). Only reachable under Git Bash on Windows, the config the docs already declare unsupported (Windows users run `statusline.ps1`), hence P3. Fix would be a depth cap or a `[ "$git_dir" != "$parent" ]` guard on the walk. Same unsupported-config family as **CSK-0004**.

### CSK-0007 — Branch-segment test coverage {#csk-0007}
**P2 · Chore · tests**

Every render fixture's `cwd` points at a non-repo, so `🌿 ---` is baked into all goldens and the parity suite structurally cannot catch branch-detection divergence between the two scripts (which is exactly how a real bash-vs-PowerShell difference on a detached HEAD went unnoticed). A test needs a `.git/HEAD` matching the fixture's `cwd`, which doesn't fit the static-JSON golden model — likely a small dedicated test that builds a temp repo, rather than a golden.

### CSK-0008 — PowerShell lacks bash's bare-invocation usage guard {#csk-0008}
**P3 · Chore · ux**

`statusline-command.sh` prints usage when run bare at a TTY (`[ -t 0 ] && [ "$#" -eq 0 ]`); `statusline.ps1` has no equivalent, so it falls straight to `[Console]::In.ReadToEnd()` and blocks on stdin. Confirmed by code inspection (not yet run at a real console — no `pwsh` on the Mac). `implementations.md` scopes the usage-guard note to bash, so it's not inaccurate, just an asymmetry. Mirror with `[Console]::IsInputRedirected`.

### CSK-0009 — Install writes an unbounded pile of `settings.json` backups {#csk-0009}
**P3 · Chore · tooling**

Both installers unconditionally copy a `settings.json.bak-<timestamp>` on every run (`statusline-command.sh:35`, `statusline.ps1:25-26`), including when the run is a pure refresh that changes nothing. Nothing ever prunes them, so they accumulate one per install forever: a single day of iterating on this repo left **six** in `~/.claude`, five of them byte-identical, and they had to be cleared by hand. Options — skip the backup when the merged result is identical to the current file, keep only the N most recent, or write one `.bak` and rotate it. Distinct from **CSK-0001**, which covers *lifecycle verbs* (an `uninstall` that removes backups); this is the install path's backup policy itself, and would still matter with no new verbs at all.

### CSK-0010 — Move `docs/tickets/` to GitHub Projects {#csk-0010}
**P3 · Chore · tooling**

The flat `tickets.md` + generated `tickets.html` was a deliberate no-external-tracker start, but it has costs: IDs are assigned by hand (this file briefly had CSK-0009 out of order), the `.html` must be regenerated via `docs/render.py` on every edit, and there's no status/assignee/linking to issues or PRs. Migrate to a GitHub Project once the backlog justifies it — port CSK-0001…0014, keep the IDs in the issue titles for traceability, then retire `tickets.md`, `tickets.html` and (if nothing else uses it) `docs/render.py`, leaving a pointer in `docs/README.md`.

This is the repo that tracks the **house-wide** migration: the board format itself is documented as interim in `.meta/ticket-board-standard.md`, with GitHub Projects named as the destination.

### CSK-0011 — Line 1 is nearly empty until the first message is sent {#csk-0011}
**P2 · Bug · ux**

On a fresh session the statusline renders only `🤖 [model]`; the context bar, `⏳` 5-hour and `📅` 7-day segments are all missing, then appear once a message goes through. Cause is the input, not the render: Claude Code omits `.context_window` and `.rate_limits` from the session JSON until the session has usage, and `statusline-command.sh` (and `statusline.ps1`) drop each segment entirely when its field is unset (`is_set` guards at `statusline-command.sh:140,155,167`). Right after install that reads as a broken statusline. Either render a neutral placeholder for the not-yet-known state (e.g. dimmed `░░░░░░░░░░ --%` / `⏳ [--] --%`) or document it in the README/troubleshooting as expected first-run behaviour.

### CSK-0012 — Rate-limit segment drop condition diverges between the two scripts {#csk-0012}
**P2 · Bug · parity**

Bash renders the segment when **`resets_at`** alone is present and appends the percent only if *that* is also set (`statusline-command.sh:155,159`); PowerShell requires **both** `resets_at` **and** `used_percentage` and drops the whole segment otherwise (`statusline.ps1:137,148`). Given `{"rate_limits":{"five_hour":{"resets_at":…}}}` with no percentage, bash prints `| 🤖 [Opus 4.8] | ⏳ [2h0m] |` and PowerShell prints `| 🤖 [Opus 4.8] |`. Bash (the reference) matches `technical/rendering.md` as written. Verified by execution on bash; PowerShell **by code inspection only** — no `pwsh` on the Mac (**CSK-0005**). Invisible to the golden suite because no fixture supplies a reset without a percentage — see **CSK-0014**. Fix PowerShell to match bash, or change the spec and both scripts together.

### CSK-0013 — Empty-directory placeholder differs {#csk-0013}
**P3 · Bug · parity**

With a payload carrying neither `workspace.current_dir` nor `cwd`, bash renders `📁 —` (U+2014 em dash, `statusline-command.sh:182`) and PowerShell renders `📁 ---` (three hyphens, `statusline.ps1:166`). Note the 🌿 branch segment uses `---` in **both** scripts, so bash is the odd one out — but bash is also the reference implementation, so this needs a decision rather than a silent fix. Verified by execution on bash; PowerShell by inspection. Not covered by the goldens: every fixture has a cwd (**CSK-0014**). Low priority — an absent cwd is unlikely in a real Claude Code payload.

### CSK-0014 — Fixtures never exercise partial rate-limit or absent-cwd payloads {#csk-0014}
**P2 · Chore · tests**

Every `tests/fixtures/*.json` supplies `resets_at` and `used_percentage` **together or not at all**, and every fixture has a working directory. That is structurally why **CSK-0012** and **CSK-0013** were invisible to a suite whose whole job is catching bash-vs-PowerShell drift. Add two fixtures + goldens: one rate-limit window with `resets_at` but no `used_percentage`, and one payload with neither `workspace.current_dir` nor `cwd`. Same family as **CSK-0007** (branch coverage) — all three are gaps where the golden model can't see a divergence. Resolve **CSK-0012**/**CSK-0013** first, since the goldens encode whichever behaviour is chosen.

## Conventions

The house standard for this board's shape — lanes, schema, detail tiers, archiving — is
`.meta/ticket-board-standard.md` in the author's workspace. The essentials, so this file
stands alone:

- **Source of truth is this file.** Edit the tables directly, then regenerate the render:
  `python docs/render.py docs/tickets/tickets.md`. Commit both files together.
- **IDs** are `CSK-NNNN`, one sequence, assigned in creation order (not priority), never
  renumbered and never reused.
- **Lanes**, in order: In progress · On deck · Blocked · Backlog · Done. An empty lane keeps
  its heading and reads `*(none)*`.
- **Priority:** P1 (soon) → P2 (real, not next) → P3 (someday). **Type:** Bug · Feature ·
  Chore (housekeeping — tests, refactors, packaging, docs) · Idea (not yet scoped).
- **Rows are sorted by priority**, ties by ID — except **On deck**, which is in intended
  sequence, and **Done**, which is reverse-chronological.
- **Keep rows short — length is the signal.** A row is a pointer, one sentence. Anything
  longer gets a `### CSK-NNNN` block under **Details** (ID-ordered), which is also the only
  place the ticket's *area* appears. `Done` rows are exempt — there the row *is* the record.
- **A literal `|` in a cell spawns a phantom column** — the renderer splits rows naively.
  Use `/` inside cells.
