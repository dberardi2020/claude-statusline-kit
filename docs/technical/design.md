# Technical Design

## Input: the statusline JSON contract

Claude Code invokes the `statusLine` command once per render and pipes a JSON object
describing the session on **stdin**. The kit consumes these fields:

| Field | Used for |
|-------|----------|
| `model.display_name` | Model segment (the `(1M context)` annotation is stripped) |
| `context_window.used_percentage` | Context bar + percent |
| `rate_limits.five_hour.resets_at` · `.used_percentage` | 5-hour window countdown + percent |
| `rate_limits.seven_day.resets_at` · `.used_percentage` | 7-day window countdown + percent |
| `workspace.current_dir` (falls back to `cwd`) | Directory segment |
| `cost.total_cost_usd` | Cost segment |
| `cost.total_duration_ms` | Elapsed segment |

Every read is **guarded** — a missing or null field degrades its segment (or drops it)
rather than erroring. In bash this is `is_set` + `jq //` defaults; in PowerShell it is the
`Get-Safe` helper.

## Segment computation

- **Model** — regex-strip the parenthetical annotation, trim, bracket.
- **Context bar** — 10 cells; `filled = round(pct / 10)` (bash `(p+5)/10`), clamped 0–10;
  filled cells `▓`, empty `░`.
- **Rate-limit countdowns** — `resets_at` (unix seconds) minus now, floored at 0, split into
  days/hours/minutes; the 5-hour window shows `[Hh Mm]`, the 7-day window shows `[Dd Hh]`. The
  countdown is colored by the fraction of the window still remaining (`rem = 100·s/win`, with
  `win` = 18000s / 604800s): **>60% left → red, 20–60% → yellow, <20% → green** — deliberately
  inverse to the usage percentage.
- **Branch** — walk up from the cwd looking for `.git/HEAD`; a `ref: refs/heads/…` line
  yields the branch name, otherwise the first 7 chars (detached HEAD); `---` when no repo is
  found.
- **Cost** — `total_cost_usd` formatted to two decimals.
- **Elapsed** — `total_duration_ms` → `Hh Mm`, dropping the hour component under one hour.

## Rendering

Two pipe-delimited lines wrapped in `─`×71 rules. Colors are ANSI SGR codes; the percent
thresholds are **green ≤60 / yellow ≤85 / red >85**, applied to the context bar and each
rate-limit percent. The rate-limit countdowns get their own time-left coloring (see above);
the session-elapsed time, labels, and structural pipes stay white.

## Self-install

Running a script with `--install` (bash) or `-Install` (PowerShell) switches from render mode
to install mode:

1. Resolve the script's own path.
2. Ensure `~/.claude/` exists; copy the script in.
3. Back up `~/.claude/settings.json` to `settings.json.bak-<timestamp>`.
4. **Merge** a `statusLine` entry into the settings JSON — never overwrite the whole file, so
   existing keys are preserved. If the existing JSON is invalid, abort and leave it untouched
   (the backup remains) with a manual snippet printed. If a *different* `statusLine` is
   already configured, it is replaced but announced — the installer prints the previous
   command and the backup path rather than clobbering it silently; a re-install of the kit's
   own entry is reported as a refresh.
5. Detect whether Claude Code appears installed (`claude` on PATH, or a pre-existing
   `~/.claude`); if not, still write the config but print a note pointing at the install page.

The bash installer additionally hard-checks for `jq` (also required at render time). A run
with no arguments at an interactive TTY prints usage instead of blocking on stdin.

## Cross-platform parity

Two implementations are maintained in behavioral lockstep:

- `statusline-command.sh` — bash, **macOS/Linux**, written to stay bash 3.2-safe.
- `statusline.ps1` — PowerShell, **Windows**, PS 5.1-safe (astral-plane emoji built via
  `ConvertFromUtf32`).

Both read the same JSON contract and emit the same layout. The reason there are two scripts
rather than one shared runtime is recorded in
[decisions/0001-two-native-shell-scripts-over-node.md](../decisions/0001-two-native-shell-scripts-over-node.md),
and the parity is enforced by golden tests run on both platforms — see
[testing.md](testing.md). Note that `statusline.ps1` carries a **UTF-8 BOM** on its first
line; without it, Windows PowerShell 5.1 misparses the file. Do not strip it.
