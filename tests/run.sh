#!/usr/bin/env bash
# Render golden tests for the bash statusline.
# Feeds each tests/fixtures/*.json to the script (clock pinned via SL_NOW) and
# diffs the output against tests/golden/*.txt. Run: bash tests/run.sh
set -u
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(dirname "$here")"
script="$repo/statusline-command.sh"
export SL_NOW=1700000000
strip_ansi() { sed -E $'s/\x1b\\[[0-9;]*m//g'; }
pass=0; fail=0
for fx in "$here"/fixtures/*.json; do
  name="$(basename "$fx" .json)"
  golden="$here/golden/$name.txt"
  if [ ! -f "$golden" ]; then echo "MISS $name (no golden)"; fail=$((fail+1)); continue; fi
  got="$(bash "$script" < "$fx" | tr -d '\r')"
  want="$(tr -d '\r' < "$golden")"
  if [ "$got" = "$want" ]; then
    echo "ok   $name"; pass=$((pass+1))
  else
    echo "FAIL $name"
    diff <(printf '%s\n' "$want" | strip_ansi) <(printf '%s\n' "$got" | strip_ansi) | sed 's/^/     /'
    fail=$((fail+1))
  fi
done
echo "---- render: $pass passed, $fail failed ----"
[ "$fail" -eq 0 ]
