param(
    [Parameter(Mandatory = $true)] [string]$Query,
    [int]$Top = 10,
    [ValidateSet('table','json','markdown')] [string]$Output = 'table',
    [string]$ConfigPath = '..\config\skill_config.json',
    [string]$ProfileName
)

. "$PSScriptRoot\common.ps1"
$profile = Get-SuperOPLConfig -ConfigPath $ConfigPath -ProfileName $ProfileName

# Fetch all tasks live from API (no local index dependency)
Write-Host "Fetching tasks from API..." -ForegroundColor DarkGray
$tasksResp = Invoke-SuperOPLApi -Method GET -Endpoint "/api/opls/$($profile.opl_id)/tasks/" -Profile $profile
$tasks = Get-SuperOPLTasks -TasksApiResponse $tasksResp
Write-Host "Total tasks fetched: $($tasks.Count)" -ForegroundColor DarkGray

$q = $Query.Trim().ToLower()
$tokens = @($q -split '\s+' | Where-Object { $_.Length -ge 2 })

function Score-Task {
    param($t)
    $text = ("$($t.subject) $($t.raw.description)").ToLower()
    $score = 0
    foreach ($tk in $tokens) {
        if ($text -match [regex]::Escape($tk)) { $score++ }
    }
    return $score
}

function Get-TypeName([int]$code) {
    switch ($code) {
        1 { 'task' } 2 { 'decision' } 3 { 'information' }
        4 { 'review' } 6 { 'problem' } 7 { 'measure' } default { 'unknown' }
    }
}

function Get-StatusName([string]$s) {
    if ($s -eq '0') { return 'open' } elseif ($s -eq '1') { return 'closed' } else { return $s }
}

# Score and filter all matching tasks
$scored = @($tasks | ForEach-Object {
    $s = Score-Task $_
    if ($s -gt 0) {
        [PSCustomObject]@{
            score       = $s
            taskId      = $_.id
            subject     = $_.subject
            type        = [int]$_.type
            typeName    = Get-TypeName([int]$_.type)
            status      = $_.status
            statusName  = Get-StatusName($_.status)
            responsible = $_.responsible
            owner       = $_.owner
            taskStart   = $_.taskStart
            endDate     = $_.endDate
            description = [string]$_.raw.description
        }
    }
} | Where-Object { $_ }) | Sort-Object score -Descending

$problems  = @($scored | Where-Object { $_.type -eq 6 } | Select-Object -First $Top)
$measures  = @($scored | Where-Object { $_.type -eq 7 } | Select-Object -First $Top)
$tasks_hit = @($scored | Where-Object { $_.type -eq 1 } | Select-Object -First $Top)
$all_hits  = @($scored | Select-Object -First $Top)

# Frequency count: how many times similar subject appeared as problem
$freqMap = @{}
foreach ($t in @($tasks | Where-Object { [int]$_.type -eq 6 })) {
    foreach ($tk in $tokens) {
        if ($t.subject -and $t.subject.ToLower() -match [regex]::Escape($tk)) {
            if (-not $freqMap.ContainsKey($tk)) { $freqMap[$tk] = 0 }
            $freqMap[$tk]++
        }
    }
}

$result = [PSCustomObject]@{
    query        = $Query
    generated_at = (Get-Date).ToString('s')
    total_tasks  = $tasks.Count
    matched      = $scored.Count
    keyword_frequency = $freqMap
    problems     = $problems
    measures     = $measures
    tasks        = $tasks_hit
    all_hits     = $all_hits
}

if ($Output -eq 'json') {
    $result | ConvertTo-Json -Depth 10
    exit 0
}

if ($Output -eq 'markdown') {
    $lines = @()
    $lines += "# OPL Analysis: $Query"
    $lines += ""
    $lines += "- Generated: $($result.generated_at)"
    $lines += "- Total tasks in OPL: $($result.total_tasks)"
    $lines += "- Matched tasks: $($result.matched)"
    $lines += ""

    if ($freqMap.Count -gt 0) {
        $lines += "## Keyword Frequency (in Problems)"
        foreach ($k in $freqMap.Keys) { $lines += "- **$k**: $($freqMap[$k]) occurrence(s)" }
        $lines += ""
    }

    if ($problems.Count -gt 0) {
        $lines += "## Related Problems"
        $lines += "| ID | Subject | Status | Responsible | Due Date |"
        $lines += "|---:|---|---|---|---|"
        foreach ($r in $problems) {
            $lines += "| $($r.taskId) | $($r.subject) | $($r.statusName) | $($r.responsible) | $($r.endDate) |"
        }
        $lines += ""
    }

    if ($measures.Count -gt 0) {
        $lines += "## Related Measures"
        $lines += "| ID | Subject | Status | Responsible | Due Date |"
        $lines += "|---:|---|---|---|---|"
        foreach ($r in $measures) {
            $lines += "| $($r.taskId) | $($r.subject) | $($r.statusName) | $($r.responsible) | $($r.endDate) |"
        }
        $lines += ""
    }

    if ($tasks_hit.Count -gt 0) {
        $lines += "## Related Tasks"
        $lines += "| ID | Subject | Status | Responsible | Due Date |"
        $lines += "|---:|---|---|---|---|"
        foreach ($r in $tasks_hit) {
            $lines += "| $($r.taskId) | $($r.subject) | $($r.statusName) | $($r.responsible) | $($r.endDate) |"
        }
    }

    ($lines -join "`n")
    exit 0
}

# table output (default)
Write-Host ""
Write-Host "Query: $Query" -ForegroundColor Cyan
Write-Host "Total tasks in OPL: $($result.total_tasks) | Matched: $($result.matched)"

if ($freqMap.Count -gt 0) {
    Write-Host "`nKeyword frequency (in Problems):" -ForegroundColor Green
    foreach ($k in $freqMap.Keys) { Write-Host "  $k : $($freqMap[$k]) occurrence(s)" }
}

if ($problems.Count -gt 0) {
    Write-Host "`nRelated Problems:" -ForegroundColor Yellow
    $problems | Select-Object taskId, subject, statusName, responsible, endDate, score | Format-Table -AutoSize | Out-Host
}

if ($measures.Count -gt 0) {
    Write-Host "`nRelated Measures:" -ForegroundColor Magenta
    $measures | Select-Object taskId, subject, statusName, responsible, endDate, score | Format-Table -AutoSize | Out-Host
}

if ($tasks_hit.Count -gt 0) {
    Write-Host "`nRelated Tasks:" -ForegroundColor DarkCyan
    $tasks_hit | Select-Object taskId, subject, statusName, responsible, endDate, score | Format-Table -AutoSize | Out-Host
}

if ($scored.Count -eq 0) {
    Write-Host "No matching tasks found for query: $Query" -ForegroundColor Red
}
