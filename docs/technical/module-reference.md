# Module Reference

Every file in the repo: what it's responsible for, how it's structured, and the functions
worth knowing. Line numbers are indicative — treat structure as authoritative, not offsets.

For the behavioral spec these implement, see [Rendering](rendering.md).

## The scripts

### `statusline-command.sh`

**bash 3.2-safe, macOS/Linux. The reference implementation.** ~227 lines, top-to-bottom, no
functions except three small helpers.

| Section | Does |
|---|---|
| **Install-mode block** | An `if` on `$1` matching `--install` / `install` / `--setup`. Self-resolves via `${BASH_SOURCE[0]}`, hard-checks `jq`, copies itself, backs up and merges `settings.json`, reports, `exit 0`. Entirely self-contained — the render path below never runs in this mode. See [Install & Distribution](install-and-distribution.md). |
| **Bare-invocation guard** | `[ -t 0 ] && [ "$#" -eq 0 ]` — a human ran it by hand with no pipe, so print usage instead of blocking on `cat`. |
| **Parse** | One `jq -r` emitting nine values one per line, read back through nine `IFS= read -r` inside a `{ … } < <(…)` process substitution. Piped through `tr -d '\r'`. |
| **Colors & helpers** | The SGR constants and the three helper functions below. |
| **Line 1 segments** | Model, context bar, 5-hour, 7-day — each guarded, each producing a string that's empty when its source is absent. |
| **Line 2 segments** | Directory, branch, cost, elapsed. |
| **Render** | Builds the rule, appends non-empty segments to line 1, emits everything in one `printf`. |

Key functions:

| Function | Signature | Does |
|---|---|---|
| `color_for_pct` | `(pct)` → SGR | Usage coloring: green ≤60, yellow ≤85, else red. |
| `color_for_countdown` | `(seconds, window)` → SGR | Time-left coloring: `rem = 100·s/win`; >60 red, ≥20 yellow, else green. Returns white if `window ≤ 0`. |
| `is_set` | `(value)` → status | True when non-empty **and** not the literal `null`. The guard behind every droppable segment. |

Bash-3.2 constraints in force: no associative arrays, no `mapfile`, no `${var^^}`. The bar
is built with a `while` loop rather than string multiplication for the same reason.

### `statusline.ps1`

**PowerShell 5.1-safe, Windows.** ~222 lines, same top-to-bottom shape.

> ⚠️ **This file carries a UTF-8 BOM on line 1 and must keep it.** Without it PS 5.1 decodes
> the file as Windows-1252, mangles the astral-plane emoji, and fails to parse.

| Section | Does |
|---|---|
| **`param(...)` + install block** | `[switch]$Install, [switch]$Setup`. Self-resolves via `$PSCommandPath`, copies itself, backs up and merges `settings.json` via `ConvertFrom-Json`/`ConvertTo-Json`, registers a `pwsh`/`powershell` wrapper command, `exit 0`. |
| **Input** | Pins `[Console]::OutputEncoding` to UTF-8, then `[Console]::In.ReadToEnd()` piped to `ConvertFrom-Json`. No bare-invocation guard (**CSK-0008**). |
| **Constants** | Bar characters, SGR codes, and the emoji built via `ConvertFromUtf32`. |
| **Line 1 / Line 2** | Segments appended to `$parts` and `$line2` arrays, `-join`ed at the end. |
| **Render** | Four `Write-Host` calls: line 1, rule, line 2, rule. |

Key functions:

| Function | Signature | Does |
|---|---|---|
| `Get-Safe` | `(obj, string[] path, default)` → value | Walks a property path inside a `try`, returning `default` on null or any failure. The universal guard — every payload read goes through it. |
| `Get-CountdownColor` | `(int s, int win)` → SGR | The time-left coloring. Mirror of bash's `color_for_countdown`. |

Usage coloring is **inline ternaries** rather than a function — the one place the two
implementations differ in factoring without differing in behavior.

The emoji constants are the notable block:

```powershell
$e_robot  = [char]::ConvertFromUtf32(0x1F916)   # 🤖  astral — must be constructed
$e_clock  = [char]0x23F3                        # ⏳  BMP — safe as a char
$e_timer  = "$([char]0x23F1)$([char]0xFE0F)"    # ⏱️  BMP + variation selector
```

## Tests

See [Testing](testing.md) for the approach; this is the file inventory.

| File | Responsibility |
|---|---|
| `tests/fixtures/*.json` | Eight session payloads: `typical`, the three threshold cases (`green`/`yellow`/`red`), `no-ratelimits`, `past-reset` (must clamp to 0), `minimal` (exercises defaults and drops), `countdown-red` (early window — low usage, hot countdown; proves the two colorings are independent). |
| `tests/golden/*.txt` | Expected output, one per fixture. **Generated from bash**, the reference implementation. The parity seam. |
| `tests/run.sh` | Feeds each fixture to the bash script with `SL_NOW` pinned, diffs against the golden. Strips ANSI for readable failure output. |
| `tests/run.ps1` | Same, for PowerShell, against the **same** goldens. Pins `[Console]::OutputEncoding` **and** `$OutputEncoding` to BOM-less UTF-8 in a `try`/`finally` — see [Testing](testing.md#platform-notes). |
| `tests/install.sh` | Install-mode tests against throwaway `HOME` directories. 8 assertions; one is skipped on Git Bash. |
| `tests/README.md` | How to run each suite and regenerate goldens. |

Both runners normalize `\r` and trailing newlines before comparing, which is why the
trailing-newline difference between the implementations is outside the spec.

## Repo files

| File | Responsibility |
|---|---|
| `README.md` | The user-facing quickstart: install, segment reference, behavior, roadmap. |
| `llms.txt` | Machine-readable summary so a coding agent can install the kit without reading the README. |
| `.github/workflows/tests.yml` | CI. `bash` job on `ubuntu-latest` (render + install); `powershell` job on `windows-latest` running the render goldens under **both** PS 7 and PS 5.1, each behind `chcp 437`. |
| `.gitattributes` | Pins `eol=lf`. A Windows checkout rewriting line endings would corrupt the bash script and break every golden comparison. |
| `LICENSE` | MIT. |

## Docs

| File | Responsibility |
|---|---|
| `docs/render.py` | Stdlib-only Markdown → styled HTML renderer. Handles the Markdown subset the docs use; `convert()` extracts the `<title>` from the first H1. Identical across repos apart from the brand palette. |
| `docs/statusline.html` | The styled one-page reference — hand-maintained, not generated from a `.md`. Carries the same content as the README. |
| `docs/statusline-example.svg` | The statusline screenshot used in the README. |

Everything else under `docs/` is prose — `product/`, `technical/`, `decisions/`,
`tickets/` — each `.md` paired with a generated `.html`.
