# Platforms & Status

What you need to run the kit, which combinations are actually verified, and what's
knowingly unsupported or deferred.

## Requirements

| | macOS / Linux | Windows |
|---|---|---|
| **Script** | `statusline-command.sh` | `statusline.ps1` |
| **Shell** | bash 3.2+ | Windows PowerShell 5.1, or PowerShell 7 |
| **JSON parsing** | [`jq`](https://jqlang.github.io/jq/) — required at install **and** render | built in (`ConvertFrom-Json`) |
| **Terminal** | UTF-8 + ANSI color | UTF-8 + ANSI color (Windows Terminal recommended) |

`jq` is the kit's only external dependency, and only on the bash side. Everything else is
guaranteed present on its platform — which is precisely the argument for two native-shell
scripts over one shared runtime
([ADR 0001](../decisions/0001-two-native-shell-scripts-over-node.md)).

## Platform status

| Platform | Shell | Status | Verified by |
|---|---|---|---|
| **Linux** | bash | ✅ Supported | CI — render goldens + install-mode tests on every push |
| **macOS** | bash | ✅ Supported | Local development machine; same script as the CI-covered Linux leg |
| **Windows** | PowerShell 7 | ✅ Supported | CI — render goldens on `windows-latest`, under the OEM codepage |
| **Windows** | Windows PowerShell 5.1 | ✅ Supported | CI — same goldens, separate job; this is the version the BOM fix targets |
| **Windows** | bash (Git Bash / MSYS / Cygwin) | ⚠️ **Unsupported** | — see below |

### What CI actually proves

Both platforms are compared against the **same golden files**, so a green run on both *is*
the parity proof rather than two independent smoke tests. The Windows jobs deliberately
force the OEM console codepage (`chcp 437`) first, so a runner's UTF-8 default can't hide a
console-decode bug — which it did once before.

Coverage gaps that are known and tracked:

- **No local macOS PowerShell run** — there's no `pwsh` on the primary Mac, so the
  PowerShell leg is verified only in CI and on a Windows box (**CSK-0005**).
- **No branch-segment coverage** — every render fixture points at a non-repo, so `🌿 ---`
  is baked into all goldens and the suite structurally can't catch branch-detection
  divergence (**CSK-0007**).
- **No Git-Bash + Windows-`jq` leg** — the CRLF-stripping guard in the bash script has no
  CI coverage (**CSK-0004**).

## Unsupported: bash on Windows

Running `statusline-command.sh` under Git Bash, MSYS, or Cygwin is **not supported**.
Windows users run `statusline.ps1`. Two concrete reasons, both left unfixed on purpose:

- **The branch walk doesn't terminate.** The loop walks up until it reaches `/`, but on a
  Windows-style path `dirname` goes `C:/Users` → `C:` → `.` → `.` and never gets there
  (**CSK-0006**). Unix paths are unaffected.
- **Path translation breaks re-install detection.** MSYS rewrites the path `jq` is handed,
  so `settings.json` stores a `C:/…` path while the script holds a `/…` one, and a refresh
  always reports as a clash. The install test skips that one assertion there.

Both are consequences of keeping the bash script platform-pure rather than importing
Windows path handling into it.

## Terminal compatibility

The kit emits UTF-8 (block characters `▓░`, box-drawing `─`, and astral-plane emoji) plus
palette-indexed ANSI SGR codes. Anything that renders those correctly will render the
statusline correctly.

Two known rough edges:

- **Color fidelity varies by terminal.** Green/yellow/red are palette indices (32/33/31),
  so each terminal maps them to its own theme RGB — notably muted against Windows
  Terminal's default next to the pinned bright white. A move to 24-bit truecolor is tracked
  as **CSK-0002**.
- **PowerShell 5.1 needs the BOM.** `statusline.ps1` carries a UTF-8 BOM on line 1. Without
  it, PS 5.1 reads the file as Windows-1252, mangles the emoji, and fails to parse. It's
  load-bearing — don't strip it.

## Claude Code version compatibility

The kit reads Claude Code's session JSON but never asserts on its shape. Every field is
guarded, and an absent one drops its segment rather than erroring — so a Claude Code
release that renames or removes a field costs you one segment, not a broken statusline.

The practical consequence you'll actually see: `context_window` and `rate_limits` are
absent until a session has usage, so line 1 is short on a brand-new session (**CSK-0011**).

## Deferred / not yet built

| | Status |
|---|---|
| **Style catalogue** — alternative layouts and segment sets | Deferred (roadmap) |
| **Builder / wizard** — pick segments, generate the script | Deferred — **CSK-0003** |
| **Management commands** — `update`, `repair`, `uninstall` as first-class verbs | Deferred — **CSK-0001** |
| **Truecolor output** | Deferred — **CSK-0002** |
| **First-run placeholders** for not-yet-known fields | Under consideration — **CSK-0011** |

The live backlog is [`tickets/tickets.md`](../tickets/tickets.md).
