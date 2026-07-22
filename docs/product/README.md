# Claude Code Statusline Kit — Product docs

Documentation for **anyone** who wants to understand the Statusline Kit as a product —
what it shows, what it's for, and how to install and read it. No code knowledge assumed.

*(For how it's built, see the [Technical docs](../technical/README.md).)*

## Start here

| Doc | Read it for |
|---|---|
| [Overview](overview.md) | The pitch: what Claude Code leaves implicit, and what the statusline makes visible. |
| [Concepts](concepts.md) | The five words that make up the whole model — Segment, Line, Coloring, Mode, Parity. |
| [User Guide](user-guide.md) | Installing it, reading every segment, customizing, troubleshooting, and uninstalling. |
| [Platforms & Status](platforms-and-status.md) | What you need to run it, which platforms are verified, and what's unsupported or deferred. |

## In one sentence

> The Statusline Kit turns the session JSON Claude Code hands its `statusLine` command
> into **two color-coded lines** — model, context fill, and both rate-limit windows above;
> directory, branch, cost, and elapsed time below — from a **self-installing script** in
> your platform's native shell.

## What it looks like

```
| 🤖 [Opus 4.8] | ▓▓▓▓░░░░░░ 42% | ⏳ [2h0m] 15% | 📅 [3d11h] 50% |
───────────────────────────────────────────────────────────────────────
| 📁 Home | 🌿 master | 💰 $2.10 | ⏱️ 1h30m |
───────────────────────────────────────────────────────────────────────
```

## Deeper references

These product docs are the reader-facing suite. [`Concepts`](concepts.md) is the single
source for the concept model — nothing else restates it. For the primary material behind it:

- [`decisions/`](../decisions/README.md) — the Architecture Decision Records (*why* it's built this way).
