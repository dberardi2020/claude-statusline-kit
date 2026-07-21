# Testing

The kit maintains two implementations that must behave identically, so the tests are built
around **cross-platform parity**: both scripts are run against the *same* expected outputs.

## The clock seam

Rate-limit segments render a countdown (`resets_at − now`), which would make output
non-deterministic. Both scripts therefore read `now` from the `SL_NOW` environment variable
when it is set, falling back to the real clock otherwise. `SL_NOW` is unset in normal use and
has zero runtime effect; it exists purely so tests produce stable, comparable output.

## Render golden tests

- `tests/fixtures/*.json` — representative statusline payloads (typical, the three color
  thresholds, absent rate-limits, a past reset that must clamp to `0`, a minimal payload that
  exercises defaults and dropped segments, and a red-countdown case where the window is early
  — low usage but a hot countdown, proving the two colorings are independent).
- `tests/golden/*.txt` — the expected output, generated from the **bash** script (the
  reference implementation).
- `tests/run.sh` and `tests/run.ps1` each feed the fixtures through their script and compare
  to the goldens. Because both compare to the *same* goldens, a green run on both platforms
  proves parity.

Parity bugs this suite has already caught (all bash-correct, PowerShell drifted): rate-limit
segments not dropping when absent, the context bar using banker's rounding instead of
round-half-up, the context segment not dropping when absent, and `cwd` not preferring
`workspace.current_dir`.

## Install-mode tests

`tests/install.sh` runs the bash installer against throwaway `HOME` directories and asserts
the settings.json merge preserves other keys, a backup is written, an existing foreign
`statusLine` is announced rather than silently replaced, re-installing is a no-warn refresh,
and invalid JSON aborts while leaving the file untouched.

## Platform notes

- **PS 5.1 requires a UTF-8 BOM.** Without it, PowerShell 5.1 reads the script as
  Windows-1252, mangles the astral-plane emoji, and fails to parse. The BOM on line 1 of
  `statusline.ps1` is load-bearing — do not strip it.
- **Console encoding must be pinned in the test runner.** PS 5.1 decodes a child process's
  stdout using `[Console]::OutputEncoding`, which on a real Windows console is the OEM
  codepage (e.g. IBM437) — so the statusline's UTF-8 emoji come back as mojibake. `run.ps1`
  pins both directions to **BOM-less** UTF-8 (`New-Object System.Text.UTF8Encoding $false`;
  a BOM-emitting encoding would prefix a BOM onto the child's stdin and break `ConvertFrom-Json`)
  and restores the prior encoding in a `finally`.
- **Windows `jq.exe` emits CRLF.** A native Windows `jq` (e.g. Chocolatey's) terminates lines
  with CRLF, so under Git Bash every parsed value carries a trailing `\r` — enough to break
  the bash arithmetic. `statusline-command.sh` strips CR at both jq boundaries (a no-op where
  jq emits LF).
- The `.gitattributes` `eol=lf` rule keeps a Windows checkout from rewriting line endings,
  which would otherwise corrupt the bash scripts and break golden comparisons.

## Known limitation: bash on Windows

The bash script is scoped to **macOS/Linux** (Windows users run `statusline.ps1`), and running
it under Git Bash is unsupported. In `install.sh`, the *re-install does not warn* assertion is
**skipped** on Git Bash / MSYS / Cygwin: `jq --arg cmd "$dest"` passes through MSYS path
translation, so `settings.json` stores a `C:/…` path while `$dest` stays `/…`, and the re-read
never matches — so a refresh always warns. Rather than import Windows path-translation handling
(`MSYS2_ARG_CONV_EXCL`) into a script deliberately kept platform-pure (see
[decisions/0001](../decisions/0001-two-native-shell-scripts-over-node.md)), the assertion is
skipped there; the suite reads 7 passed + 1 skipped.

## CI

`.github/workflows/tests.yml` runs the bash suites on `ubuntu-latest` and the render tests on
`windows-latest` under **both** PowerShell 7 and Windows PowerShell 5.1 — the latter being the
version the BOM fix targets. The Windows steps force the **OEM console codepage** (`chcp 437`)
first, so a runner's UTF-8 default can no longer hide a console-decode bug the way it did once
before. This makes parity a merge-blocking invariant and gives the PowerShell path real Windows
coverage on every push.
