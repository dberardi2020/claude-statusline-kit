#!/usr/bin/env bash
# Claude Code statusline — bash implementation (macOS/Linux, bash 3.2-safe).
#
# Two modes:
#   • render  — Claude Code pipes its session JSON on stdin; prints the statusline.
#   • install — `bash statusline-command.sh --install` copies this script into
#               ~/.claude and wires it into ~/.claude/settings.json (backs up first).
#
# Rendered output — two pipe-delimited lines bracketed by rules:
#   ───────────────────────────────────────────────────────────────────────
#   | 🤖 [model] | <bar> pct% | ⏳ [5h reset] pct% | 📅 [7d reset] pct% |
#   | 📁 dir | 🌿 branch | 💰 $cost | ⏱️ elapsed |
#   ───────────────────────────────────────────────────────────────────────

# --- install mode ----------------------------------------------------------
if [ "$1" = "--install" ] || [ "$1" = "install" ] || [ "$1" = "--setup" ]; then
  set -e
  src="${BASH_SOURCE[0]}"
  case "$src" in /*) : ;; *) src="$(cd "$(dirname "$src")" && pwd)/$(basename "$src")" ;; esac
  [ -f "$src" ] || { echo "install: run this as a file, not via a pipe." >&2; exit 1; }
  command -v jq >/dev/null 2>&1 || { echo "install: 'jq' is required (e.g. 'brew install jq' / 'apt install jq')." >&2; exit 1; }
  claude_dir="$HOME/.claude"
  had_claude_dir=0; [ -d "$claude_dir" ] && had_claude_dir=1
  mkdir -p "$claude_dir"
  dest="$claude_dir/statusline-command.sh"
  [ "$src" = "$dest" ] || cp "$src" "$dest"
  chmod +x "$dest"
  settings="$claude_dir/settings.json"
  [ -f "$settings" ] || echo '{}' > "$settings"
  # Note any statusLine already configured, so we never silently clobber it.
  existing_cmd=$(jq -r '.statusLine.command // empty' "$settings" 2>/dev/null || true)
  bak="$settings.bak-$(date +%Y%m%d%H%M%S)"; cp "$settings" "$bak"
  tmp="$settings.tmp.$$"
  if jq --arg cmd "$dest" '.statusLine = {type:"command", command:$cmd}' "$settings" > "$tmp" 2>/dev/null; then
    mv "$tmp" "$settings"
  else
    rm -f "$tmp"
    echo "install: settings.json isn't valid JSON — left untouched (backup: $bak)." >&2
    echo "Add manually:  \"statusLine\": { \"type\": \"command\", \"command\": \"$dest\" }" >&2
    exit 1
  fi
  echo "✓ statusline installed → $dest"
  echo "✓ settings.json wired (backup: $bak)"
  if [ -n "$existing_cmd" ] && [ "$existing_cmd" != "$dest" ]; then
    echo "⚠ replaced an existing statusLine:" >&2
    echo "    was: $existing_cmd" >&2
    echo "    now: $dest" >&2
    echo "  To keep the old one, restore $bak" >&2
  elif [ -n "$existing_cmd" ]; then
    echo "  (refreshed your existing Statusline Kit install)"
  fi
  if ! command -v claude >/dev/null 2>&1 && [ "$had_claude_dir" -eq 0 ]; then
    echo "note: Claude Code wasn't detected (no prior ~/.claude and 'claude' not on PATH)." >&2
    echo "      Config is in place; install Claude Code from https://claude.com/claude-code" >&2
    echo "      and the statusline appears once it runs." >&2
  else
    echo "  Restart Claude Code or open a new session to see it."
  fi
  exit 0
fi

# A curious run with no args and no piped JSON would otherwise hang on `cat`.
if [ -t 0 ] && [ "$#" -eq 0 ]; then
  echo "This is a Claude Code statusline command; it expects session JSON on stdin." >&2
  echo "To install it:  bash \"$0\" --install" >&2
  exit 0
fi

input=$(cat)

# Parse each field as its own line — avoids IFS/delimiter edge cases in bash 3.2
{
  IFS= read -r model
  IFS= read -r cwd
  IFS= read -r used_pct
  IFS= read -r five_reset
  IFS= read -r five_pct
  IFS= read -r week_reset
  IFS= read -r week_pct
  IFS= read -r cost_usd
  IFS= read -r dur_ms
} < <(echo "$input" | jq -r '
  (.model.display_name                     // "?"),
  (.workspace.current_dir // .cwd          // ""),
  (.context_window.used_percentage         // "" | tostring),
  (.rate_limits.five_hour.resets_at        // "" | tostring),
  (.rate_limits.five_hour.used_percentage  // "" | tostring),
  (.rate_limits.seven_day.resets_at        // "" | tostring),
  (.rate_limits.seven_day.used_percentage  // "" | tostring),
  (.cost.total_cost_usd                    // "" | tostring),
  (.cost.total_duration_ms                 // "" | tostring)
')

# --- Colours ---
GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'
WHITE=$'\033[97m'; RESET=$'\033[0m'
PIPE="${WHITE}|${RESET}"

# green <=60, yellow <=85, else red  (matches the PowerShell thresholds)
color_for_pct() {
  local p="$1"
  if   [ "$p" -le 60 ]; then printf '%s' "$GREEN"
  elif [ "$p" -le 85 ]; then printf '%s' "$YELLOW"
  else                       printf '%s' "$RED"
  fi
}

is_set() { [ -n "$1" ] && [ "$1" != "null" ]; }

# ===========================================================================
# LINE 1 — model · context bar+% · 5h limit · 7d limit
# ===========================================================================

# 1. Model — strip "(1M context)" annotation, bracket it
model_clean=$(printf '%s' "$model" | sed -E 's/ *\([^)]*\) *//g')
seg_model="🤖 ${WHITE}[${model_clean}]${RESET}"

# 2+3. Context bar (10 cells: ▓ filled / ░ empty) + percent
seg_ctx=""
if is_set "$used_pct"; then
  p=$(printf '%.0f' "$used_pct" 2>/dev/null); [ -z "$p" ] && p=0
  filled=$(( (p + 5) / 10 )); [ "$filled" -gt 10 ] && filled=10; [ "$filled" -lt 0 ] && filled=0
  empty=$(( 10 - filled ))
  c=$(color_for_pct "$p")
  bar=""
  i=0; while [ "$i" -lt "$filled" ]; do bar="${bar}▓"; i=$((i+1)); done
  i=0; while [ "$i" -lt "$empty"  ]; do bar="${bar}░"; i=$((i+1)); done
  seg_ctx="${c}${bar} ${p}%${RESET}"
fi

now=${SL_NOW:-$(date +%s)}   # SL_NOW overrides the clock for deterministic tests

# 10a. 5-hour window : ⏳ [Hh Mm] pct%   (countdown white, percent coloured)
seg_five=""
if is_set "$five_reset"; then
  s=$(( ${five_reset%.*} - now )); [ "$s" -lt 0 ] && s=0
  h=$(( s / 3600 )); m=$(( (s % 3600) / 60 ))
  seg_five="⏳ ${WHITE}[${h}h${m}m]${RESET}"
  if is_set "$five_pct"; then
    p=$(printf '%.0f' "$five_pct" 2>/dev/null); [ -z "$p" ] && p=0
    seg_five="${seg_five} $(color_for_pct "$p")${p}%${RESET}"
  fi
fi

# 10b. 7-day window : 📅 [Dd Hh] pct%
seg_week=""
if is_set "$week_reset"; then
  s=$(( ${week_reset%.*} - now )); [ "$s" -lt 0 ] && s=0
  d=$(( s / 86400 )); h=$(( (s % 86400) / 3600 ))
  seg_week="📅 ${WHITE}[${d}d${h}h]${RESET}"
  if is_set "$week_pct"; then
    p=$(printf '%.0f' "$week_pct" 2>/dev/null); [ -z "$p" ] && p=0
    seg_week="${seg_week} $(color_for_pct "$p")${p}%${RESET}"
  fi
fi

# ===========================================================================
# LINE 2 — cwd · branch · cost · elapsed
# ===========================================================================

# 📁 directory leaf
dir_name="$(basename "$cwd" 2>/dev/null)"; [ -z "$dir_name" ] && dir_name="—"
seg_dir="📁 ${WHITE}${dir_name}${RESET}"

# 🌿 git branch (walk up for .git/HEAD; "---" when not a repo)
branch=""; git_dir="$cwd"
while [ -n "$git_dir" ] && [ "$git_dir" != "/" ]; do
  if [ -f "$git_dir/.git/HEAD" ]; then
    head_content=$(cat "$git_dir/.git/HEAD" 2>/dev/null)
    if [[ "$head_content" == ref:* ]]; then branch="${head_content#ref: refs/heads/}"
    else branch="${head_content:0:7}"; fi
    break
  fi
  git_dir="$(dirname "$git_dir")"
done
[ -z "$branch" ] && branch="---"
seg_branch="🌿 ${WHITE}${branch}${RESET}"

# 💰 session cost
cost_fmt="0.00"
if is_set "$cost_usd"; then
  cf=$(printf '%.2f' "$cost_usd" 2>/dev/null); [ -n "$cf" ] && cost_fmt="$cf"
fi
seg_cost="💰 ${WHITE}\$${cost_fmt}${RESET}"

# ⏱️ elapsed (total_duration_ms → Hh Mm, drops the hour when < 1h)
dur="0m"
if is_set "$dur_ms"; then
  ms=${dur_ms%.*}
  dh=$(( ms / 3600000 )); dm=$(( (ms % 3600000) / 60000 ))
  if [ "$dh" -gt 0 ]; then dur="${dh}h${dm}m"; else dur="${dm}m"; fi
fi
seg_timer="⏱️ ${WHITE}${dur}${RESET}"

# ===========================================================================
# RENDER — two pipe-delimited lines bracketed by ── rules
# ===========================================================================
rule="${WHITE}"; i=0; while [ "$i" -lt 71 ]; do rule="${rule}─"; i=$((i+1)); done; rule="${rule}${RESET}"

l1="${PIPE} ${seg_model} ${PIPE}"
is_set "$used_pct"  && l1="${l1} ${seg_ctx} ${PIPE}"
[ -n "$seg_five" ]  && l1="${l1} ${seg_five} ${PIPE}"
[ -n "$seg_week" ]  && l1="${l1} ${seg_week} ${PIPE}"

l2="${PIPE} ${seg_dir} ${PIPE} ${seg_branch} ${PIPE} ${seg_cost} ${PIPE} ${seg_timer} ${PIPE}"

printf '%s\n%s\n%s\n%s' "$l1" "$rule" "$l2" "$rule"
