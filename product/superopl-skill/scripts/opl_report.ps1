param(
    [string]$OutputPath,
    [int]$UpcomingDays = 7,
    [int]$RecentClosedDays = 30,
    [string]$ConfigPath = '..\config\skill_config.json',
    [string]$ProfileName
)

. "$PSScriptRoot\common.ps1"
$profile = Get-SuperOPLConfig -ConfigPath $ConfigPath -ProfileName $ProfileName

$oplResp = Invoke-SuperOPLApi -Method GET -Endpoint "/api/opls/$($profile.opl_id)/" -Profile $profile
$opl = Get-SuperOPLData -ApiResponse $oplResp
$tasksResp = Invoke-SuperOPLApi -Method GET -Endpoint "/api/opls/$($profile.opl_id)/tasks/" -Profile $profile
$tasks = Get-SuperOPLTasks -TasksApiResponse $tasksResp

$today = (Get-Date).Date
$upcomingLimit = $today.AddDays($UpcomingDays)
$recentLimit = $today.AddDays(-$RecentClosedDays)

$openTasks = @($tasks | Where-Object { [string]$_.status -eq '0' })
$closedTasks = @($tasks | Where-Object { [string]$_.status -eq '1' })

$overdue = @()
$upcoming = @()
foreach ($t in $openTasks) {
    $dueRaw = if ($t.endDate) { $t.endDate } else { $null }
    if (-not $dueRaw) { continue }
    $due = [datetime]$dueRaw
    if ($due.Date -lt $today) { $overdue += $t }
    elseif ($due.Date -le $upcomingLimit) { $upcoming += $t }
}

$recentClosed = @($closedTasks | Where-Object {
    $_.changeStatusDate -and ([datetime]$_.changeStatusDate -ge $recentLimit)
})

if (-not $OutputPath) {
    $date = Get-Date -Format 'yyyy-MM-dd'
    $OutputPath = Join-Path $PSScriptRoot "..\knowledge_base\reports\OPL_$($profile.opl_id)_report_$date.md"
}

$lines = @()
$lines += ("# OPL Status Report - {0}" -f $opl.name)
$lines += "**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  **OPL ID:** $($profile.opl_id)"
$lines += ""
$lines += "## Summary"
$lines += "| Total | Open | Closed | Overdue | Upcoming |"
$lines += "|------:|-----:|-------:|--------:|---------:|"
$lines += "| $($tasks.Count) | $($openTasks.Count) | $($closedTasks.Count) | $($overdue.Count) | $($upcoming.Count) |"
$lines += ""

$lines += "## Overdue Tasks"
$lines += "| ID | Subject | Responsible | Due Date |"
$lines += "|---:|---------|-------------|----------|"
foreach ($t in $overdue) {
    $lines += "| $($t.id) | $($t.subject) | $($t.responsible) | $($t.endDate) |"
}
if ($overdue.Count -eq 0) { $lines += "| - | None | - | - |" }
$lines += ""

$lines += "## Upcoming Tasks (within $UpcomingDays days)"
$lines += "| ID | Subject | Responsible | Due Date |"
$lines += "|---:|---------|-------------|----------|"
foreach ($t in $upcoming) {
    $lines += "| $($t.id) | $($t.subject) | $($t.responsible) | $($t.endDate) |"
}
if ($upcoming.Count -eq 0) { $lines += "| - | None | - | - |" }
$lines += ""

$lines += "## Risks"
$lines += "| ID | Name | Category | Status |"
$lines += "|---:|------|----------|--------|"
$risks = if ($opl -and ($opl.PSObject.Properties.Name -contains 'risks')) { @($opl.risks) } else { @() }
foreach ($r in $risks) {
    $lines += "| $($r.id) | $($r.name) | $($r.category) | $($r.status) |"
}
if (@($risks).Count -eq 0) { $lines += "| - | None | - | - |" }
$lines += ""

$lines += "## Recently Closed (last $RecentClosedDays days)"
$lines += "| ID | Subject | Responsible | Close Date |"
$lines += "|---:|---------|-------------|------------|"
foreach ($t in $recentClosed) {
    $lines += "| $($t.id) | $($t.subject) | $($t.responsible) | $($t.changeStatusDate) |"
}
if ($recentClosed.Count -eq 0) { $lines += "| - | None | - | - |" }

$outputDir = Split-Path -Parent $OutputPath
if (-not (Test-Path $outputDir)) { New-Item -ItemType Directory -Path $outputDir -Force | Out-Null }
Set-Content -Path $OutputPath -Value ($lines -join "`n") -Encoding UTF8

Write-Host "Report generated: $OutputPath" -ForegroundColor Green
