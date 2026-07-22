# Rendering

**This document is the specification.** Both implementations must satisfy it byte-for-byte;
where they disagree, one of them has a bug. `statusline-command.sh` is the reference — the
goldens are generated from it — so a discrepancy is resolved in bash's favour unless bash is
demonstrably wrong.

For *how* each implementation realizes this, see [Implementations](implementations.md). For
where the input comes from, see [Data Model & Config](data-model-and-config.md).

## The layout

Four lines of output, in this order:

```
| 🤖 [Opus 4.8] | ▓▓▓▓░░░░░░ 42% | ⏳ [2h0m] 15% | 📅 [3d11h] 50% |
───────────────────────────────────────────────────────────────────────
| 📁 Home | 🌿 master | 💰 $2.10 | ⏱️ 1h30m |
───────────────────────────────────────────────────────────────────────
```

| Element | Spec |
|---|---|
| **Rule** | Exactly **71** × `─` (U+2500), white, emitted after each line. |
| **Delimiter** | `\|` (U+007C) in white, with **one space** on each side. |
| **Line boundaries** | Every line opens and closes with a delimiter, so each is fully bracketed. |
| **Line 1** | Variable-length. Model always; then context, 5-hour, and 7-day segments, each appended **only if non-empty**. |
| **Line 2** | Fixed. Always exactly four segments — every source has a default. |
| **Trailing newline** | **Unspecified.** bash emits none (a single `printf` with no final `\n`); PowerShell emits one (`Write-Host`). Both test runners `TrimEnd` before comparing, so this is deliberately outside the contract. |

The variable/fixed split is by volatility: line 1 is session state that moves and may not
exist yet, line 2 is context that always resolves.

## The color model

ANSI SGR codes, palette-indexed:

| Role | Code | Applied to |
|---|---|---|
| Green | `\033[32m` | Usage ≤60% · countdown with <20% of window left |
| Yellow | `\033[33m` | Usage ≤85% · countdown with 20–60% left |
| Red | `\033[31m` | Usage >85% · countdown with >60% left |
| White | `\033[97m` | Delimiters, rules, all labels, and every line-2 value |
| Reset | `\033[0m` | After every colored run |

There are exactly **two coloring functions**, and they are inverse to each other:

### Usage coloring

```
pct ≤ 60  → green
pct ≤ 85  → yellow
otherwise → red
```

Applied to: the context bar (bar and percent together), the 5-hour percentage, the 7-day
percentage.

### Countdown coloring

```
rem = floor(100 × seconds_remaining / window_seconds)

rem > 60  → red
rem ≥ 20  → yellow
otherwise → green

window ≤ 0 → white   (defensive; unreachable with the fixed windows below)
```

Applied to: the 5-hour countdown (`window = 18000`) and the 7-day countdown
(`window = 604800`).

The inversion is intentional. A just-reset window has low usage (green percent) but a long
wait if you *do* hit the limit (red countdown). The two halves of a rate-limit segment
answer different questions and are colored independently — `⏳ [4h50m] 3%` renders a red
countdown beside a green percent, and that is correct output.

Everything not covered by these two rules is **white**. Notably the ⏱️ elapsed timer is
white, not colored — it's information, not a signal.

## Segment specifications

### 1 · 🤖 Model

| | |
|---|---|
| **Source** | `model.display_name`, defaulting to `?` |
| **Transform** | Strip every parenthetical group and surrounding whitespace (`(1M context)` → nothing), then trim |
| **Output** | `🤖 ` + white + `[` + name + `]` + reset |
| **Drops?** | Never — always present, defaulted |

`Opus 4.8 (1M context)` → `🤖 [Opus 4.8]`

### 2·3 · Context bar and percent

| | |
|---|---|
| **Source** | `context_window.used_percentage` |
| **Percent** | Round to nearest integer, **half-to-even** (C `printf %.0f` semantics); clamp to ≥ 0 |
| **Fill** | `filled = floor((pct + 5) / 10)` — **round half up**, deliberately *not* the same rounding as the percent; clamp to 0–10 |
| **Bar** | `▓` (U+2593) × filled, then `░` (U+2591) × (10 − filled) |
| **Color** | Usage coloring, from the percent; **bar and percent share one color run** |
| **Output** | color + bar + ` ` + pct + `%` + reset |
| **Drops?** | **Yes** — the whole segment when the field is absent |

The two roundings differ on purpose: the percent is what C's `printf` gives, and the bar
uses integer `(p+5)/10` so a displayed 45% fills five cells rather than four. Matching them
would change the displayed percent.

`42` → `▓▓▓▓░░░░░░ 42%` in green.

### 4 · ⏳ 5-hour rate limit

| | |
|---|---|
| **Source** | `rate_limits.five_hour.resets_at` (unix seconds) and `.used_percentage` |
| **Remaining** | `s = max(0, resets_at − now)` — a past reset clamps to 0, never negative |
| **Split** | `h = floor(s / 3600)`, `m = floor((s % 3600) / 60)` |
| **Countdown** | `⏳ ` + countdown-color(`s`, 18000) + `[{h}h{m}m]` + reset |
| **Percent** | ` ` + usage-color(pct) + `{pct}%` + reset, appended **only if** the percentage is present |
| **Drops?** | **Yes** — the whole segment when `resets_at` is absent |

Note there is **no zero-padding and no space** inside the bracket: `[2h0m]`, not `[2h 00m]`.

### 5 · 📅 7-day rate limit

Identical to the 5-hour segment except:

| | |
|---|---|
| **Source** | `rate_limits.seven_day.*` |
| **Split** | `d = floor(s / 86400)`, `h = floor((s % 86400) / 3600)` |
| **Format** | `📅 [{d}d{h}h]` |
| **Window** | `604800` |

### 6 · 📁 Directory

| | |
|---|---|
| **Source** | `workspace.current_dir`, falling back to `cwd` |
| **Transform** | The **leaf** only — `/work/Home` → `Home` |
| **Output** | `📁 ` + white + leaf + reset |
| **Drops?** | Never — falls back to a placeholder |

### 7 · 🌿 Branch

Resolved from the **filesystem**, not the payload, and not by shelling out to `git`:

1. Start at the working directory from segment 6.
2. If `<dir>/.git/HEAD` exists as a file, read it and stop.
3. Otherwise move to the parent directory and repeat, stopping at the filesystem root.

Then interpret the contents of `HEAD`:

| `HEAD` contains | Renders as |
|---|---|
| `ref: refs/heads/<name>` | `<name>` — that prefix stripped |
| Anything else (detached HEAD) | The **first 7 characters** — a short SHA |
| No `HEAD` found anywhere up the walk | `---` |

Reading the file rather than running `git branch --show-current` is deliberate: it avoids a
`git`-on-`PATH` dependency, and `--show-current` prints nothing on a detached HEAD where
this spec requires a short SHA.

| | |
|---|---|
| **Output** | `🌿 ` + white + branch + reset |
| **Drops?** | Never — `---` when no repo |

### 8 · 💰 Cost

| | |
|---|---|
| **Source** | `cost.total_cost_usd`, defaulting to `0` |
| **Format** | Fixed **two** decimal places, prefixed `$` |
| **Output** | `💰 ` + white + `$` + amount + reset |
| **Drops?** | Never — `$0.00` |

### 9 · ⏱️ Elapsed

| | |
|---|---|
| **Source** | `cost.total_duration_ms`, defaulting to `0` |
| **Split** | `h = floor(ms / 3600000)`, `m = floor((ms % 3600000) / 60000)` |
| **Format** | `{h}h{m}m` when `h > 0`, otherwise `{m}m` |
| **Output** | `⏱️ ` + white + duration + reset — **white, not colored** |
| **Drops?** | Never — `0m` |

`5400000` → `1h30m`. `120000` → `2m`.

## Assembly

```
line1 = "| " + model
        + (context   ? " | " + context   : "")
        + (fiveHour  ? " | " + fiveHour  : "")
        + (sevenDay  ? " | " + sevenDay  : "")
        + " |"

line2 = "| " + dir + " | " + branch + " | " + cost + " | " + elapsed + " |"

output = line1 + "\n" + rule + "\n" + line2 + "\n" + rule
```

An absent segment shortens line 1 rather than leaving a gap or a doubled delimiter. On a
brand-new session, before Claude Code has populated `context_window` or `rate_limits`, line
1 is legitimately just `| 🤖 [Opus 4.8] |`.

## Character inventory

Everything non-ASCII the renderer can emit. All must survive as UTF-8 to the terminal.

| Char | Code point | Use | BMP? |
|---|---|---|---|
| `▓` | U+2593 | Bar, filled cell | ✅ |
| `░` | U+2591 | Bar, empty cell | ✅ |
| `─` | U+2500 | Rule | ✅ |
| `⏳` | U+23F3 | 5-hour label | ✅ |
| `⏱️` | U+23F1 U+FE0F | Elapsed label (with variation selector) | ✅ |
| `🤖` | U+1F916 | Model label | ❌ astral |
| `📅` | U+1F4C5 | 7-day label | ❌ astral |
| `📁` | U+1F4C1 | Directory label | ❌ astral |
| `🌿` | U+1F33F | Branch label | ❌ astral |
| `💰` | U+1F4B0 | Cost label | ❌ astral |

The five astral-plane characters are why `statusline.ps1` builds its emoji with
`[char]::ConvertFromUtf32` rather than using literals, and why the file needs its UTF-8 BOM.
See [Implementations](implementations.md) and [Testing](testing.md#platform-notes).
