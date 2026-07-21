#!/usr/bin/env bash
# Claude Code status line — STYLE=B (statusline-wizard SELECTIONS=1,2,3,10).
# bash implementation, macOS bash 3.2 safe.
#
# Reads Claude Code's JSON from stdin; prints four lines:
#   ───────────────────────────────────────────────────────────────────────
#   | 🤖 [model] | <bar> pct% | ⏳ [5h reset] pct% | 📅 [7d reset] pct% |
#   | 📁 dir | 🌿 branch | 💰 $cost | ⏱️ elapsed |
#   ───────────────────────────────────────────────────────────────────────

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

now=$(date +%s)

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
# RENDER — STYLE=B : two pipe-delimited lines bracketed by ── rules
# ===========================================================================
rule="${WHITE}"; i=0; while [ "$i" -lt 71 ]; do rule="${rule}─"; i=$((i+1)); done; rule="${rule}${RESET}"

l1="${PIPE} ${seg_model} ${PIPE}"
is_set "$used_pct"  && l1="${l1} ${seg_ctx} ${PIPE}"
[ -n "$seg_five" ]  && l1="${l1} ${seg_five} ${PIPE}"
[ -n "$seg_week" ]  && l1="${l1} ${seg_week} ${PIPE}"

l2="${PIPE} ${seg_dir} ${PIPE} ${seg_branch} ${PIPE} ${seg_cost} ${PIPE} ${seg_timer} ${PIPE}"

printf '%s\n%s\n%s\n%s' "$l1" "$rule" "$l2" "$rule"
