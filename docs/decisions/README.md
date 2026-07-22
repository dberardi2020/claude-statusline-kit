# Decision records

Architecture decisions for the Claude Code Statusline Kit — the *why* behind the build.
Each records context, the options weighed, the decision, and its consequences.

| # | Decision | Status |
|---|---|---|
| [0001](0001-two-native-shell-scripts-over-node.md) | **Two native-shell scripts** (bash + PowerShell) over a single **Node** implementation | Accepted |

Numbered, append-only. A superseded decision stays and is marked `Superseded by NNNN` rather
than edited away.

## Why 0001 matters more than most

Almost every structural property of the kit follows from it:

- **Two implementations to maintain**, which is why [parity](../technical/implementations.md)
  is the load-bearing abstraction and why the [golden suite](../technical/testing.md) is
  merge-blocking rather than nice-to-have.
- **`jq` as the sole dependency** — the price of bash having no JSON parser.
- **PS 5.1 as the floor**, which is why the emoji are built with `ConvertFromUtf32` and why
  the file needs a UTF-8 BOM.
- **One download and one command** to install, because there's no runtime to bootstrap
  first.

If you're only going to read one ADR, read that one.
