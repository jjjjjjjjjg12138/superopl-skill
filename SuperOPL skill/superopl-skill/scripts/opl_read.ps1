param(
    [ValidateSet('opl','tasks','risks','all')] [string]$Entity = 'tasks',
    [string]$Status,
    [string]$Responsible,
    [string]$Type,
    [string]$FromDate,
    [string]$ToDate,
    [ValidateSet('table','json')] [string]$Output = 'table',
    [string]$ConfigPath = '..\config\skill_config.json',
    [string]$ProfileName
)

. "$PSScriptRoot\common.ps1"
$profile = Get-SuperOPLConfig -ConfigPath $ConfigPath -ProfileName $ProfileName

function Filter-Tasks([array]$tasks) {
    $filtered = $tasks
    if ($Status) { $filtered = $filtered | Where-Object { [string]$_.status -eq [string]$Status } }
    if ($Responsible) { $filtered = $filtered | Where-Object { [string]$_.responsible -like "*$Responsible*" } }
    if ($Type) {
        $typeCode = Convert-TypeToCode -Type $Type
        $filtered = $filtered | Where-Object { [int]$_.type -eq $typeCode }
    }
    if ($FromDate) {
        $from = [datetime]$FromDate
        $filtered = $filtered | Where-Object { $_.taskStart -and ([datetime]$_.taskStart -ge $from) }
    }
    if ($ToDate) {
        $to = [datetime]$ToDate
        $filtered = $filtered | Where-Object { $_.endDate -and ([datetime]$_.endDate -le $to) }
    }
    return @($filtered)
}

$result = [ordered]@{}

if ($Entity -eq 'opl' -or $Entity -eq 'all' -or $Entity -eq 'risks') {
    $oplResp = Invoke-SuperOPLApi -Method GET -Endpoint "/api/opls/$($profile.opl_id)/" -Profile $profile
    $opl = Get-SuperOPLData -ApiResponse $oplResp
    if ($Entity -eq 'opl') { $result.opl = $opl }
    if ($Entity -eq 'all') { $result.opl = $opl }
    if ($Entity -eq 'risks' -or $Entity -eq 'all') {
        $risks = if ($opl -and ($opl.PSObject.Properties.Name -contains 'risks')) { @($opl.risks) } else { @() }
        $result.risks = $risks
    }
}

if ($Entity -eq 'tasks' -or $Entity -eq 'all') {
    $tasksResp = Invoke-SuperOPLApi -Method GET -Endpoint "/api/opls/$($profile.opl_id)/tasks/" -Profile $profile
    $tasks = Get-SuperOPLTasks -TasksApiResponse $tasksResp
    $result.tasks = Filter-Tasks -tasks $tasks
}

if ($Output -eq 'json') {
    $result | ConvertTo-Json -Depth 20
    exit 0
}

if ($result.tasks) {
    $result.tasks |
        Select-Object id, subject, type, status, responsible, owner, endDate, reminderState |
        Format-Table -AutoSize | Out-Host
}
if (($result.Contains('risks')) -and $result.risks -and $result.risks.Count -gt 0) {
    Write-Host "\nRisks:" -ForegroundColor Yellow
    $result.risks | Select-Object id, name, category, status | Format-Table -AutoSize | Out-Host
}
if ($result.Contains('opl') -and $result.opl) {
    Write-Host "\nOPL: $($result.opl.name) (ID: $($profile.opl_id))" -ForegroundColor Cyan
}
