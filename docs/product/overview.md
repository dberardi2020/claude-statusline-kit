# Overview

## The problem

Claude Code leaves several things about your session implicit, and each of them is
something you end up wanting mid-task:

- **Which model line am I actually on?** You set it once and then forget, or a session
  starts on a different default than you assumed.
- **How much context headroom is left?** A compaction that arrives without warning
  interrupts a train of thought; one you can see coming, you can plan around — wrap up the
  current thread, or start a fresh session deliberately.
- **How close am I to a rate-limit reset?** Both the 5-hour and the 7-day window matter,
  and neither is visible until you hit it.
- **What has this session cost, and how long have I been at it?**

None of that is hard to find — but every route to it means switching windows or running a
command, which costs you the thing you were holding in your head.

## The solution

A **two-line statusline** in Claude Code's own terminal chrome that keeps all of it
continuously visible:

```
| 🤖 [Opus 4.8] | ▓▓▓▓░░░░░░ 42% | ⏳ [2h0m] 15% | 📅 [3d11h] 50% |
───────────────────────────────────────────────────────────────────────
| 📁 Home | 🌿 master | 💰 $2.10 | ⏱️ 1h30m |
───────────────────────────────────────────────────────────────────────
```

- **Line 1 — what's moving.** 🤖 model · a 10-cell context-fill bar and percent · ⏳ the
  5-hour rate-limit window · 📅 the 7-day window.
- **Line 2 — where you are.** 📁 directory · 🌿 git branch · 💰 session cost · ⏱️ elapsed
  time.

Color is the whole interface. Percentages run **green ≤60 · yellow ≤85 · red >85**. The
rate-limit countdowns use the *inverse* scheme — colored by how much of the window is still
left (**>60% left → red · 20–60% → yellow · <20% → green**) — so a window that's about to
reset reads calm and one you'll be waiting on reads hot. Everything else stays white, which
means any color on the line is telling you something.

## Install is one command

There's nothing to clone and no runtime to install. Download the one script for your
platform and run it with `--install`:

```bash
bash statusline-command.sh --install     # macOS / Linux
```
```powershell
./statusline.ps1 -Install                # Windows
```

It copies itself into `~/.claude/`, **backs up** your `settings.json`, and **merges** a
`statusLine` entry into it — preserving every other key you have. Restart Claude Code and
the line is there. See the [User Guide](user-guide.md).

## How it's built

Claude Code invokes your `statusLine` command once per render and pipes it a JSON blob
describing the session. The kit is that command: read the JSON, print two lines, exit. No
daemon, no state between renders.

It ships as **two native-shell implementations** — bash for macOS/Linux, PowerShell for
Windows — rather than one cross-platform script, because a single implementation would need
a runtime (Node) that Claude Code's native-binary installer doesn't put on your machine.
The two are held in lockstep by tests that compare both against the same expected output.
That reasoning is recorded in
[ADR 0001](../decisions/0001-two-native-shell-scripts-over-node.md).

## Who it's for

- Claude Code users on **macOS, Linux, or Windows** who want ambient session awareness
  without switching windows or running commands.
- Anyone who works **long sessions** and wants to see a context compaction or a rate-limit
  reset coming rather than hitting it.
- People who want cost and elapsed time visible **while** they work, not reconstructed
  afterwards.

## Design principles

- **Ambient, not noisy** — readable in one glance; no color unless it means something.
- **Degrade gracefully** — a missing field drops its segment instead of erroring, so the
  line survives Claude Code releases and payload changes.
- **Zero-config after install** — the installer wires it in and backs up your settings;
  there is nothing else to tune.
- **Cross-platform parity** — the bash and PowerShell implementations produce the same
  layout from the same data, enforced in CI.

## Next

- The vocabulary behind all of this → [Concepts](concepts.md).
- Installing it and reading every segment → [User Guide](user-guide.md).
- What's verified where → [Platforms & Status](platforms-and-status.md).
