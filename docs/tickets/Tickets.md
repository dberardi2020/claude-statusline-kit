# Claude Code Statusline Kit — Tickets

A lightweight backlog — persist and review open items without a ticketing system.
This `.md` is the source of truth; regenerate the styled render with
`python docs/render.py docs/tickets/Tickets.md`.

## In progress

_(none)_

## Open

| ID | Type | Pri | Area | Title |
|---|---|---|---|---|
| CSK-0001 | Feature | P2 | tooling | **Family of management skills/commands** — `install`, `update`, `reinstall`, `uninstall`, `repair`. Today setup is a single `--install` / `-Install` self-install; there's no first-class way to *update* an installed copy (pull + re-copy into `~/.claude`), *repair* a broken config (re-point `statusLine`, fix a mangled `settings.json`, restore from a `.bak`), or cleanly *uninstall* (remove the `statusLine` entry, the script, and backups). A discoverable family — Claude Code skills and/or CLI verbs — would cover the whole lifecycle. Mirrors Terminal Launcher **TLA-0020**. |
| CSK-0002 | Feature | P3 | ux | **Truecolor status colours** — green/yellow/red use palette-indexed ANSI (32/33/31), which each terminal maps to its own RGB, so the kit renders as different shades across terminals (notably muted on Windows Terminal's default theme) next to the pinned bright-white. Switch to 24-bit truecolor (`\033[38;2;R;G;Bm`) with the exact hues from `statusline.html` (green `#3f9d52`, yellow `#c79413`, red `#cf4a54`) so both terminals — and the HTML doc — match. Add a truecolor golden/fixture to keep parity. |
| CSK-0003 | Feature | P3 | tooling | **Builder / wizard** — pick segments and a layout, generate the script (the roadmap's catalogue + generator). The self-install path's safe `settings.json` merge is the seed to reuse. |
| CSK-0004 | Chore | P3 | tests | **Git-Bash + Windows-jq CI leg** — CI runs bash only on Linux, so the Windows-`jq.exe` CRLF path (guarded by the `tr -d '\r'` defensive strip) has no coverage. A render-only Git-Bash + Chocolatey-jq job would lock it. Tests an unsupported config (Windows users run `statusline.ps1`), so low priority. |
| CSK-0005 | Chore | P3 | tests | **No local macOS PowerShell coverage** — there's no `pwsh` on the Mac, so `run.ps1` is verified only in CI and on the PC. Either install PowerShell on the Mac for a local parity run, or accept CI as the source of truth for the PS leg. |
| CSK-0006 | Bug | P3 | compat | **`statusline-command.sh` hangs on a Windows path outside a repo** — the branch walk is `while [ -n "$git_dir" ] && [ "$git_dir" != "/" ]`, but on a Windows-style cwd `dirname` goes `C:/Users` → `C:` → `.` → `.` and never reaches `/`, so the loop never terminates (confirmed: `exit=124` under `timeout`, no output). Unix is unaffected — `dirname` there reaches `/` and the loop exits (verified against a POSIX path). Only reachable under Git Bash on Windows, the config the docs already declare unsupported (Windows users run `statusline.ps1`), hence P3. Fix would be a depth cap or a `[ "$git_dir" != "$parent" ]` guard on the walk. Same unsupported-config family as **CSK-0004**. |
| CSK-0007 | Chore | P2 | tests | **Branch-segment test coverage** — every render fixture's `cwd` points at a non-repo, so `🌿 ---` is baked into all goldens and the parity suite structurally cannot catch branch-detection divergence between the two scripts (which is exactly how a real bash-vs-PowerShell difference on a detached HEAD went unnoticed). A test needs a `.git/HEAD` matching the fixture's `cwd`, which doesn't fit the static-JSON golden model — likely a small dedicated test that builds a temp repo, rather than a golden. |
| CSK-0008 | Chore | P3 | ux | **PowerShell lacks bash's bare-invocation usage guard** — `statusline-command.sh` prints usage when run bare at a TTY (`[ -t 0 ] && [ "$#" -eq 0 ]`); `statusline.ps1` has no equivalent, so it falls straight to `[Console]::In.ReadToEnd()` and blocks on stdin. Confirmed by code inspection (not yet run at a real console — no `pwsh` on the Mac). `design.md` scopes the usage-guard note to bash, so it's not inaccurate, just an asymmetry. Mirror with `[Console]::IsInputRedirected`. |

## Blocked

_(none)_

## Done

_(none)_
