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

## Blocked

_(none)_

## Done

_(none)_
