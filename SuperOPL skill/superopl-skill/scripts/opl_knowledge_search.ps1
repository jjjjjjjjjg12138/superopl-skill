param(
    [Parameter(Mandatory = $true)] [string]$Query,
    [int]$Top = 10,
    [string]$ConfigPath = '..\config\skill_config.json',
    [string]$ProfileName
)

. "$PSScriptRoot\common.ps1"
$profile = Get-SuperOPLConfig -ConfigPath $ConfigPath -ProfileName $ProfileName
$kbPath = Get-KnowledgeBasePath -Profile $profile
$indexPath = Join-Path $kbPath 'index.json'
$freqPath = Join-Path (Join-Path $kbPath 'statistics') 'frequency.json'

if (-not (Test-Path $indexPath)) { throw "Knowledge index not found: $indexPath. Run opl_knowledge_sync.ps1 first." }
$index = Get-Content -Raw -Path $indexPath | ConvertFrom-Json

$q = $Query.Trim().ToLower()
$hits = @($index.items | Where-Object {
    $_.subject -and ([string]$_.subject).ToLower().Contains($q)
})

Write-Host "Knowledge search query: $Query" -ForegroundColor Cyan
if ($hits.Count -eq 0) {
    Write-Host 'No direct matches in subject index.' -ForegroundColor Yellow
} else {
    $hits | Select-Object -First $Top id, subject, type, status, responsible, endDate | Format-Table -AutoSize | Out-Host
}

if (Test-Path $freqPath) {
    $freq = Get-Content -Raw -Path $freqPath | ConvertFrom-Json
    $ranked = @()
    foreach ($prop in $freq.by_subject.PSObject.Properties) {
        if ($prop.Name -like "*$q*") {
            $ranked += [PSCustomObject]@{ subject = $prop.Name; count = [int]$prop.Value }
        }
    }
    if ($ranked.Count -gt 0) {
        Write-Host "\nFrequency hints:" -ForegroundColor Green
        $ranked | Sort-Object count -Descending | Select-Object -First $Top | Format-Table -AutoSize | Out-Host
    }
}
