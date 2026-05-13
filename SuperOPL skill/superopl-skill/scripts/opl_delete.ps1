param(
    [Parameter(Mandatory = $true)] [string]$TaskId,
    [string]$ConfigPath = '..\config\skill_config.json',
    [string]$ProfileName
)

. "$PSScriptRoot\common.ps1"
$profile = Get-SuperOPLConfig -ConfigPath $ConfigPath -ProfileName $ProfileName

$payload = @{ loginUser = $profile.user_login }
$response = Invoke-SuperOPLApi -Method DELETE -Endpoint "/api/opls/$($profile.opl_id)/tasks/$TaskId" -Profile $profile -Body $payload

if ($response.result -eq 1 -or $response.result -eq $true) {
    Write-Host "Deleted task $TaskId successfully." -ForegroundColor Green
} else {
    Write-Host "Delete request returned non-success result for task $TaskId." -ForegroundColor Yellow
}
$response | ConvertTo-Json -Depth 10
