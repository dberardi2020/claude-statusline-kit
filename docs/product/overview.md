# Product Overview

## What it is

A two-line statusline for [Claude Code](https://claude.com/claude-code) that surfaces the
live state of your session in the terminal chrome — the model, how full the context window
is, how close each rate-limit window is to resetting, and the working directory, git branch,
session cost, and elapsed time.

```
| 🤖 [Opus 4.8] | ▓▓▓▓░░░░░░ 42% | ⏳ [2h0m] 15% | 📅 [3d11h] 50% |
───────────────────────────────────────────────────────────────────────
| 📁 Home | 🌿 master | 💰 $2.10 | ⏱️ 1h30m |
───────────────────────────────────────────────────────────────────────
```

## Who it's for

Claude Code users on **macOS, Linux, or Windows** who want ambient awareness of a session
without switching windows or running commands — especially anyone who works long sessions and
wants to see a context compaction or a rate-limit reset coming.

## The problem it solves

Claude Code leaves several things implicit: which model line you're on, how much context
headroom is left before a compaction, how close you are to the 5-hour and 7-day rate-limit
resets, and what the session has cost so far. This statusline makes all of it continuously
visible, color-coded so a glance is enough.

## What you see

Two lines, bracketed by rules:

- **Line 1** — 🤖 model · context-fill bar and percent · ⏳ 5-hour rate-limit window ·
  📅 7-day rate-limit window.
- **Line 2** — 📁 directory · 🌿 git branch · 💰 session cost · ⏱️ elapsed time.

Percentages are color-coded: **green ≤60 · yellow ≤85 · red >85**. The rate-limit countdowns
are color-coded by how much of the window is left (**>60% left → red · 20–60% → yellow · <20% →
green**), inverse to the percentage; the session-elapsed time and all labels stay white. Full
field-by-field detail is in [technical/design.md](../technical/design.md).

## Design principles

- **Ambient, not noisy** — everything readable in one glance; no color unless it means
  something.
- **Degrade gracefully** — a missing field drops its segment instead of erroring, so the
  line is robust across Claude Code versions and payload shapes.
- **Zero-config after install** — the installer wires it in and backs up your settings; there
  is nothing else to tune.
- **Cross-platform parity** — the bash and PowerShell implementations produce the same
  layout from the same data.
