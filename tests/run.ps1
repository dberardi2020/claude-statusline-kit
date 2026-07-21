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

# The statusline emits UTF-8. PS 5.1 decodes a child process's stdout using
# [Console]::OutputEncoding, which in a real Windows console is the OEM codepage
# (IBM437/1252) -- so every emoji came back as mojibake and all 7 goldens failed.
# CI's runner happens to default to UTF-8, which is why this passed there and only
# broke on an actual desktop. Pin both directions to *BOM-less* UTF-8: the plain
# [Text.Encoding]::UTF8 has emitBOM=true, which is what prefixed a BOM onto the
# child's stdin and made the JSON unparseable.
$prevOut = [Console]::OutputEncoding
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
$OutputEncoding           = New-Object System.Text.UTF8Encoding $false
try {

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

} finally { [Console]::OutputEncoding = $prevOut }
if ($fail -ne 0) { exit 1 }
