# Data Model & Config

Everything the kit reads and writes: the session JSON Claude Code hands it, the
`settings.json` it edits at install time, and the one environment variable that exists for
tests.

## The session JSON contract

Claude Code invokes the configured `statusLine.command` once per render and pipes a JSON
object describing the session to **stdin**. That object is the kit's only input, and the kit
never asks Claude Code for anything else.

### Fields consumed

| Field | Type | Used for | Missing → |
|---|---|---|---|
| `model.display_name` | string | 🤖 Model segment | `?` |
| `context_window.used_percentage` | number | Context bar + percent | **segment dropped** |
| `rate_limits.five_hour.resets_at` | number (unix seconds) | ⏳ countdown | **segment dropped** |
| `rate_limits.five_hour.used_percentage` | number | ⏳ percent | percent omitted¹ |
| `rate_limits.seven_day.resets_at` | number (unix seconds) | 📅 countdown | **segment dropped** |
| `rate_limits.seven_day.used_percentage` | number | 📅 percent | percent omitted¹ |
| `workspace.current_dir` | string | 📁 directory, 🌿 branch walk | falls back to `cwd` |
| `cwd` | string | 📁 directory, 🌿 branch walk | placeholder² |
| `cost.total_cost_usd` | number | 💰 cost | `$0.00` |
| `cost.total_duration_ms` | number | ⏱️ elapsed | `0m` |

¹ In bash. PowerShell drops the whole segment instead — a known divergence, see
[Implementations](implementations.md#1--rate-limit-segment-drop-condition).
² `—` in bash, `---` in PowerShell — also a known divergence.

Every other key in the payload is **ignored**. The kit reads what it recognizes and never
validates the shape, so a Claude Code release adding fields is a non-event.

### A representative payload

```json
{
  "model": { "display_name": "Opus 4.8 (1M context)" },
  "workspace": { "current_dir": "/work/Home" },
  "context_window": { "used_percentage": 42 },
  "rate_limits": {
    "five_hour": { "resets_at": 1700007200, "used_percentage": 15 },
    "seven_day": { "resets_at": 1700300000, "used_percentage": 50 }
  },
  "cost": { "total_cost_usd": 2.1, "total_duration_ms": 5400000 }
}
```

And the minimum the kit tolerates — this renders fine, with a one-segment line 1:

```json
{ "model": { "display_name": "Sonnet 5 (1M context)" }, "cwd": "/work/solo" }
```

### The guard rule

**No read of this payload may raise.** Not a missing key, not a null, not a wrong type, not
an empty object. The statusline runs on *every* Claude Code render inside the user's
terminal chrome; a crash there is constant, noisy, and reads as Claude Code being broken —
strictly worse than a missing field.

Each implementation has exactly one guard idiom, applied uniformly:

| | Idiom | How |
|---|---|---|
| **bash** | `jq //` + `is_set` | The `//` operator supplies a default inside the single `jq` expression; `is_set` then tests for empty-or-`null` before a segment is built. |
| **PowerShell** | `Get-Safe` | Walks a path array inside a `try`, returning `$default` on any failure or null. |

```sh
(.workspace.current_dir // .cwd // "")          # bash: fallback chain, inline default
```
```powershell
Get-Safe $data @("workspace","current_dir") ""  # PowerShell: guarded path walk
```

The parse is a **seam**: all nine fields are reduced to scalars with defaults already
applied, in one place. No segment code below that point ever touches the JSON, so a payload
change is a one-line fix rather than a hunt.

### Two absences that mean different things

Worth being precise about, because it drives the drop-don't-zero rule:

- **Field absent** — Claude Code didn't supply it. Common and expected: `context_window` and
  `rate_limits` are omitted entirely until a session has usage, which is why line 1 is short
  on a brand-new session (**CSK-0011**).
- **Field present and zero** — genuinely zero. `0%` context used, `$0.00` spent.

Rendering `⏳ [0h0m] 0%` for the first case would be actively misleading, and the two are
indistinguishable once a default has been substituted. So segments **drop** rather than
zero.

## Config: `~/.claude/settings.json`

The kit's install mode is the only thing that writes to disk, and this is the file. It's
Claude Code's own settings file, shared with every other setting the user has — which is why
the installer **merges** rather than writes.

### The key the kit owns

```json
{
  "statusLine": {
    "type": "command",
    "command": "/Users/you/.claude/statusline-command.sh"
  }
}
```

| Field | Value |
|---|---|
| `type` | Always `"command"` |
| `command` | Absolute path to the installed script (bash), or a full PowerShell invocation (Windows) |

On Windows the command is a wrapper rather than a bare path:

```
pwsh -NoProfile -ExecutionPolicy Bypass -File "C:\Users\you\.claude\statusline.ps1"
```

with `powershell` substituted for `pwsh` when installing under Windows PowerShell 5.1.

`statusLine` is the **only** key the kit reads or writes. Everything else in the file is
preserved untouched — the merge behaviour and its failure modes are specified in
[Install & Distribution](install-and-distribution.md).

### Installed artifacts

| Path | What |
|---|---|
| `~/.claude/statusline-command.sh` | The installed bash script |
| `~/.claude/statusline.ps1` | The installed PowerShell script |
| `~/.claude/settings.json` | Claude Code's settings, with `statusLine` merged in |
| `~/.claude/settings.json.bak-<YYYYMMDDHHMMSS>` | A backup, written on **every** install run |

Backups accumulate — one per install — and are never cleaned up, including on a pure refresh
that changes nothing (**CSK-0009**). That's deliberate for now (a lost setting is worse than a
stray file), and a proper `uninstall` is tracked as **CSK-0001**.

## The `SL_NOW` seam

The single environment variable the kit reads, and the only nondeterminism in the program:

| | |
|---|---|
| **Set** | Both scripts use its value as "now" (unix seconds) for the rate-limit countdowns. |
| **Unset** | Both use the real clock. |
| **In normal use** | Unset. Zero runtime effect. |

Countdowns are `resets_at − now`, which would make output non-reproducible and the golden
tests impossible. Isolating the clock to one variable makes the render a **pure function of
(stdin JSON, `SL_NOW`, filesystem)** — which is exactly what the test suite depends on. The
test value is `1700000000`.

The one remaining input that *isn't* pinned is the filesystem: the 🌿 branch segment walks
up from the working directory looking for `.git/HEAD`. The fixtures all point at non-repo
paths so the goldens bake in `🌿 ---`, which keeps them stable but means branch detection
has no coverage at all (**CSK-0007**).

See [Testing](testing.md#the-clock-seam).
