#!/usr/bin/env bash
# Install-mode tests for the bash statusline. Uses a throwaway HOME for each case,
# so it NEVER touches your real ~/.claude. Run: bash tests/install.sh
set -u
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(dirname "$here")"
script="$repo/statusline-command.sh"
pass=0; fail=0; skip=0
check() { if eval "$2"; then echo "ok   $1"; pass=$((pass+1)); else echo "FAIL $1"; fail=$((fail+1)); fi; }
# Git Bash / MSYS / Cygwin on Windows — bash-on-Windows is an unsupported config here
# (Windows users run statusline.ps1), and MSYS path translation makes one assertion moot.
is_win_bash=0
case "$(uname -s 2>/dev/null)" in MINGW*|MSYS*|CYGWIN*) is_win_bash=1 ;; esac

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cp "$script" "$work/sl.sh"; chmod +x "$work/sl.sh"

do_install() { # $1 = fake HOME ; stderr captured to $1/.err
  env -i HOME="$1" PATH="$PATH" bash "$work/sl.sh" --install >/dev/null 2>"$1/.err"
}

# 1. Merge preserves unrelated keys, adds statusLine, writes a backup.
h1="$work/h1"; mkdir -p "$h1/.claude"; printf '%s' '{"theme":"dark"}' > "$h1/.claude/settings.json"
do_install "$h1"
check "merge preserves other keys" '[ "$(jq -r .theme "$h1/.claude/settings.json")" = "dark" ]'
check "statusLine wired"           '[ -n "$(jq -r ".statusLine.command // empty" "$h1/.claude/settings.json")" ]'
check "backup written"             'ls "$h1/.claude"/settings.json.bak-* >/dev/null 2>&1'

# 2. A foreign existing statusLine is replaced but announced (not silent).
h2="$work/h2"; mkdir -p "$h2/.claude"
printf '%s' '{"statusLine":{"type":"command","command":"~/old.sh"}}' > "$h2/.claude/settings.json"
do_install "$h2"
check "foreign statusLine warns"   'grep -q "replaced an existing statusLine" "$h2/.err"'

# 3. Re-installing our own entry is a refresh, not a warning.
# Skipped on Git Bash (Windows): `jq --arg cmd "$dest"` passes through MSYS path
# translation, so settings.json stores a C:/… form while $dest stays /…, and the
# re-read never matches — a refresh always warns. That path is unsupported (use
# statusline.ps1), so this is skipped rather than failed. See docs/technical/testing.md.
if [ "$is_win_bash" -eq 1 ]; then
  echo "skip re-install does not warn (bash-on-Windows unsupported; use statusline.ps1)"; skip=$((skip+1))
else
  do_install "$h2"
  check "re-install does not warn"   '! grep -q "replaced an existing statusLine" "$h2/.err"'
fi

# 4. Invalid JSON aborts, keeps the backup, leaves the file byte-identical.
h4="$work/h4"; mkdir -p "$h4/.claude"; printf '%s' '{ not json' > "$h4/.claude/settings.json"
do_install "$h4" || true
check "invalid json aborts"        'grep -qi "isn.t valid json" "$h4/.err"'
check "invalid json left untouched" '[ "$(cat "$h4/.claude/settings.json")" = "{ not json" ]'
check "invalid json kept a backup" 'ls "$h4/.claude"/settings.json.bak-* >/dev/null 2>&1'

echo "---- install: $pass passed, $fail failed, $skip skipped ----"
[ "$fail" -eq 0 ]
