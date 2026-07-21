param([switch]$Install, [switch]$Setup)
# ---------------------------------------------------------------------------
# Claude Code statusline — PowerShell implementation (Windows, PS 5.1-safe).
#
# Two modes:
#   • render  — Claude Code pipes its session JSON on stdin; prints the statusline.
#   • install — `statusline.ps1 -Install` copies this script into ~/.claude and
#               wires it into ~/.claude/settings.json (backs up first).
#
# Rendered output — two pipe-delimited lines bracketed by rules:
#   | 🤖 model | <bar> pct% | ⏳ [5h reset] pct% | 📅 [7d reset] pct% |
#   | 📁 dir | 🌿 branch | 💰 cost | ⏱️ elapsed |
# (Astral-plane emoji built via ConvertFromUtf32 to stay PS 5.1-safe.)
# ---------------------------------------------------------------------------

if ($Install -or $Setup) {
    $ErrorActionPreference = 'Stop'
    $claudeDir = Join-Path $HOME '.claude'
    $hadClaudeDir = Test-Path $claudeDir
    if (-not $hadClaudeDir) { New-Item -ItemType Directory -Path $claudeDir | Out-Null }
    $dest = Join-Path $claudeDir 'statusline.ps1'
    if ($PSCommandPath -ne $dest) { Copy-Item -LiteralPath $PSCommandPath -Destination $dest -Force }
    $settings = Join-Path $claudeDir 'settings.json'
    if (-not (Test-Path $settings)) { '{}' | Set-Content -LiteralPath $settings -Encoding UTF8 }
    $bak = "$settings.bak-" + (Get-Date -Format 'yyyyMMddHHmmss')
    Copy-Item -LiteralPath $settings -Destination $bak -Force
    try { $cfg = (Get-Content -Raw -LiteralPath $settings | ConvertFrom-Json) }
    catch { Write-Error "settings.json isn't valid JSON — left untouched (backup: $bak)"; exit 1 }
    if ($null -eq $cfg) { $cfg = [pscustomobject]@{} }
    $exe = if ($PSVersionTable.PSVersion.Major -ge 6) { 'pwsh' } else { 'powershell' }
    $newCmd = "$exe -NoProfile -ExecutionPolicy Bypass -File `"$dest`""
    # Note any statusLine already configured, so we never silently clobber it.
    $existingCmd = if ($cfg.PSObject.Properties.Name -contains 'statusLine') { $cfg.statusLine.command } else { $null }
    $sl  = [pscustomobject]@{ type = 'command'; command = $newCmd }
    if ($cfg.PSObject.Properties.Name -contains 'statusLine') { $cfg.statusLine = $sl }
    else { $cfg | Add-Member -NotePropertyName statusLine -NotePropertyValue $sl }
    ($cfg | ConvertTo-Json -Depth 20) | Set-Content -LiteralPath $settings -Encoding UTF8
    Write-Host "OK  statusline installed -> $dest"
    Write-Host "OK  settings.json wired (backup: $bak)"
    if ($existingCmd -and $existingCmd -ne $newCmd) {
        Write-Warning "Replaced an existing statusLine:"
        Write-Warning "    was: $existingCmd"
        Write-Warning "    now: $newCmd"
        Write-Warning "  To keep the old one, restore $bak"
    } elseif ($existingCmd) {
        Write-Host "  (refreshed your existing Statusline Kit install)"
    }
    if (-not (Get-Command claude -ErrorAction SilentlyContinue) -and -not $hadClaudeDir) {
        Write-Warning "Claude Code wasn't detected (no prior ~/.claude and 'claude' not on PATH)."
        Write-Warning "Config is in place; install Claude Code from https://claude.com/claude-code and the statusline appears once it runs."
    } else {
        Write-Host "    Restart Claude Code or open a new session to see it."
    }
    exit 0
}

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$raw  = [Console]::In.ReadToEnd()
$data = $raw | ConvertFrom-Json

function Get-Safe {
    param($obj, [string[]]$path, $default = "")
    try {
        $val = $obj
        foreach ($key in $path) { $val = $val.$key }
        if ($null -eq $val) { return $default }
        return $val
    } catch { return $default }
}

# --- Block-bar characters -------------------------------------------------
$filled_char = [char]0x2593   # ▓
$empty_char  = [char]0x2591   # ░

# --- ANSI colours ---------------------------------------------------------
$esc    = [char]27
$green  = "$($esc)[32m"
$yellow = "$($esc)[33m"
$red    = "$($esc)[31m"
$reset  = "$($esc)[0m"
$white  = "$($esc)[97m"

$pipe = "$($white)|$($reset)"

# --- Emoji ----------------------------------------------------------------
# Defined as char sequences; literal emoji above U+FFFF get mangled in PS 5.1.
$e_robot  = [char]::ConvertFromUtf32(0x1F916)   # 🤖 model
$e_clock  = [char]0x23F3                        # ⏳ 5h window (hourglass)
$e_cal    = [char]::ConvertFromUtf32(0x1F4C5)   # 📅 7d window
$e_folder = [char]::ConvertFromUtf32(0x1F4C1)   # 📁 cwd
$e_leaf   = [char]::ConvertFromUtf32(0x1F33F)   # 🌿 git branch
$e_money  = [char]::ConvertFromUtf32(0x1F4B0)   # 💰 cost
$e_timer  = "$([char]0x23F1)$([char]0xFE0F)"    # ⏱️ elapsed (stopwatch)

# ===========================================================================
# LINE 1 — model · context bar+% · 5h limit · 7d limit
# ===========================================================================
$parts = @()

# 1. Model name — bracketed; strip context-size annotation "(1M context)" etc.
$model = Get-Safe $data @("model","display_name") "?"
$model = ($model -replace '\s*\([^)]*\)\s*', '').Trim()
$parts += "$e_robot $($white)[$model]$($reset)"

# 2 + 3. Context bar with % (combined, coloured)
$pct    = [int](Get-Safe $data @("context_window","used_percentage") "0")
$filled = [int]($pct * 10 / 100)
$empty  = 10 - $filled
$bar    = ($filled_char.ToString() * $filled) + ($empty_char.ToString() * $empty)
$colour = if ($pct -le 60) { $green } elseif ($pct -le 85) { $yellow } else { $red }
$parts += "$($colour)$($bar) $($pct)%$($reset)"

# 10. Rate limits — ⏳ 5-hour window, 📅 7-day window : [reset-countdown] pct%
$r15h_pct   = [int][double](Get-Safe $data @("rate_limits","five_hour","used_percentage") "0")
$r17d_pct   = [int][double](Get-Safe $data @("rate_limits","seven_day","used_percentage") "0")
$r15h_reset = [double](Get-Safe $data @("rate_limits","five_hour","resets_at") "0")
$r17d_reset = [double](Get-Safe $data @("rate_limits","seven_day","resets_at") "0")
$now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()

$diff5 = [math]::Max(0, [int]($r15h_reset - $now))
$h5    = [int]($diff5 / 3600)
$m5    = [int](($diff5 % 3600) / 60)

$diff7 = [math]::Max(0, [int]($r17d_reset - $now))
$d7    = [int]($diff7 / 86400)
$h7    = [int](($diff7 % 86400) / 3600)

# Colour each window by its used-percentage (green ≤60, yellow ≤85, else red)
$c5h = if ($r15h_pct -le 60) { $green } elseif ($r15h_pct -le 85) { $yellow } else { $red }
$c7d = if ($r17d_pct -le 60) { $green } elseif ($r17d_pct -le 85) { $yellow } else { $red }

$parts += "$e_clock $($white)[${h5}h${m5}m]$($reset) $($c5h)$($r15h_pct)%$($reset)"
$parts += "$e_cal $($white)[${d7}d${h7}h]$($reset) $($c7d)$($r17d_pct)%$($reset)"

# ===========================================================================
# LINE 2 — cwd · branch · cost · elapsed
# ===========================================================================
$line2 = @()

$cwd     = Get-Safe $data @("cwd") ""
$cwdleaf = Split-Path -Leaf $cwd
$line2  += "$e_folder $($white)$cwdleaf$($reset)"

# git branch of the cwd ("---" when not a repo)
if ($cwd) {
    $branch = (& git -C $cwd branch --show-current 2>$null)
    $branchlabel = if ($branch) { $branch.Trim() } else { "---" }
} else {
    $branchlabel = "---"
}
$line2 += "$e_leaf $($white)$branchlabel$($reset)"

# cost — total_cost_usd, formatted $F2
$costUsd = [double](Get-Safe $data @("cost","total_cost_usd") "0")
$cost    = "`$" + $costUsd.ToString("F2")
$line2  += "$e_money $($white)$cost$($reset)"

# elapsed — total_duration_ms → Hh Mm (drops the hour when < 1h)
$elapsed = [double](Get-Safe $data @("cost","total_duration_ms") "0")
$durH    = [int]($elapsed / 3600000)
$durMin  = [int](($elapsed % 3600000) / 60000)
$dur     = if ($durH -gt 0) { "${durH}h${durMin}m" } else { "${durMin}m" }
$line2  += "$e_timer $($white)$dur$($reset)"

# ===========================================================================
# RENDER — two pipe-delimited lines bracketed by horizontal rules
# ===========================================================================
$rule = $white + ([string][char]0x2500 * 71) + $reset            # ── × 71

Write-Host "$pipe $($parts -join " $pipe ") $pipe"
Write-Host "$rule"
Write-Host "$pipe $($line2 -join " $pipe ") $pipe"
Write-Host "$rule"
