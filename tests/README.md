# Tests

Deterministic tests for the statusline. Both scripts read a fixed clock from the `SL_NOW`
environment variable (unset in normal use), so rate-limit countdowns are reproducible and
the two implementations can be compared against the same expected output.

## Render golden tests

`fixtures/*.json` are sample statusline payloads; `golden/*.txt` are the expected outputs.
**Both implementations must match the same goldens** — that is how cross-platform parity is
verified.

```bash
bash tests/run.sh                 # macOS/Linux (bash)
```
```powershell
pwsh tests/run.ps1                # PowerShell 7
powershell -File tests\run.ps1    # Windows PowerShell 5.1
```

Regenerate goldens after an *intentional* format change (bash is the reference):

```bash
for f in tests/fixtures/*.json; do
  SL_NOW=1700000000 bash statusline-command.sh < "$f" > "tests/golden/$(basename "$f" .json).txt"
done
```

## Install-mode tests (bash)

```bash
bash tests/install.sh
```

Exercises the settings.json merge, backup creation, the existing-statusLine clash warning,
and the invalid-JSON abort — each against a throwaway `HOME`, so your real `~/.claude` is
never touched.

> **Known limitation (Git Bash on Windows):** one assertion, *re-install does not warn*, is
> **skipped** there (you'll see 7 passed + 1 skipped). `jq --arg cmd "$dest"` goes through
> MSYS path translation, so `settings.json` stores a `C:/…` path while `$dest` stays `/…`,
> and the re-read never matches — a refresh always warns. bash-on-Windows is an unsupported
> configuration (Windows users run `statusline.ps1`); see
> [../docs/technical/testing.md](../docs/technical/testing.md).

## CI

`.github/workflows/tests.yml` runs `run.sh` + `install.sh` on Linux and `run.ps1` on Windows
(both PowerShell 7 and Windows PowerShell 5.1, under the OEM console codepage `chcp 437`)
against the same goldens — turning cross-platform parity into a checked invariant and giving
the PowerShell implementation real Windows coverage. See
[../docs/technical/testing.md](../docs/technical/testing.md).
