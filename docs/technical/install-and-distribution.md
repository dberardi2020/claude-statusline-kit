# Install & Distribution

How the kit gets onto a machine. There's no build, no package, and no release artifact —
each script **installs itself**, which is why setup is one download and one command.

## The self-install mechanism

Each script has [two modes](../product/concepts.md#mode) in one file. An argument check at the very
top diverts to install mode and exits; everything else falls through to render.

| | bash | PowerShell |
|---|---|---|
| **Trigger** | `--install`, `install`, or `--setup` | `-Install` or `-Setup` |
| **Detects itself via** | `${BASH_SOURCE[0]}`, resolved to an absolute path | `$PSCommandPath` |

Bash resolves a relative `$BASH_SOURCE` to absolute before doing anything, and refuses to
proceed if it can't find itself as a file — `curl … | bash -s -- --install` has no file to
copy, so it fails with a clear message rather than installing something broken.

## The algorithm

Both implementations do the same seven things in the same order:

1. **Hard-check dependencies.** bash requires `jq` and aborts with a platform-appropriate
   hint (`brew install jq` / `apt install jq`) if it's missing. Failing here rather than at
   render time means the user learns about it *before* the statusline is wired in, not from
   a silently broken line afterwards. PowerShell has nothing to check.
2. **Note whether `~/.claude` already existed** — used for the Claude Code detection in
   step 7.
3. **Ensure `~/.claude/` exists** and copy the script into it. Bash `chmod +x` the copy. A
   script already running *from* the destination skips the copy rather than copying onto
   itself.
4. **Read any existing `statusLine.command`**, before writing anything, so step 6 can report
   honestly on what was there.
5. **Back up `settings.json`** to `settings.json.bak-<YYYYMMDDHHMMSS>`. This happens on
   **every** install run, before any modification. A missing settings file is first created
   as `{}`.
6. **Merge** the `statusLine` entry into the JSON — never overwrite the whole file.
7. **Report**, including the clash and Claude-Code-detection cases below.

## The merge, and why it's careful

`~/.claude/settings.json` is Claude Code's own settings file. It holds the user's
permissions, environment variables, hooks, model preferences — things far more valuable than
a statusline. Clobbering it would be an unrecoverable own-goal for a cosmetic tool.

So the write is a **read-modify-write of a single key**:

```sh
jq --arg cmd "$dest" '.statusLine = {type:"command", command:$cmd}' "$settings" > "$tmp"
```
```powershell
$cfg.statusLine = [pscustomobject]@{ type = 'command'; command = $newCmd }
($cfg | ConvertTo-Json -Depth 20) | Set-Content -LiteralPath $settings -Encoding UTF8
```

Bash writes through a **temp file** and only `mv`s it into place if `jq` succeeded, so a
parse failure can't leave a truncated settings file behind.

### Four cases the installer handles

| Case | Behaviour |
|---|---|
| **No `statusLine` configured** | Added. Normal path. |
| **The kit's own `statusLine` already there** | Replaced with itself and reported as a **refresh** — `(refreshed your existing Statusline Kit install)`. No warning. |
| **A *different* `statusLine` configured** | Replaced, but **announced** — prints the previous command and the backup path so the user can restore it. Never silent. |
| **`settings.json` isn't valid JSON** | **Abort.** The file is left untouched, the backup remains, and a manual snippet is printed for the user to paste. Exit 1. |

The clash case is the one that matters most: silently eating another tool's statusline would
be a genuinely bad citizen, and the user might not notice for days. The backup path is
printed alongside precisely so the fix is one `cp` away.

The refresh-vs-clash distinction is why step 4 reads the existing command *before* writing —
and why the bash path strips CR from that read. A stray `\r` from a Windows `jq.exe` would
make the kit's own entry compare unequal to its destination, so every re-install would warn
as though it were clobbering a stranger. See
[Implementations](implementations.md#bash--crlf-from-a-windows-jq).

### Claude Code detection

Last, the installer checks whether Claude Code looks present at all — `claude` on `PATH`, or
a pre-existing `~/.claude`. If neither, it still writes the config (it's harmless and
correct) but notes that Claude Code wasn't detected and points at the install page, so a
user who ran the installer on the wrong machine finds out immediately.

## Distribution

There is no release pipeline. The scripts are served **raw from `main`** on GitHub:

```bash
curl -fsSLO https://raw.githubusercontent.com/dberardi2020/claude-statusline-kit/main/statusline-command.sh
bash statusline-command.sh --install
```
```powershell
irm https://raw.githubusercontent.com/dberardi2020/claude-statusline-kit/main/statusline.ps1 -OutFile statusline.ps1
./statusline.ps1 -Install
```

Two consequences worth naming:

- **`main` is what users get.** There's no staging between a merge and a user's next
  download, which is exactly why the parity suite is merge-blocking.
- **There's no version stamp.** Nothing in the script records which revision it is, so
  neither the user nor the installer can tell a current copy from a year-old one. Part of
  what the **CSK-0001** command family would address.

### Download-then-run, not pipe-to-shell

The documented instructions download the file first and run it as a second step, rather than
`curl … | bash`. Two reasons: the user can read what they're about to run, and the installer
**needs a real file on disk** to copy into `~/.claude/` — bash's `[ -f "$src" ]` check
rejects the piped case explicitly.

### `llms.txt`

The repo root carries an [`llms.txt`](../../llms.txt) — a short machine-readable summary of
what the kit is, the install commands for both platforms, and links to the raw scripts and
the docs. It exists so a coding agent pointed at the repo can perform the install without
reading the whole README. The README carries a matching paste-ready prompt for the same
purpose.

## What doesn't exist yet

There is **no uninstall, update, or repair** command. Today `--install` is the entire
lifecycle, and everything else is manual:

| Want to | Today |
|---|---|
| **Update** | Re-download and re-run `--install`. It overwrites the copy, writes a fresh backup, and reports a refresh. |
| **Uninstall** | Delete the `statusLine` key from `settings.json` (or restore a `.bak-*`), delete the script, delete the backups. |
| **Repair** | Re-run `--install`, or restore a backup by hand. |

A first-class family — `install` · `update` · `reinstall` · `uninstall` · `repair` — is
tracked as **CSK-0001**, mirroring Terminal Launcher's **TLA-0020**. The safe merge
described above is the piece it would reuse.

Backups also accumulate one-per-install and are never cleaned up — including on a pure refresh
that changes nothing, so a day of iterating can leave half a dozen byte-identical files behind
(**CSK-0009**). The current policy errs deliberately: a lost setting is worse than a stray file.

## Testing the installer

`tests/install.sh` runs the bash installer against **throwaway `HOME` directories**, so a
real `~/.claude` is never touched. It asserts the merge preserves other keys, a backup is
written, a foreign `statusLine` is announced rather than silently replaced, a re-install is a
no-warn refresh, and invalid JSON aborts leaving the file untouched.

The PowerShell installer has **no automated coverage** — the suite is bash-only. See
[Testing](testing.md#install-mode-tests).
