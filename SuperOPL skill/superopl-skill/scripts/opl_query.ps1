param(
    [string]$ConfigPath = '..\config\skill_config.json',
    [string]$ProfileName,
    [string]$Keywords,
    [string]$Type,
    [string]$Responsible,
    [string]$Owner,
    [string]$Status,
    [string]$DaysBack,
    [string]$TaskId,
    [ValidateSet('table','json','markdown')]
    [string]$Output = 'table',
    [int]$Top = 50
)

. "$PSScriptRoot\common.ps1"
$profile = Get-SuperOPLConfig -ConfigPath $ConfigPath -ProfileName $ProfileName

# Fetch all tasks
$tasksResp = Invoke-SuperOPLApi -Method GET -Endpoint "/api/opls/$($profile.opl_id)/tasks/" -Profile $profile
$tasks = Get-SuperOPLTasks -TasksApiResponse $tasksResp

$filtered = $tasks

# Filter by TaskId (exact)
if ($TaskId) {
    $filtered = @($filtered | Where-Object { $_.id -eq $TaskId })
}

# Filter by Keywords (subject + description)
if ($Keywords) {
    $kwList = @($Keywords -split '[,\s]+' | Where-Object { $_ })
    $filtered = @($filtered | Where-Object {
        $t = $_
        $text = "$($t.subject) $($t.raw.description)"
        $match = $false
        foreach ($kw in $kwList) {
            if ($text -match [regex]::Escape($kw)) { $match = $true; break }
        }
        $match
    })
}

# Filter by Type
if ($Type) {
    $typeMap = @{ 'task'=1; 'decision'=2; 'information'=3; 'review'=4; 'problem'=6; 'measure'=7 }
    $typeCode = $null
    if ($typeMap.ContainsKey($Type.ToLower())) { $typeCode = $typeMap[$Type.ToLower()] }
    elseif ($Type -match '^\d+$') { $typeCode = [int]$Type }
    if ($null -ne $typeCode) {
        $filtered = @($filtered | Where-Object { [int]$_.type -eq $typeCode })
    }
}

# Filter by Responsible
if ($Responsible) {
    $filtered = @($filtered | Where-Object { $_.responsible -like "*$Responsible*" })
}

# Filter by Owner
if ($Owner) {
    $filtered = @($filtered | Where-Object { $_.owner -like "*$Owner*" })
}

# Filter by Status
if ($Status) {
    $statusCode = if ($Status -eq 'open') { '0' } elseif ($Status -eq 'closed') { '1' } else { $Status }
    $filtered = @($filtered | Where-Object { [string]$_.status -eq $statusCode })
}

# Filter by DaysBack
if ($DaysBack -and $DaysBack -match '^\d+$') {
    $cutoff = (Get-Date).AddDays(-[int]$DaysBack).Date
    $filtered = @($filtered | Where-Object {
        if ($_.taskStart) {
            try { [datetime]::Parse($_.taskStart) -ge $cutoff } catch { $true }
        } else { $true }
    })
}

# Cap results
if ($Top -gt 0 -and $filtered.Count -gt $Top) {
    $filtered = @($filtered | Select-Object -First $Top)
}

$typeNameMap = @{ 1='task'; 2='decision'; 3='information'; 4='review'; 6='problem'; 7='measure' }

function Get-TypeName([int]$code) {
    if ($typeNameMap.ContainsKey($code)) { return $typeNameMap[$code] } else { return 'unknown' }
}

function Get-StatusName([string]$s) {
    if ($s -eq '0') { return 'open' } elseif ($s -eq '1') { return 'closed' } else { return $s }
}

if ($filtered.Count -eq 0) {
    Write-Host "No matching tasks found."
    exit 0
}

Write-Host "Matched: $($filtered.Count) task(s)"

switch ($Output) {
    'json' {
        $out = @($filtered | ForEach-Object {
            [PSCustomObject]@{
                taskId      = $_.id
                subject     = $_.subject
                type        = Get-TypeName([int]$_.type)
                status      = Get-StatusName($_.status)
                responsible = $_.responsible
                owner       = $_.owner
                taskStart   = $_.taskStart
                endDate     = $_.endDate
                description = [string]$_.raw.description
            }
        })
        $out | ConvertTo-Json -Depth 5
    }
    'markdown' {
        foreach ($t in $filtered) {
            Write-Host "## [$($t.id)] $($t.subject)"
            Write-Host ""
            Write-Host "- Type: $(Get-TypeName([int]$t.type))"
            Write-Host "- Status: $(Get-StatusName($t.status))"
            Write-Host "- Responsible: $($t.responsible)"
            Write-Host "- Owner: $($t.owner)"
            Write-Host "- Start: $($t.taskStart)  Due: $($t.endDate)"
            if ($t.raw.description) { Write-Host "- Description: $($t.raw.description)" }
            Write-Host ""
        }
    }
    default {
        # table
        $filtered | ForEach-Object {
            [PSCustomObject]@{
                ID          = $_.id
                Subject     = if ($_.subject.Length -gt 50) { $_.subject.Substring(0,50) + '...' } else { $_.subject }
                Type        = Get-TypeName([int]$_.type)
                Status      = Get-StatusName($_.status)
                Responsible = $_.responsible
                DueDate     = $_.endDate
            }
        } | Format-Table -AutoSize
    }
}
