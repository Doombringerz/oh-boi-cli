# ohboi.ps1: ADHD focus tracker + fail logger
# https://github.com/Doombringerz/oh-boi-cli
# For when shit gets done, and for when it doesn't.

$script:OhBoiLogPath   = Join-Path $env:USERPROFILE ".oh-boi-log.md"
$script:OhBoiStatePath = Join-Path $env:USERPROFILE ".oh-boi-state.json"

function Get-OhBoiState {
    if (Test-Path $script:OhBoiStatePath) {
        Get-Content $script:OhBoiStatePath -Raw | ConvertFrom-Json
    } else {
        $null
    }
}

function Set-OhBoiState {
    param($State)
    if ($null -eq $State) {
        if (Test-Path $script:OhBoiStatePath) {
            Remove-Item $script:OhBoiStatePath -Force
        }
    } else {
        $State | ConvertTo-Json | Set-Content $script:OhBoiStatePath -Encoding UTF8
    }
}

function Add-OhBoiLogEntry {
    param([string]$Line)
    if (-not (Test-Path $script:OhBoiLogPath)) {
        @"
# OH BOI Log

For when shit gets done, and for when it doesn't.

"@ | Set-Content $script:OhBoiLogPath -Encoding UTF8
    }
    Add-Content $script:OhBoiLogPath -Value $Line -Encoding UTF8
}

function Format-OhBoiDuration {
    param([TimeSpan]$Span)
    if ($Span.TotalHours -ge 1) {
        return "{0}h {1}m" -f [int]$Span.TotalHours, $Span.Minutes
    } else {
        return "{0}m" -f [int]$Span.TotalMinutes
    }
}

function Show-OhBoiHelp {
    @"

OH BOI: ADHD focus tracker and fail logger
For when shit gets done, and for when it doesn't.

Usage:
  ohboi start [tag]           Start a focus session (optional tag: game, bot, vid, code, biz)
  ohboi end [note]            End current session, optionally note what got done
  ohboi lazy [tag] [note]     Log low-energy moment (shows the rhythm)
  ohboi fail "<description>"  Log a fail moment (channel content material)
  ohboi stats                 Weekly summary
  ohboi list [n]              Last N entries (default 10)
  ohboi share                 Copy last entry to clipboard
  ohboi help                  This screen

Log:   $($env:USERPROFILE)\.oh-boi-log.md
State: $($env:USERPROFILE)\.oh-boi-state.json

"@ | Write-Host
}

function ohboi {
    param(
        [Parameter(Position=0)][string]$Command,
        [Parameter(Position=1)][string]$Arg1,
        [Parameter(Position=2)][string]$Arg2
    )

    switch ($Command) {
        "start" {
            $state = Get-OhBoiState
            if ($state -and $state.active) {
                Write-Host "OH BOI: a session is already running (started $($state.startTime), tag: $($state.tag)). Run 'ohboi end' first." -ForegroundColor Yellow
                return
            }
            $tag = if ($Arg1) { $Arg1 } else { "general" }
            $newState = [PSCustomObject]@{
                active    = $true
                startTime = (Get-Date).ToString("o")
                tag       = $tag
            }
            Set-OhBoiState $newState
            Write-Host "OH BOI: session started [$tag]" -ForegroundColor Green
        }

        "end" {
            $state = Get-OhBoiState
            if (-not $state -or -not $state.active) {
                Write-Host "OH BOI: no active session. Run 'ohboi start' first." -ForegroundColor Yellow
                return
            }
            $start    = [DateTime]::Parse($state.startTime)
            $end      = Get-Date
            $duration = $end - $start
            $note     = if ($Arg1) { ", $Arg1" } else { "" }
            $line     = "- **$($start.ToString('yyyy-MM-dd HH:mm'))** to **$($end.ToString('HH:mm'))** ($(Format-OhBoiDuration $duration)) [$($state.tag)] FOCUS$note"
            Add-OhBoiLogEntry $line
            Set-OhBoiState $null
            Write-Host "OH BOI: session ended. Duration: $(Format-OhBoiDuration $duration)" -ForegroundColor Green
        }

        "lazy" {
            $tag  = if ($Arg1) { $Arg1 } else { "general" }
            $note = if ($Arg2) { ", $Arg2" } else { "" }
            $line = "- **$(Get-Date -Format 'yyyy-MM-dd HH:mm')** [$tag] LAZY$note"
            Add-OhBoiLogEntry $line
            Write-Host "OH BOI: lazy mode logged [$tag]" -ForegroundColor Cyan
        }

        "fail" {
            if (-not $Arg1) {
                Write-Host 'OH BOI: usage: ohboi fail "<description>"' -ForegroundColor Yellow
                return
            }
            $line = "- **$(Get-Date -Format 'yyyy-MM-dd HH:mm')** FAIL, $Arg1"
            Add-OhBoiLogEntry $line
            Write-Host "OH BOI: fail logged. (For the OH BOI montage.)" -ForegroundColor Magenta
        }

        "stats" {
            if (-not (Test-Path $script:OhBoiLogPath)) {
                Write-Host "OH BOI: no log yet. Run 'ohboi start' to begin." -ForegroundColor Yellow
                return
            }
            $weekAgo      = (Get-Date).AddDays(-7)
            $focusCount   = 0
            $lazyCount    = 0
            $failCount    = 0
            $totalMinutes = 0
            $lines        = Get-Content $script:OhBoiLogPath
            foreach ($l in $lines) {
                if ($l -match "^\- \*\*(\d{4}-\d{2}-\d{2} \d{2}:\d{2})\*\*") {
                    $date = [DateTime]::ParseExact($matches[1], "yyyy-MM-dd HH:mm", $null)
                    if ($date -ge $weekAgo) {
                        if ($l -match "FOCUS") {
                            $focusCount++
                            if ($l -match "\((\d+)h (\d+)m\)") {
                                $totalMinutes += ([int]$matches[1] * 60) + [int]$matches[2]
                            } elseif ($l -match "\((\d+)m\)") {
                                $totalMinutes += [int]$matches[1]
                            }
                        } elseif ($l -match "LAZY") { $lazyCount++ }
                          elseif ($l -match "FAIL") { $failCount++ }
                    }
                }
            }
            $hours   = [math]::Floor($totalMinutes / 60)
            $minutes = $totalMinutes % 60
            Write-Host ""
            Write-Host "OH BOI, last 7 days" -ForegroundColor Green
            Write-Host "  Focus sessions: $focusCount" -ForegroundColor Cyan
            Write-Host "  Total focus:    ${hours}h ${minutes}m" -ForegroundColor Cyan
            Write-Host "  Lazy moments:   $lazyCount" -ForegroundColor Yellow
            Write-Host "  Fails:          $failCount" -ForegroundColor Magenta
            Write-Host ""
        }

        "share" {
            if (-not (Test-Path $script:OhBoiLogPath)) {
                Write-Host "OH BOI: no log yet." -ForegroundColor Yellow
                return
            }
            $last = Get-Content $script:OhBoiLogPath | Where-Object { $_ -match "^\- \*\*" } | Select-Object -Last 1
            if ($last) {
                $last | Set-Clipboard
                Write-Host "OH BOI: last entry copied to clipboard." -ForegroundColor Green
                Write-Host $last -ForegroundColor Gray
            } else {
                Write-Host "OH BOI: no entries yet." -ForegroundColor Yellow
            }
        }

        "list" {
            if (-not (Test-Path $script:OhBoiLogPath)) {
                Write-Host "OH BOI: no log yet." -ForegroundColor Yellow
                return
            }
            $n       = if ($Arg1 -match "^\d+$") { [int]$Arg1 } else { 10 }
            $entries = Get-Content $script:OhBoiLogPath | Where-Object { $_ -match "^\- \*\*" } | Select-Object -Last $n
            Write-Host ""
            Write-Host "OH BOI, last $n entries" -ForegroundColor Green
            $entries | ForEach-Object { Write-Host $_ }
            Write-Host ""
        }

        "help"    { Show-OhBoiHelp }
        ""        { Show-OhBoiHelp }
        default   { Show-OhBoiHelp }
    }
}
