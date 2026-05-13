param(
    [ValidateSet('task')] [string]$Entity = 'task',
    [Parameter(Mandatory = $true)] [string]$Subject,
    [ValidateSet('task','decision','information','review','problem','measure')] [string]$Type = 'task',
    [Parameter(Mandatory = $true)] [string]$Responsible,
    [string]$Owner,
    [string]$TaskStart = (Get-Date -Format 'yyyy-MM-dd'),
    [string]$DueDate,
    [string]$Description,
    [ValidateSet('A','B','C','D','E')] [string]$Prio,
    [string]$ConfigPath = '..\config\skill_config.json',
    [string]$ProfileName
)

. "$PSScriptRoot\common.ps1"
$profile = Get-SuperOPLConfig -ConfigPath $ConfigPath -ProfileName $ProfileName

if (-not $DueDate) {
    $DueDate = Read-Host 'DueDate is mandatory by API. Input YYYY-MM-DD (or 2099-12-31 for no deadline)'
}
if (-not $Owner) { $Owner = $profile.user_login }

$payload = [ordered]@{
    loginUser   = $profile.user_login
    owner       = $Owner
    type        = (Convert-TypeToCode -Type $Type)
    subject     = $Subject
    taskStart   = $TaskStart
    endDate     = $DueDate
    responsible = $Responsible
}

if ($Description) { $payload.description = $Description }
if ($Prio) { $payload.prio = $Prio }

$response = Invoke-SuperOPLApi -Method POST -Endpoint "/api/opls/$($profile.opl_id)/tasks/" -Profile $profile -Body $payload

Write-Host "Created task successfully." -ForegroundColor Green
$response | ConvertTo-Json -Depth 10
