param(
    [int]$UpcomingDays = 7,
    [ValidateSet('table','json')] [string]$Output = 'table',
    [string]$ConfigPath = '..\config\skill_config.json',
    [string]$ProfileName
)

. "$PSScriptRoot\common.ps1"
$profile = Get-SuperOPLConfig -ConfigPath $ConfigPath -ProfileName $ProfileName
$tasksResp = Invoke-SuperOPLApi -Method GET -Endpoint "/api/opls/$($profile.opl_id)/tasks/" -Profile $profile
$tasks = Get-SuperOPLTasks -TasksApiResponse $tasksResp

$today = (Get-Date).Date
$upcomingLimit = $today.AddDays($UpcomingDays)
$openTasks = @($tasks | Where-Object { [string]$_.status -eq '0' })

$overdue = @()
$upcoming = @()
$normal = @()

foreach ($t in $openTasks) {
    $dueRaw = if ($t.endDate) { $t.endDate } else { $null }
    if (-not $dueRaw) { $normal += $t; continue }

    $due = [datetime]$dueRaw
    if ($due.Date -lt $today) { $overdue += $t; continue }
    if ($due.Date -le $upcomingLimit) { $upcoming += $t; continue }
    $normal += $t
}

$result = [ordered]@{
    opl_id        = $profile.opl_id
    generated_at  = (Get-Date).ToString('s')
    total         = $tasks.Count
    open          = $openTasks.Count
    closed        = @($tasks | Where-Object { [string]$_.status -eq '1' }).Count
    overdue_count = $overdue.Count
    upcoming_count= $upcoming.Count
    overdue       = $overdue
    upcoming      = $upcoming
}

if ($Output -eq 'json') {
    $result | ConvertTo-Json -Depth 20
    exit 0
}

Write-Host "OPL $($profile.opl_id) tracking summary" -ForegroundColor Cyan
Write-Host "Open: $($result.open) | Closed: $($result.closed) | Overdue: $($result.overdue_count) | Upcoming: $($result.upcoming_count)"

if ($overdue.Count -gt 0) {
    Write-Host "\n[OVERDUE]" -ForegroundColor Red
    $overdue | Select-Object id, subject, responsible, owner, endDate | Format-Table -AutoSize | Out-Host
}
if ($upcoming.Count -gt 0) {
    Write-Host "\n[UPCOMING]" -ForegroundColor Yellow
    $upcoming | Select-Object id, subject, responsible, owner, endDate | Format-Table -AutoSize | Out-Host
}
