param(
    [ValidateSet('add','remove','list')] [string]$Action = 'list',
    [string]$ProblemId,
    [string]$MeasureId,
    [string]$Note,
    [string]$ConfigPath = '..\config\skill_config.json',
    [string]$ProfileName
)

. "$PSScriptRoot\common.ps1"
$profile = Get-SuperOPLConfig -ConfigPath $ConfigPath -ProfileName $ProfileName
$kbPath = Get-KnowledgeBasePath -Profile $profile
$wikiDir = Join-Path $kbPath 'wiki'
if (-not (Test-Path $wikiDir)) { New-Item -ItemType Directory -Path $wikiDir -Force | Out-Null }

$confirmedPath = Join-Path $wikiDir 'confirmed_links.json'
if (-not (Test-Path $confirmedPath)) {
    $seed = [PSCustomObject]@{ updated_at = $null; items = @() }
    Set-Content -Path $confirmedPath -Value ($seed | ConvertTo-Json -Depth 20) -Encoding UTF8
}

$doc = Get-Content -Raw -Path $confirmedPath | ConvertFrom-Json
if (-not $doc.items) { $doc | Add-Member -NotePropertyName items -NotePropertyValue @() -Force }
$items = @($doc.items)

function Normalize-TaskId([string]$id) {
    if (-not $id) { return '' }
    $v = $id.Trim()
    if ($v -like 'task:*') { return $v.Substring(5) }
    return $v
}

$now = (Get-Date).ToString('s')

if ($Action -eq 'add') {
    if (-not $ProblemId -or -not $MeasureId) { throw 'add action requires -ProblemId and -MeasureId' }

    $problemKey = Normalize-TaskId $ProblemId
    $measureKey = Normalize-TaskId $MeasureId
    $linkId = "confirmed-$problemKey-$measureKey"

    $new = [PSCustomObject]@{
        link_id = $linkId
        relation = 'problem_measure'
        problem_id = $problemKey
        measure_id = $measureKey
        source_entity_id = "task:$problemKey"
        target_entity_id = "task:$measureKey"
        confirmed = $true
        confirmed_by = [string]$profile.user_login
        note = if ($Note) { $Note } else { '' }
        confirmed_at = $now
        updated_at = $now
    }

    $items = @($items | Where-Object { [string]$_.link_id -ne $linkId }) + @($new)
    $doc.updated_at = $now
    $doc.items = $items
    Set-Content -Path $confirmedPath -Value ($doc | ConvertTo-Json -Depth 20) -Encoding UTF8

    Write-Host "Confirmed link added: $linkId" -ForegroundColor Green
}
elseif ($Action -eq 'remove') {
    if (-not $ProblemId -or -not $MeasureId) { throw 'remove action requires -ProblemId and -MeasureId' }

    $problemKey = Normalize-TaskId $ProblemId
    $measureKey = Normalize-TaskId $MeasureId
    $linkId = "confirmed-$problemKey-$measureKey"

    $before = @($items).Count
    $items = @($items | Where-Object { [string]$_.link_id -ne $linkId })
    $after = @($items).Count

    $doc.updated_at = $now
    $doc.items = $items
    Set-Content -Path $confirmedPath -Value ($doc | ConvertTo-Json -Depth 20) -Encoding UTF8

    if ($after -lt $before) {
        Write-Host "Confirmed link removed: $linkId" -ForegroundColor Yellow
    } else {
        Write-Host "Confirmed link not found: $linkId" -ForegroundColor Yellow
    }
}

$result = [PSCustomObject]@{
    updated_at = (Get-Date).ToString('s')
    action = $Action
    file = $confirmedPath
    total = @($items).Count
    items = @($items)
}

$result | ConvertTo-Json -Depth 20