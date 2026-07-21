# Render golden tests for the PowerShell statusline.
# Feeds each tests/fixtures/*.json to the script (clock pinned via SL_NOW) and
# compares against tests/golden/*.txt — the SAME goldens the bash tests use, which
# is how cross-platform parity is verified.
#   pwsh tests/run.ps1            (PowerShell 7)
#   powershell -File tests\run.ps1  (Windows PowerShell 5.1)
$here = Split-Path -Parent $PSCommandPath
$repo = Split-Path -Parent $here
$scriptPath = Join-Path $repo 'statusline.ps1'
$exe = if ($PSVersionTable.PSVersion.Major -ge 6) { 'pwsh' } else { 'powershell' }
$env:SL_NOW = '1700000000'
$pass = 0; $fail = 0
Get-ChildItem (Join-Path $here 'fixtures') -Filter *.json | Sort-Object Name | ForEach-Object {
    $name = $_.BaseName
    $golden = Join-Path $here "golden/$name.txt"
    if (-not (Test-Path $golden)) { Write-Host "MISS $name (no golden)"; $script:fail++; return }
    $got  = (Get-Content -Raw -Encoding UTF8 $_.FullName | & $exe -NoProfile -File $scriptPath) -join "`n"
    $got  = ($got  -replace "`r", "").TrimEnd("`n")
    $want = ((Get-Content -Raw -Encoding UTF8 $golden) -replace "`r", "").TrimEnd("`n")
    if ($got -eq $want) { Write-Host "ok   $name"; $script:pass++ }
    else {
        Write-Host "FAIL $name"
        Write-Host "  want: $($want -replace '\x1b\[[0-9;]*m','')"
        Write-Host "  got:  $($got  -replace '\x1b\[[0-9;]*m','')"
        $script:fail++
    }
}
Write-Host "---- render: $pass passed, $fail failed ----"
if ($fail -ne 0) { exit 1 }
