# User Guide

Getting the statusline installed, reading every segment, and fixing it when something looks
wrong.

## 1. Requirements

| Platform | Shell | Also needs |
|---|---|---|
| macOS / Linux | **bash** (3.2+, i.e. anything since 2007) | [`jq`](https://jqlang.github.io/jq/) — at install *and* at render time |
| Windows | **PowerShell** 5.1+ or PowerShell 7 | nothing — JSON parsing is built in |

Plus [Claude Code](https://claude.com/claude-code) itself, and a terminal that can render
UTF-8 emoji and ANSI color. Both ship with your OS; the only thing you may need to add is
`jq`:

```bash
brew install jq        # macOS
sudo apt install jq    # Debian / Ubuntu
```

## 2. Install

Each script is **self-installing** — download the one for your platform and run it with the
install flag. There's nothing to clone.

### macOS / Linux

```bash
curl -fsSLO https://raw.githubusercontent.com/dberardi2020/claude-statusline-kit/main/statusline-command.sh
bash statusline-command.sh --install
```

### Windows

```powershell
irm https://raw.githubusercontent.com/dberardi2020/claude-statusline-kit/main/statusline.ps1 -OutFile statusline.ps1
./statusline.ps1 -Install
```

Either way you should see:

```
✓ statusline installed → /Users/you/.claude/statusline-command.sh
✓ settings.json wired (backup: /Users/you/.claude/settings.json.bak-20260721143022)
  Restart Claude Code or open a new session to see it.
```

**Restart Claude Code** (or open a new session) and the line appears.

### What the installer actually did

1. Copied the script to `~/.claude/`.
2. Backed up `~/.claude/settings.json` to `settings.json.bak-<timestamp>`.
3. **Merged** — not overwrote — a `statusLine` entry into it, leaving every other key
   intact.

If you already had a *different* `statusLine` configured, it says so rather than silently
clobbering it, and prints both the old command and the backup path.

### Manual install

Prefer to wire it yourself? Copy the script into `~/.claude/` and add to
`~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline-command.sh"
  }
}
```

On Windows, point it at PowerShell instead:

```json
{
  "statusLine": {
    "type": "command",
    "command": "pwsh -NoProfile -ExecutionPolicy Bypass -File C:\\Users\\you\\.claude\\statusline.ps1"
  }
}
```

## 3. Reading the line

```
| 🤖 [Opus 4.8] | ▓▓▓▓░░░░░░ 42% | ⏳ [2h0m] 15% | 📅 [3d11h] 50% |
───────────────────────────────────────────────────────────────────────
| 📁 Home | 🌿 master | 💰 $2.10 | ⏱️ 1h30m |
───────────────────────────────────────────────────────────────────────
```

| Segment | Reads as | Notes |
|---|---|---|
| 🤖 `[Opus 4.8]` | The model this session is on | Any `(1M context)`-style annotation is stripped. |
| `▓▓▓▓░░░░░░ 42%` | Context window is 42% full | 10 cells, one per 10%. Colored by usage. |
| ⏳ `[2h0m] 15%` | 2 hours until the 5-hour window resets; 15% of it used | Countdown and percent are colored **independently** — see below. |
| 📅 `[3d11h] 50%` | 3 days 11 hours until the 7-day window resets; 50% used | Same. |
| 📁 `Home` | The **leaf** of the working directory | `/work/Home` shows as `Home`. |
| 🌿 `master` | Current git branch | `---` when you're not in a repo; a 7-char SHA on a detached HEAD. |
| 💰 `$2.10` | Session cost so far | Two decimal places. |
| ⏱️ `1h30m` | Wall-clock time in this session | The hour is dropped under 1h, e.g. `45m`. |

### The two colorings

This is the part worth internalizing, because the countdown color is **inverse** to what
you might first assume:

| What | Green | Yellow | Red |
|---|---|---|---|
| Any **percentage** | ≤60% used | ≤85% used | >85% used |
| A rate-limit **countdown** | <20% of window left | 20–60% left | >60% left |

So a freshly-reset 5-hour window shows `⏳ [4h50m] 3%` — a **red countdown next to a green
percent**. That's right, not a bug: you have plenty of budget (green), but if you *do* run
out you're nearly five hours from relief (red). As the window burns down, the countdown
cools to green while the percentage heats toward red.

Everything else on the line — labels, pipes, rules, and the ⏱️ timer — stays white, so any
color you see is telling you something.

### Segments that aren't there

Missing segments are **normal**, not broken. Each one drops out entirely when Claude Code
doesn't supply its data, rather than rendering a misleading zero. The most common case is
covered in troubleshooting below.

## 4. Verifying it works

You can render the statusline by hand without Claude Code — just pipe it a payload:

```bash
echo '{"model":{"display_name":"Opus 4.8"},"workspace":{"current_dir":"/tmp"},
"context_window":{"used_percentage":42},"cost":{"total_cost_usd":2.1,"total_duration_ms":5400000}}' \
  | bash ~/.claude/statusline-command.sh
```

```powershell
'{"model":{"display_name":"Opus 4.8"},"cwd":"C:\\tmp","context_window":{"used_percentage":42}}' `
  | pwsh -NoProfile -File $HOME\.claude\statusline.ps1
```

If that prints two colored lines, the script is fine and any problem is in the wiring.

## 5. Troubleshooting

### Line 1 is nearly empty on a fresh session

**Expected.** Right after a session starts you may see only `🤖 [Opus 4.8]` — no bar, no
⏳, no 📅. Claude Code omits `context_window` and `rate_limits` from the session JSON until
the session has actually used something, and the kit drops each segment whose field is
absent. Send one message and they appear. *(Tracked as **CSK-0011** — a dimmed placeholder
for the not-yet-known state is under consideration.)*

### Nothing appears at all

1. Restart Claude Code — the `statusLine` setting is read at startup.
2. Check the wiring: `cat ~/.claude/settings.json` should have a `statusLine` block whose
   `command` points at the script.
3. Check the script is executable: `ls -l ~/.claude/statusline-command.sh`.
4. Render it by hand (§4). If that works, the problem is the settings entry.

### `jq: command not found`

The bash implementation needs `jq` at render time, not just at install. Install it (§1).

### The line renders as mojibake / boxes

Your terminal isn't decoding UTF-8. On Windows this is usually the console codepage — the
statusline emits UTF-8 regardless of what the console expects. Modern Windows Terminal
handles it; an old `conhost` window may not.

### Colors look washed out or wrong

The kit uses palette-indexed ANSI colors (32/33/31), which each terminal maps to its own
RGB — so the same green is a different green in iTerm2, Windows Terminal, and Terminal.app.
Nothing is broken; the theme is doing it. *(Tracked as **CSK-0002** — a move to 24-bit
truecolor would pin the exact hues.)*

### The branch shows `---` inside a repo

The branch is found by walking up from the session's working directory looking for
`.git/HEAD`. If your repo uses a `.git` **file** rather than a directory (submodules,
worktrees), the walk won't find it.

### It hangs when I run the script directly

You ran it with no arguments and no piped input, so it's waiting on stdin. The bash script
prints usage instead in this case; PowerShell currently doesn't *(**CSK-0008**)*. Press
Ctrl-C.

## 6. Updating

Re-run the installer with a freshly downloaded script. It overwrites the copy in
`~/.claude/`, writes a new backup, and reports the re-install as a refresh rather than a
clash:

```
  (refreshed your existing Statusline Kit install)
```

*(A first-class `update` / `repair` / `uninstall` command family is tracked as **CSK-0001**.)*

## 7. Uninstalling

There's no uninstall flag yet. To remove it by hand:

1. Delete the `statusLine` block from `~/.claude/settings.json` — or restore one of the
   `settings.json.bak-*` files the installer left next to it.
2. Delete `~/.claude/statusline-command.sh` (or `statusline.ps1`).
3. Delete any `settings.json.bak-*` files you no longer want.
4. Restart Claude Code.

## Next

- The model behind the segments → [Concepts](concepts.md).
- What's verified on which platform → [Platforms & Status](platforms-and-status.md).
- How each segment is computed → [technical/rendering.md](../technical/rendering.md).
