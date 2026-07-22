# Tech Stack

A deliberately tiny stack. There is **no build step, no package manager, and no runtime to
install** — the whole kit is two scripts written in shells that ship with their operating
systems. Exactly one external dependency exists, and only on one platform.

## The runtimes

| | macOS / Linux | Windows |
|---|---|---|
| **Shell** | bash | PowerShell |
| **Floor** | **3.2** | **5.1** (Windows PowerShell) |
| **Why that floor** | 3.2 is what macOS ships (2007-era, frozen for GPL-license reasons). Targeting it means no `declare -A`, no `${var^^}`, no `mapfile`. | 5.1 is what Windows ships out of the box. PowerShell 7 is supported too, but 5.1 is the constraint. |
| **JSON** | `jq` (external) | `ConvertFrom-Json` (built in) |

Targeting the *shipped* version of each shell rather than a current one is the whole point:
the kit's argument for existing in two implementations is that both are **guaranteed
present**. A script that needs bash 5 or PowerShell 7 would reintroduce the install step
that [ADR 0001](../decisions/0001-two-native-shell-scripts-over-node.md) set out to avoid.

## Dependencies

| Dependency | Platform | Buys | Needed at |
|---|---|---|---|
| `jq` | macOS / Linux | JSON parsing for bash | **install and render** |

That is the complete list. PowerShell needs nothing — `ConvertFrom-Json` has been built in
since PS 3.0.

### Why `jq` — and why it's acceptable

bash has no JSON parser, and hand-rolling one in a shell that predates associative arrays
would be both fragile and far more code than the rest of the script. `jq` is the standard
answer, is in every package manager, and does the whole parse in **one invocation** — the
script asks for all nine fields at once and reads them back a line at a time:

```sh
jq -r '(.model.display_name // "?"), (.workspace.current_dir // .cwd // ""), …'
```

The `//` operator supplies the default inline, which is what makes the
[guard-everything rule](data-model-and-config.md) cheap rather than nine separate checks.

It's the one place the kit accepts an unmet dependency, and it's a real cost: a user without
`jq` gets nothing until they install it, so the installer **hard-checks** for it and fails
early with a platform-appropriate hint rather than letting the statusline silently fail at
render time.

### What was rejected: Node

The strongest single-implementation candidate, and the one ADR 0001 exists to reject. A Node
script assumes `node` on `PATH` — an assumption that fails in practice, because Claude Code
is increasingly installed via its **native binary installer**, which bundles no Node and
puts none on `PATH`. This was verified on a development machine where `node` and `npm` are
both absent yet Claude Code runs fine; a statusline installed as `node "…"` would simply
have failed there.

Being a Node project itself is not the same as putting Node on the user's machine. See
[ADR 0001](../decisions/0001-two-native-shell-scripts-over-node.md).

### What was rejected: `git`

The branch segment reads `.git/HEAD` off the filesystem rather than shelling out to `git`.
Two reasons: it would add a `git`-on-`PATH` dependency the bash path doesn't otherwise have,
and `git branch --show-current` prints **nothing** on a detached HEAD, where the kit shows a
short SHA — so matching bash and PowerShell would have meant special-casing that anyway.
Reading the file directly is fewer moving parts and identical on both platforms.

## What the standard shells provide

Everything else is built in, and worth listing because it's the reason there's no
dependency list:

| Need | bash | PowerShell |
|---|---|---|
| JSON parse | `jq` | `ConvertFrom-Json` |
| Rounding | `printf '%.0f'` | `[math]::Round` / `[math]::Floor` |
| Integer math | `$(( ))` | native |
| Unix clock | `date +%s` | `[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()` |
| Path leaf | `basename` | `Split-Path -Leaf` |
| Path parent | `dirname` | `Split-Path -Parent` |
| Colors | ANSI SGR via `$'\033[…m'` | ANSI SGR via `[char]27` |
| Non-ASCII output | UTF-8 source literals | `[char]::ConvertFromUtf32` (see below) |

### The one PowerShell workaround

Astral-plane emoji (🤖 📅 📁 🌿 💰, all above U+FFFF) cannot be written as literals in a
PS 5.1 script — they get mangled. They're constructed instead:

```powershell
$e_robot = [char]::ConvertFromUtf32(0x1F916)
```

Related and load-bearing: `statusline.ps1` carries a **UTF-8 BOM** on line 1. Without it,
PS 5.1 reads the file as Windows-1252 and fails to parse. Don't strip it — see
[Testing](testing.md#platform-notes).

## Test & CI tooling

| Piece | What it is | Why |
|---|---|---|
| **`tests/run.sh` · `run.ps1`** | Hand-written runners, no framework | A test framework would be a dependency, and the whole assertion is "does stdout equal this file". |
| **`tests/golden/*.txt`** | Expected output, generated from bash | The parity seam. Both runners compare to these same files. |
| **`tests/install.sh`** | Install-mode tests against throwaway `$HOME`s | The installer edits a real user's `settings.json`; it gets real coverage. |
| **`SL_NOW`** | Environment variable overriding the clock | The only nondeterminism in the program, isolated so output can be pinned. |
| **GitHub Actions** | `ubuntu-latest` + `windows-latest` | Turns parity into a merge-blocking invariant and gives PowerShell real Windows coverage — including a dedicated PS 5.1 job under `chcp 437`. |

## Repo tooling

| Piece | What it is |
|---|---|
| **`docs/render.py`** | Stdlib-only Python renderer producing the paired `.html` for each doc. Not a dependency of the kit — a docs-authoring tool. |
| **`.gitattributes`** | Pins `eol=lf`. A Windows checkout rewriting line endings would corrupt the bash script and break every golden comparison. |
| **`llms.txt`** | A machine-readable summary at the repo root, so a coding agent pointed at the repo can install the kit without reading the whole README. |

## The dependency-minimization rule

The stack stays this small because of one standing rule: **a new dependency must be
guaranteed present on its platform, or it doesn't go in.**

`jq` is the sole exception, and it's grandfathered on the strength of being universally
packaged, doing the entire parse in one call, and being hard-checked at install time so a
user learns about it before the statusline is wired in rather than after.

Anything that would require a user to install a runtime — a language, a package manager, a
framework — is rejected on sight, because the moment setup stops being "download one file
and run it," the kit has lost the property it exists for.
