# 0001 — Two native-shell scripts over a single Node implementation

- **Status:** Accepted
- **Date:** 2026-07-21

## Context

The statusline logic is platform-agnostic: read a JSON blob from stdin, print two ANSI lines.
Only the *runtime* differs by platform, because Claude Code's `statusLine.command` runs in
the OS default shell — **bash** on macOS/Linux, **PowerShell** on Windows. Maintaining two
implementations is more work for the author and one more "which file do I use?" question for
the user, so we evaluated collapsing both into a single cross-platform script (Node.js, the
strongest candidate since Claude Code is itself a Node project).

## Decision

Ship **two native-shell implementations** — `statusline-command.sh` and `statusline.ps1` —
rather than a single Node script.

## Rationale

A single Node script assumes `node` is on `PATH`. That assumption fails in practice: Claude
Code is increasingly installed via its **native binary installer**, which bundles no Node and
puts none on `PATH`. This was verified on a primary development machine where `node` and
`npm` are both absent, yet Claude Code (a compiled native binary) runs fine — a Node-based
statusline installed as `node "…"` would simply fail there.

The native shells, by contrast, are **guaranteed present** on their platforms (bash on
macOS/Linux, PowerShell on Windows), so the two-script approach has zero unmet runtime
dependencies. We accept the dual-maintenance cost in exchange for that robustness.

## Consequences

- Two files must be kept in **behavioral lockstep** — same JSON contract, same layout,
  same color thresholds. [technical/rendering.md](../technical/rendering.md) is the shared spec,
  and the golden-parity tests ([technical/testing.md](../technical/testing.md)) enforce it in
  CI. This risk is not hypothetical: the PowerShell script has drifted from bash more than
  once (rate-limit dropping, bar rounding, cwd fallback), always with bash correct — which is
  what motivated the parity suite.
- The only external dependency is `jq` for the bash implementation's JSON parsing;
  PowerShell uses its built-in JSON support.
- If a future builder/wizard emerges, revisit whether a shared generator (emitting both
  scripts from one source of truth) reduces the duplication without reintroducing a runtime
  dependency.
