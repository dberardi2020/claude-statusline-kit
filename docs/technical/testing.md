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
  thresholds, absent rate-limits, a past reset that must clamp to `0`, and a minimal payload
  that exercises defaults and dropped segments).
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
- The `.gitattributes` `eol=lf` rule keeps a Windows checkout from rewriting line endings,
  which would otherwise corrupt the bash scripts and break golden comparisons.

## CI

`.github/workflows/tests.yml` runs the bash suites on `ubuntu-latest` and the render tests on
`windows-latest` under **both** PowerShell 7 and Windows PowerShell 5.1 — the latter being the
version the BOM fix targets. This makes parity a merge-blocking invariant and gives the
PowerShell path real Windows coverage on every push.
