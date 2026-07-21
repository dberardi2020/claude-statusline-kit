# Claude Code Statusline Kit

A two-line [Claude Code](https://claude.com/claude-code) statusline — **model · context ·
rate-limits**, then **cwd · branch · cost · elapsed** — bracketed by rules. One statusline
in two shells: **bash** for macOS/Linux, **PowerShell** for Windows.

```
| 🤖 [Opus 4.8] | ▓▓▓▓░░░░░░ 42% | ⏳ [2h0m] 15% | 📅 [3d11h] 50% |
───────────────────────────────────────────────────────────────────────
| 📁 Home | 🌿 master | 💰 $2.10 | ⏱️ 1h30m |
───────────────────────────────────────────────────────────────────────
```

It surfaces at a glance what Claude Code otherwise leaves implicit: which model you're on,
how full the context window is, how close each rate-limit window is to resetting, and the
session's directory, branch, and cost. Percentages are color-coded
(**green ≤60 · yellow ≤85 · red >85**); countdowns and labels stay white.

## Install

Claude Code streams a JSON blob to your statusline command on stdin. Both scripts read that
JSON and print the two lines above.

### macOS / Linux (bash)

Requires [`jq`](https://jqlang.github.io/jq/).

```bash
# 1. Copy the script into place and make it executable
cp statusline-command.sh ~/.claude/statusline-command.sh
chmod +x ~/.claude/statusline-command.sh
```

Then point `~/.claude/settings.json` at it:

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline-command.sh"
  }
}
```

### Windows (PowerShell)

PowerShell 5.1-safe (astral-plane emoji via `ConvertFromUtf32`).

```json
{
  "statusLine": {
    "type": "command",
    "command": "pwsh -NoProfile -File C:\\path\\to\\statusline.ps1"
  }
}
```

> Back up any existing statusline before overwriting.

## What each segment shows

| # | Segment | Source field(s) | Format & color |
|---|---------|-----------------|----------------|
| 1 | 🤖 Model | `model.display_name` | Bracketed name, `(1M context)` annotation stripped; white. |
| 2·3 | Context bar + % | `context_window.used_percentage` | 10-cell `▓`/`░` bar + percent. green ≤60 · yellow ≤85 · red >85. |
| 10 | ⏳ 5-hour limit | `rate_limits.five_hour.resets_at` · `.used_percentage` | `[Hh Mm] pct%` — bracketed countdown (white) then percent (colored). |
| 10 | 📅 7-day limit | `rate_limits.seven_day.resets_at` · `.used_percentage` | `[Dd Hh] pct%`. |
| L2 | 📁 Directory | `workspace.current_dir` / `cwd` | Leaf of the working directory; white. |
| L2 | 🌿 Branch | `.git/HEAD` of the cwd (walked up) | Current branch, or `---` when not a repo. |
| L2 | 💰 Cost | `cost.total_cost_usd` | Session cost, `$`F2. |
| L2 | ⏱️ Elapsed | `cost.total_duration_ms` | Wall-clock → `Hh Mm` (drops the hour under 1h). |

Line 1 is segments **1, 2, 3, 10** (model · context bar · context % · rate limits); line 2
is the fixed context row. `STYLE=B` means two pipe-delimited lines wrapped in `─`×71 rules.

## Behavior

- **Safe field access** — every value is read through a guarded helper (`Get-Safe` in
  PowerShell, `is_set` + `jq //` defaults in bash), so a missing key degrades the line
  instead of erroring.
- **Graceful segments** — when the rate-limit fields are absent, those segments drop out and
  line 1 is just model + context.
- **Rate-limit countdowns** — `resets_at` (unix seconds) minus now, floored at 0, split into
  d/h/m.
- **Cross-platform parity** — both implementations read the same JSON schema and produce the
  same `STYLE=B` layout.

The styled reference doc [`statusline.html`](statusline.html) carries the same content as
this README in a browsable form.

## Roadmap

Today the kit ships one style (`STYLE=B`) in two shells. Where it's headed:

- **A style catalogue** — additional layouts and segment sets beyond `STYLE=B`.
- **A builder / wizard** — pick segments and a style, generate the script. The scripts here
  are already stamped with their selections (`segments 1,2,3,10 · STYLE=B`) as the seed for
  that generator.

## License

[MIT](LICENSE) © Dimitri Berardi
