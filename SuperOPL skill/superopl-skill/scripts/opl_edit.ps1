param(
    [Parameter(Mandatory = $true)] [string]$TaskId,
    [string]$Subject,
    [string]$DueDate,
    [string]$Responsible,
    [ValidateSet('0','1')] [string]$Status,
    [string]$StatusComment,
    [string]$DueDateChangeReason,
    [string]$ConfigPath = '..\config\skill_config.json',
    [string]$ProfileName
)

. "$PSScriptRoot\common.ps1"
$profile = Get-SuperOPLConfig -ConfigPath $ConfigPath -ProfileName $ProfileName

$allTasksResp = Invoke-SuperOPLApi -Method GET -Endpoint "/api/opls/$($profile.opl_id)/tasks/" -Profile $profile
$allTasks = Get-SuperOPLTasks -TasksApiResponse $allTasksResp
$target = $allTasks | Where-Object { [string]$_.id -eq [string]$TaskId } | Select-Object -First 1
if (-not $target) { throw "Task ID $TaskId not found in OPL $($profile.opl_id)." }

$payload = [ordered]@{
    loginUser   = $profile.user_login
    owner       = $target.owner
    type        = [int]$target.type
    subject     = $target.subject
    taskStart   = if ($target.taskStart) { $target.taskStart } else { (Get-Date -Format 'yyyy-MM-dd') }
    endDate     = if ($target.endDate) { $target.endDate } else { (Get-Date).AddDays(7).ToString('yyyy-MM-dd') }
    responsible = $target.responsible
}

if ($Subject) { $payload.subject = $Subject }
if ($DueDate) { $payload.endDate = $DueDate; $payload.dueDate = $DueDate }
if ($Responsible) { $payload.responsible = $Responsible }
if ($Status) {
    $payload.status = $Status
    $payload.changeStatusDate = (Get-Date -Format 'yyyy-MM-dd')
    if ($StatusComment) { $payload.changeStatusComment = $StatusComment }
}
if ($DueDateChangeReason) { $payload.dueDateChangeReason = $DueDateChangeReason }

$response = Invoke-SuperOPLApi -Method PUT -Endpoint "/api/opls/$($profile.opl_id)/tasks/$TaskId" -Profile $profile -Body $payload

Write-Host "Updated task $TaskId successfully." -ForegroundColor Green
$response | ConvertTo-Json -Depth 10
