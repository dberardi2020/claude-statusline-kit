# Architecture

The Statusline Kit is a **stateless filter**: JSON in on stdin, two ANSI lines out on
stdout, exit. There is no daemon, no cache, and no state carried between invocations. The
"architecture" is therefore mostly about two things — the **mode split** inside each script,
and the **parity seam** between the two scripts.

## The layers

```
  ┌─────────────────────────── Claude Code ────────────────────────────┐
  │  reads settings.json → invokes statusLine.command once per render,  │
  │  pipes session JSON on stdin, draws stdout in the terminal chrome   │
  └──────────────────────────────┬─────────────────────────────────────┘
                                 │  session JSON
                                 ▼
  ┌──────────────────────── One script, two modes ─────────────────────┐
  │                                                                     │
  │   argv guard ──► INSTALL MODE          ──► exit 0                   │
  │   (--install / -Install)   copy self → ~/.claude/                   │
  │                            back up + merge settings.json            │
  │                                                                     │
  │   otherwise  ──► RENDER MODE                                        │
  │                     1. parse   stdin JSON → 9 scalars               │
  │                     2. compute each segment, independently          │
  │                     3. assemble line 1 (variable) + line 2 (fixed)  │
  │                     4. print   2 lines + 2 rules                    │
  └──────────────────────────────┬─────────────────────────────────────┘
                                 │
                    ┌────────────┴────────────┐
                    ▼                         ▼
        statusline-command.sh        statusline.ps1
        bash 3.2 · jq                PowerShell 5.1 · ConvertFrom-Json
        macOS / Linux                Windows
                    \                         /
                     └──── same goldens ─────┘
                        tests/golden/*.txt
                     (parity is a test, not code)
```

## The parity seam

This is the unusual part of the design and the thing to understand first.

There is **no shared code** between the two implementations — not a common core, not a
generated file, not a config format they both read. They are two independent programs that
happen to produce identical bytes. The seam that holds them together is
`tests/golden/*.txt`: a set of expected-output files that **both** runners compare against.

That choice has a clear cost and a clear benefit:

| | |
|---|---|
| **Cost** | Every behavioral change must be made twice, and PowerShell has drifted from bash more than once. |
| **Benefit** | Zero runtime dependencies. Each script is a single file in a shell guaranteed to exist on its platform, with nothing to install and nothing to bootstrap. |

The trade was made deliberately — see
[ADR 0001](../decisions/0001-two-native-shell-scripts-over-node.md). The golden suite exists
precisely because the cost is real: it converts "two files must stay in sync" from a
discipline into a merge-blocking CI check.

**Bash is the reference.** Goldens are generated from it; PowerShell is held to them.

## End-to-end: what one render does

1. **Claude Code invokes the command.** It read `statusLine.command` from
   `~/.claude/settings.json` at startup and runs it once per render, piping a JSON object
   describing the session to stdin.
2. **Mode guard.** The script checks its arguments first. `--install` / `-Install` diverts
   to install mode and exits; anything else falls through to render. Bash additionally
   guards the *bare interactive run* — no args and a TTY on stdin means a human ran it by
   hand, so it prints usage instead of blocking on `cat`.
3. **Parse.** The entire payload is reduced to **nine scalars** in one pass — model, cwd,
   context %, two rate-limit resets, two rate-limit percentages, cost, duration. Bash does
   this with a single `jq` invocation emitting one value per line; PowerShell with
   `ConvertFrom-Json` plus a `Get-Safe` path walker. Every read carries a default, so a
   missing key yields an empty string rather than an error.
4. **Read the clock.** `now` comes from `SL_NOW` if that environment variable is set,
   otherwise the real clock. This is the [test seam](testing.md#the-clock-seam) — unset in
   normal use, zero runtime effect.
5. **Compute each segment independently.** Nine segments, each from its own one or two
   scalars, each guarded so an unset source produces an empty segment string rather than a
   zero. Nothing on the line is derived from anything else on the line. Full spec in
   [Rendering](rendering.md).
6. **Assemble.** Line 1 is built by appending only the non-empty segments, so absent data
   shortens the line rather than leaving a hole. Line 2 is fixed at four segments — its
   sources always have defaults.
7. **Print.** Line 1, a 71-char rule, line 2, a second rule.

Steps 3–7 touch nothing outside the process except the wall clock and the filesystem (for
`.git/HEAD` during branch detection). That's what makes the whole thing deterministic under
a pinned `SL_NOW`, and it's the entire basis of the test suite.

## The key seams (where responsibilities are cut)

| Seam | Boundary | Why it's there |
|---|---|---|
| **Claude Code ↔ kit** | The session JSON on stdin; two lines on stdout. | The only contract with the host. The kit never asks Claude Code anything — it renders what it's handed. See [Data Model & Config](data-model-and-config.md). |
| **Render ↔ install** | An argv check at the top of the file. | One file does both, so setup is one download and one command with no separate installer to trust. See [Install & Distribution](install-and-distribution.md). |
| **Parse ↔ compute** | Nine scalars with defaults already applied. | All the payload-shape knowledge lives in one place. Segment code below it never touches the JSON, so a payload change is a one-line fix. |
| **Bash ↔ PowerShell** | `tests/golden/*.txt` — expected output, not shared code. | Zero runtime dependencies at the cost of dual maintenance; the goldens make the cost visible in CI rather than at a user's terminal. See [Implementations](implementations.md). |
| **Clock ↔ render** | `SL_NOW`, read once. | The only nondeterminism in the program, isolated to one variable so the output can be pinned. See [Testing](testing.md). |

## Why the design looks like this

- **Two native-shell scripts, not one Node script**
  ([0001](../decisions/0001-two-native-shell-scripts-over-node.md)) — a shared runtime would
  assume `node` on `PATH`, and Claude Code's native-binary installer puts none there. The
  native shells are guaranteed present on their platforms, so the two-script approach has
  zero unmet runtime dependencies. Everything else in this document follows from that.
- **Parity enforced by goldens rather than by abstraction** — the natural fix for dual
  maintenance is a shared core, but there's no language both shells can share without
  reintroducing exactly the runtime dependency ADR 0001 rejected. Tests are the only
  available seam.
- **Guard everything, assert nothing** — the statusline renders on *every* Claude Code
  render, in the user's terminal chrome. A crash there is constant, noisy, and reads as
  Claude Code being broken. So a missing field costs one segment, never the line.
- **Segments drop rather than zero** — rendering `⏳ [0h0m] 0%` for absent data would be
  actively misleading, and there's no way to distinguish "no data" from "genuinely zero"
  after the fact. Dropping is the honest degradation.
- **Stateless** — a cache would need invalidation, a lock, and a location, and would buy
  nothing: the payload already carries everything except the clock and the branch.

For the full decision history, read [`../decisions/`](../decisions/).
