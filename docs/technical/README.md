# Claude Code Statusline Kit — Technical docs

Documentation for **developers** working on the code. Assumes you've skimmed the
[Product docs](../product/README.md) for the vocabulary (Segment · Line · Coloring · Mode ·
Parity).

## Start here

| Doc | Read it for |
|---|---|
| [Architecture](architecture.md) | The two modes, the end-to-end flow from Claude Code's invocation to two printed lines, and the seams. |
| [Tech Stack](tech-stack.md) | Every dependency — bash 3.2, `jq`, PowerShell 5.1, GitHub Actions — and *why* each. |
| [Rendering](rendering.md) | **The specification.** Layout, per-segment computation, the color model, encoding. Both implementations must satisfy this doc. |
| [Implementations](implementations.md) | How bash and PowerShell each realize the spec, where they structurally differ, and the known divergences. |
| [Data Model & Config](data-model-and-config.md) | The session-JSON contract, the guard/default table, `settings.json`, and the `SL_NOW` seam. |
| [Install & Distribution](install-and-distribution.md) | The self-install algorithm, the safe `settings.json` merge, and how the kit is shipped. |
| [Module Reference](module-reference.md) | Every file: responsibility, structure, key functions. |
| [Testing](testing.md) | The golden-parity approach, the fixture set, install-mode tests, platform gotchas, and CI. |

## The shape, at a glance

Two standalone scripts, ~450 lines total, with no shared code between them — the parity is
enforced by tests rather than by abstraction.

```
statusline-command.sh      # bash implementation (227 lines) — render + install modes
statusline.ps1             # PowerShell implementation (222 lines) — render + install modes
                           #   ⚠ carries a load-bearing UTF-8 BOM on line 1
llms.txt                   # machine-readable summary for agents
tests/
  fixtures/*.json          # 8 representative session payloads
  golden/*.txt             # expected output — generated from bash, the reference impl
  run.sh  run.ps1          # render-golden runners; both compare to the SAME goldens
  install.sh               # install-mode tests against throwaway $HOME dirs
.github/workflows/tests.yml# bash on Linux; PS 7 + PS 5.1 on Windows, under chcp 437
docs/                      # this suite + decisions/ (ADRs)
  render.py                # stdlib-only Markdown → styled HTML renderer
```

## The three invariants worth knowing first

- **Every field read is guarded.** No access to the session JSON may raise. A missing key
  degrades its segment to a default or drops it from the line entirely. The statusline runs
  on every render in the user's terminal chrome — a crash there is worse than a blank
  field. See [Data Model & Config](data-model-and-config.md).
- **Bash is the reference implementation.** Goldens are generated from it; PowerShell is
  held to them. Every parity bug found so far has been PowerShell drifting from a correct
  bash. See [Implementations](implementations.md).
- **The render is a pure function of (stdin JSON, clock, filesystem).** No state persists
  between invocations. Pin the clock with `SL_NOW` and the output is fully determined —
  which is the entire basis of the test suite. See [Testing](testing.md).

## The one thing that will bite you

`statusline.ps1` **must** keep its UTF-8 BOM. Without it Windows PowerShell 5.1 decodes the
file as Windows-1252, mangles the astral-plane emoji, and fails to parse. Many editors and
formatters strip BOMs silently. See [Testing](testing.md#platform-notes).

## Deeper references

- [`../decisions/`](../decisions/) — the ADRs: *why* each choice was made. Start with
  [0001](../decisions/0001-two-native-shell-scripts-over-node.md), which is the decision the
  whole two-script structure follows from.
- [`../product/concepts.md`](../product/concepts.md) — the concept model (Segment · Line ·
  Coloring · Mode · Parity).
