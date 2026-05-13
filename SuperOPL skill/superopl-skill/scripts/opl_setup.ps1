param(
    [string]$ApiKey,
    [string]$OplId,
    [string]$UserLogin,
    [string]$UserName,
    [string]$BaseUrl = 'https://rb-superopl.emea.bosch.com',
    [string]$ProfileName = 'default',
    [string]$ConfigPath = '..\config\skill_config.json'
)

. "$PSScriptRoot\common.ps1"

if (-not $ApiKey) { $ApiKey = Read-Host 'Input SuperOPL API key' }
if (-not $OplId) { $OplId = Read-Host 'Input OPL ID (number in OPL URL)' }
if (-not $UserName -and -not $UserLogin) { $UserName = Read-Host 'Input your display name (for team matching)' }

$temporary = [PSCustomObject]@{
    api_key  = $ApiKey
    opl_id   = $OplId
    user_login = if ($UserLogin) { $UserLogin } else { 'unknown' }
    user_name  = $UserName
    base_url = $BaseUrl.TrimEnd('/')
}

$oplResp = Invoke-SuperOPLApi -Method GET -Endpoint "/api/opls/$OplId/" -Profile $temporary
$opl = Get-SuperOPLData -ApiResponse $oplResp

$team = @()
if ($opl -and ($opl.PSObject.Properties.Name -contains 'access')) {
    foreach ($p in @($opl.access.PSObject.Properties)) {
        $acc = $p.Value
        if ($acc -and (@($acc.PSObject.Properties.Name) -contains 'login')) {
            $team += [PSCustomObject]@{
                login = [string]$acc.login
                name  = if ((@($acc.PSObject.Properties.Name) -contains 'name')) { [string]$acc.name } else { [string]$acc.login }
            }
        }
    }
}

if (-not $UserLogin -and $UserName -and $team.Count -gt 0) {
    $match = $team | Where-Object { $_.name -like "*$UserName*" -or $_.login -like "*$UserName*" } | Select-Object -First 1
    if ($match) { $UserLogin = $match.login }
}

if (-not $UserLogin) {
    if ($team.Count -gt 0) {
        Write-Host 'Team members found:' -ForegroundColor Cyan
        $team | Format-Table -AutoSize | Out-Host
    }
    $UserLogin = Read-Host 'Input your NT login (user_login)'
}

$configObj = [PSCustomObject]@{
    profiles = [PSCustomObject]@{}
    active_profile = $ProfileName
    knowledge_base_path = '.\knowledge_base'
}

$profileObj = [PSCustomObject]@{
    api_key = $ApiKey
    opl_id = [string]$OplId
    user_login = [string]$UserLogin
    user_name = [string]$UserName
    base_url = $BaseUrl.TrimEnd('/')
}

$configObj.profiles | Add-Member -NotePropertyName $ProfileName -NotePropertyValue $profileObj

$resolved = if ([System.IO.Path]::IsPathRooted($ConfigPath)) { $ConfigPath } else { Join-Path $PSScriptRoot $ConfigPath }
Save-SuperOPLConfig -ConfigObject $configObj -ConfigPath $resolved

Write-Host "Setup completed. Config saved to: $resolved" -ForegroundColor Green
Write-Host "Validated OPL: $($opl.name) (ID: $OplId)" -ForegroundColor Green
