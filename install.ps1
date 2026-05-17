# install.ps1: install ohboi to your PowerShell profile
# Run: irm https://raw.githubusercontent.com/Doombringerz/oh-boi-cli/main/install.ps1 | iex

$ErrorActionPreference = "Stop"

$installDir = Join-Path $env:USERPROFILE ".oh-boi-cli"
$ohboiPath  = Join-Path $installDir "ohboi.ps1"

# Clone or update
if (Test-Path $installDir) {
    Write-Host "OH BOI: updating existing install at $installDir" -ForegroundColor Yellow
    Push-Location $installDir
    try { git pull --quiet } finally { Pop-Location }
} else {
    Write-Host "OH BOI: cloning to $installDir" -ForegroundColor Green
    git clone --quiet https://github.com/Doombringerz/oh-boi-cli.git $installDir
}

# Ensure profile exists
if (-not (Test-Path $PROFILE)) {
    New-Item -ItemType File -Path $PROFILE -Force | Out-Null
    Write-Host "OH BOI: created PowerShell profile at $PROFILE" -ForegroundColor Cyan
}

# Add source line if not already there
$sourceLine    = ". `"$ohboiPath`""
$profileBody   = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
if (-not $profileBody -or $profileBody -notmatch [regex]::Escape($sourceLine)) {
    Add-Content -Path $PROFILE -Value "`n# OH BOI focus tracker`n$sourceLine`n"
    Write-Host "OH BOI: added to your PowerShell profile." -ForegroundColor Green
} else {
    Write-Host "OH BOI: already in your PowerShell profile." -ForegroundColor Cyan
}

# Source it now so it works in the current session
. $ohboiPath

Write-Host ""
Write-Host "OH BOI installed. Type 'ohboi help' to get started." -ForegroundColor Green
Write-Host ""
