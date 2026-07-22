# Testing

The kit maintains two implementations that must behave identically, so the suite is built
around **cross-platform parity**: both scripts are run against the *same* expected outputs.
A green run on both platforms *is* the parity proof — there's no shared code to unit-test
instead.

```sh
bash tests/run.sh                 # render goldens, bash
bash tests/install.sh             # install mode, bash
pwsh tests/run.ps1                # render goldens, PowerShell 7
powershell -File tests\run.ps1    # render goldens, Windows PowerShell 5.1
```

## The clock seam

Rate-limit segments render a countdown (`resets_at − now`), which would make output
non-deterministic. Both scripts therefore read `now` from the **`SL_NOW`** environment
variable when it is set, falling back to the real clock otherwise. `SL_NOW` is unset in
normal use and has zero runtime effect; it exists purely so tests produce stable, comparable
output. The pinned test value is `1700000000`.

With the clock pinned, a render is a **pure function of (stdin JSON, `SL_NOW`,
filesystem)** — which is what makes golden testing possible at all. See
[Data Model & Config](data-model-and-config.md#the-sl_now-seam).

## Render golden tests

| Piece | What |
|---|---|
| `tests/fixtures/*.json` | Eight representative session payloads. |
| `tests/golden/*.txt` | The expected output, **generated from the bash script** — the reference implementation. |
| `tests/run.sh` · `tests/run.ps1` | Each feeds the fixtures through its own script and compares to the goldens. |

Because both runners compare to the *same* goldens, a green run on both platforms proves
parity. Both normalize `\r` and trailing newlines before comparing, which is why the
trailing-newline difference between the implementations sits outside the spec.

### What the fixtures cover

| Fixture | Exercises |
|---|---|
| `typical` | The ordinary full payload. |
| `green` · `yellow` · `red` | The three usage-color thresholds. |
| `no-ratelimits` | Rate-limit segments dropping when absent. |
| `past-reset` | A `resets_at` in the past — must clamp to `0`, not go negative. |
| `minimal` | Defaults and dropped segments: only a model and a `cwd`. |
| `countdown-red` | An early window — **low usage, hot countdown** — proving the two colorings are independent. |

### Regenerating

After an *intentional* format change. Make the change in **bash first**, regenerate, then
bring PowerShell up to the new goldens:

```bash
for f in tests/fixtures/*.json; do
  SL_NOW=1700000000 bash statusline-command.sh < "$f" > "tests/golden/$(basename "$f" .json).txt"
done
```

### Parity bugs this suite has caught

All bash-correct, PowerShell drifted: rate-limit segments not dropping when absent, the
context bar using banker's rounding instead of round-half-up, the context segment not
dropping when absent, and `cwd` not preferring `workspace.current_dir`.

## Install-mode tests

`tests/install.sh` runs the bash installer against throwaway `HOME` directories — the real
`~/.claude` is never touched — and asserts that:

- the `settings.json` merge preserves other keys,
- a backup is written,
- an existing **foreign** `statusLine` is announced rather than silently replaced,
- re-installing the kit's own entry is a **no-warn refresh**,
- invalid JSON **aborts** while leaving the file untouched.

The PowerShell installer has **no automated coverage**; the suite is bash-only.

## Coverage gaps

Known, tracked, and worth keeping in view — the suite is strong on parity and weak on
breadth:

| Gap | Ticket |
|---|---|
| **Branch detection is entirely untested.** Every fixture's `cwd` points at a non-repo, so `🌿 ---` is baked into all goldens and the suite structurally cannot catch divergence in the `.git/HEAD` walk — which is how a real bash-vs-PowerShell difference on a detached HEAD went unnoticed. Needs a temp-repo test rather than a static-JSON golden. | **CSK-0007** |
| **No fixture supplies `resets_at` without `used_percentage`**, or omits the working directory — so two real behavioral divergences are invisible to the suite. See [Implementations](implementations.md#known-divergences). | — |
| **No PowerShell install-mode tests.** | — |
| **No local macOS PowerShell run** — no `pwsh` on the primary Mac, so the PS leg is verified only in CI and on a Windows box. | **CSK-0005** |
| **No Git-Bash + Windows-`jq` leg** — the CRLF-stripping guard has no CI coverage. Tests an unsupported config, hence low priority. | **CSK-0004** |

## Platform notes

- **PS 5.1 requires a UTF-8 BOM.** Without it, PowerShell 5.1 reads the script as
  Windows-1252, mangles the astral-plane emoji, and fails to parse. The BOM on line 1 of
  `statusline.ps1` is load-bearing — do not strip it. Many editors and formatters remove
  BOMs silently, so check it first if the script suddenly won't run on 5.1.
- **Console encoding must be pinned in the test runner.** PS 5.1 decodes a child process's
  stdout using `[Console]::OutputEncoding`, which on a real Windows console is the OEM
  codepage (e.g. IBM437) — so the statusline's UTF-8 emoji come back as mojibake. CI's
  runner happened to default to UTF-8, which is why this passed there and only broke on an
  actual desktop. `run.ps1` pins **both** directions to **BOM-less** UTF-8
  (`New-Object System.Text.UTF8Encoding $false` — the plain `[Text.Encoding]::UTF8` has
  `emitBOM=true`, which would prefix a BOM onto the child's stdin and break
  `ConvertFrom-Json`) and restores the prior encoding in a `finally`.
- **Windows `jq.exe` emits CRLF.** A native Windows `jq` (e.g. Chocolatey's) terminates
  lines with CRLF, so under Git Bash every parsed value carries a trailing `\r` — enough to
  break the bash arithmetic. `statusline-command.sh` strips CR at both `jq` boundaries (a
  no-op where `jq` emits LF).
- **`.gitattributes` pins `eol=lf`.** A Windows checkout rewriting line endings would
  corrupt the bash script and break every golden comparison.

## Known limitation: bash on Windows

The bash script is scoped to **macOS/Linux** (Windows users run `statusline.ps1`), and
running it under Git Bash is unsupported. In `install.sh`, the *re-install does not warn*
assertion is **skipped** on Git Bash / MSYS / Cygwin: `jq --arg cmd "$dest"` passes through
MSYS path translation, so `settings.json` stores a `C:/…` path while `$dest` stays `/…`, and
the re-read never matches — so a refresh always warns. Rather than import Windows
path-translation handling (`MSYS2_ARG_CONV_EXCL`) into a script deliberately kept
platform-pure (see [ADR 0001](../decisions/0001-two-native-shell-scripts-over-node.md)), the
assertion is skipped there; the suite reads 7 passed + 1 skipped.

A second, separate bash-on-Windows defect is tracked as **CSK-0006**: the branch walk never
terminates on a Windows-style path outside a repo, because `dirname` reaches `.` rather than
`/`.

## CI

`.github/workflows/tests.yml` runs:

| Job | Runner | Steps |
|---|---|---|
| **bash** | `ubuntu-latest` | `tests/run.sh`, then `tests/install.sh` |
| **powershell** | `windows-latest` | `tests/run.ps1` under **PowerShell 7**, then again under **Windows PowerShell 5.1** — the version the BOM fix targets |

Both Windows steps force the **OEM console codepage** (`chcp 437`) first, so a runner's
UTF-8 default can no longer hide a console-decode bug the way it did once before.

This makes parity a **merge-blocking invariant** and gives the PowerShell path real Windows
coverage on every push — which matters more than usual here, because the scripts are served
raw from `main` with no staging between a merge and a user's next download.
