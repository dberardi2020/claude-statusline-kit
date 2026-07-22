# Concepts

The whole kit is five words. Learn these and you understand it.

## Segment

A **segment** is one field on the statusline — an emoji label plus a value, separated from
its neighbours by a white `|`. There are nine, across two lines:

| # | Segment | Shows | Source field(s) |
|---|---|---|---|
| 1 | 🤖 **Model** | The model line you're on | `model.display_name` |
| 2·3 | **Context** | A 10-cell fill bar and percent | `context_window.used_percentage` |
| 4 | ⏳ **5-hour limit** | Countdown to reset, and usage % | `rate_limits.five_hour.*` |
| 5 | 📅 **7-day limit** | Countdown to reset, and usage % | `rate_limits.seven_day.*` |
| 6 | 📁 **Directory** | The leaf of the working directory | `workspace.current_dir`, else `cwd` |
| 7 | 🌿 **Branch** | Current git branch | `.git/HEAD`, walked up from the cwd |
| 8 | 💰 **Cost** | Session cost so far | `cost.total_cost_usd` |
| 9 | ⏱️ **Elapsed** | Wall-clock time in session | `cost.total_duration_ms` |

Each segment is computed **independently** of every other, from one or two fields of the
session JSON. Nothing is derived from anything else on the line.

The load-bearing property: a segment whose source field is missing **drops out entirely**
rather than rendering a zero. A payload with no `rate_limits` produces a shorter line 1 —
not a misleading `⏳ [0h0m] 0%`. This is what lets one script span Claude Code versions and
payload shapes without sniffing for a version.

## Line

The output is **two lines, each followed by a rule** — a 71-character run of `─`:

```
| 🤖 [Opus 4.8] | ▓▓▓▓░░░░░░ 42% | ⏳ [2h0m] 15% | 📅 [3d11h] 50% |
───────────────────────────────────────────────────────────────────────
| 📁 Home | 🌿 master | 💰 $2.10 | ⏱️ 1h30m |
───────────────────────────────────────────────────────────────────────
```

The split is by **volatility**:

- **Line 1 is variable-length** — session state that moves. The model is always there;
  context and the two rate-limit windows appear as the data for them does. On a brand-new
  session, before any message has gone through, line 1 may be just the model.
- **Line 2 is fixed** — four segments, always. Where you are and what it's cost.

## Coloring

Color carries meaning, and there are exactly **two schemes** — deliberately inverse to each
other:

| Scheme | Applies to | Rule |
|---|---|---|
| **Usage** | Context fill %, both rate-limit percentages | green ≤60 · yellow ≤85 · red >85 |
| **Time left** | The two rate-limit countdowns | >60% of the window left → **red** · 20–60% → **yellow** · <20% → **green** |

The inversion is the point, and it's the part that surprises people first. A rate-limit
window that just reset has *lots* of time left and *low* usage. The percentage reads
green — you've barely used it. But the countdown reads red, because if you *do* hit the
limit, you're a long way from relief.

So on a fresh 5-hour window you see `⏳ [4h50m] 3%` with a **red countdown and a green
percent**, and that's correct: plenty of budget, long time until reset. As the window burns
down the countdown cools to green while the percentage heats toward red. The two halves of
the segment answer different questions.

Everything else — the labels, the pipes, the rules, and the ⏱️ elapsed timer — stays
**white**. Any color on the line is a signal.

## Mode

Each script has **two modes in one file**:

| Mode | Invoked by | Does |
|---|---|---|
| **Render** | Claude Code, once per render, with session JSON on stdin | Prints the two lines and exits. The default. |
| **Install** | You, once: `--install` (bash) / `-Install` (PowerShell) | Copies the script into `~/.claude/` and merges a `statusLine` entry into `~/.claude/settings.json`, backing it up first. |

One file doing both is why setup is *one download and one command* — there's nothing to
clone, and no separate installer to trust.

The install path is deliberately careful: it **backs up** `settings.json` before touching
it, **merges** rather than overwrites so your other keys survive, **announces** rather than
silently replaces an existing `statusLine` from some other tool, and **aborts** without
writing if your settings file isn't valid JSON.

## Parity

The kit maintains **two implementations of one specification**:

| Script | Shell | Platform |
|---|---|---|
| `statusline-command.sh` | bash (3.2-safe) | macOS / Linux |
| `statusline.ps1` | PowerShell (5.1-safe) | Windows |

They are not ports that drifted apart. They're held in behavioral lockstep by **golden
tests**: a set of fixture payloads, a set of expected output files, and two runners that
feed the fixtures through their own script and compare against the **same** goldens. A green
run on both platforms *is* the proof of parity.

**Bash is the reference implementation** — the goldens are generated from it, and every
parity bug found so far has been PowerShell drifting from a correct bash. Countdowns would
make the output non-deterministic, so both scripts read "now" from an `SL_NOW` environment
variable when it's set; it's unset in normal use and exists purely for the tests.

Why two scripts rather than one shared runtime is recorded in
[ADR 0001](../decisions/0001-two-native-shell-scripts-over-node.md) — the short version is
that a Node implementation would assume `node` on `PATH`, and Claude Code's native-binary
installer doesn't put one there.

## The degradation principle

Underneath all five: **every field read is guarded**. A missing key, a null, or an
unexpected shape degrades its segment — to a default, or out of the line entirely — and
never raises.

The statusline sits in your terminal chrome on *every* render. A crash there is far worse
than a missing field: it's noisy, it's constant, and it looks like Claude Code itself is
broken. So the kit never asserts on the payload shape — it reads what it recognizes and
ignores the rest.

---

*This is the single source for the concept model. Field-by-field detail:
[technical/rendering.md](../technical/rendering.md). The decisions behind it:
[`decisions/`](../decisions/README.md).*
