param(
    [Parameter(Mandatory = $true)] [string]$Query,
    [int]$Top = 5,
    [string]$ConfigPath = '..\config\skill_config.json',
    [string]$ProfileName
)

. "$PSScriptRoot\common.ps1"
$profile = Get-SuperOPLConfig -ConfigPath $ConfigPath -ProfileName $ProfileName
$kbPath = Get-KnowledgeBasePath -Profile $profile

$indexPath = Join-Path $kbPath 'index.json'
$freqPath = Join-Path (Join-Path $kbPath 'statistics') 'frequency.json'
$eventsPath = Join-Path (Join-Path $kbPath 'statistics') 'problem_events.json'
$linksPath = Join-Path (Join-Path $kbPath 'links') 'problem_measure_links.json'

# llm-wiki files
$wikiDir = Join-Path $kbPath 'wiki'
$wikiEntitiesPath = Join-Path $wikiDir 'entities.json'
$wikiEdgesPath = Join-Path $wikiDir 'edges.json'
$wikiEvidencePath = Join-Path $wikiDir 'evidence.json'
$wikiPagesPath = Join-Path $wikiDir 'pages.json'
$wikiRevisionsPath = Join-Path $wikiDir 'revisions.json'

if (-not (Test-Path $indexPath)) { throw "index.json not found. Run opl_knowledge_sync.ps1 first." }
if (-not (Test-Path $freqPath)) { throw "frequency.json not found. Run opl_knowledge_sync.ps1 first." }

$index = Get-Content -Raw -Path $indexPath | ConvertFrom-Json
$freq = Get-Content -Raw -Path $freqPath | ConvertFrom-Json
$events = if (Test-Path $eventsPath) { @((Get-Content -Raw -Path $eventsPath | ConvertFrom-Json).items) } else { @() }
$links = if (Test-Path $linksPath) { @((Get-Content -Raw -Path $linksPath | ConvertFrom-Json).links) } else { @() }

$wikiEntities = if (Test-Path $wikiEntitiesPath) { @((Get-Content -Raw -Path $wikiEntitiesPath | ConvertFrom-Json).items) } else { @() }
$wikiEdges = if (Test-Path $wikiEdgesPath) { @((Get-Content -Raw -Path $wikiEdgesPath | ConvertFrom-Json).items) } else { @() }
$wikiEvidence = if (Test-Path $wikiEvidencePath) { @((Get-Content -Raw -Path $wikiEvidencePath | ConvertFrom-Json).items) } else { @() }
$wikiPages = if (Test-Path $wikiPagesPath) { @((Get-Content -Raw -Path $wikiPagesPath | ConvertFrom-Json).items) } else { @() }
$wikiRevisions = if (Test-Path $wikiRevisionsPath) { @(Get-Content -Raw -Path $wikiRevisionsPath | ConvertFrom-Json) } else { @() }

$q = $Query.Trim().ToLower()

$problemCandidates = @($index.items | Where-Object {
    [int]$_.type -eq 6 -and $_.subject -and ([string]$_.subject).ToLower().Contains($q)
})

$subjectHits = @()
foreach ($prop in $freq.by_subject.PSObject.Properties) {
    if ($prop.Name -like "*$q*") {
        $subjectHits += [PSCustomObject]@{
            subject_key = $prop.Name
            count       = [int]$prop.Value.count
            ids         = @($prop.Value.ids)
        }
    }
}

Write-Host "Analysis query: $Query" -ForegroundColor Cyan
Write-Host "Matched problems: $($problemCandidates.Count)"
Write-Host "Wiki entities: $(@($wikiEntities).Count), edges: $(@($wikiEdges).Count), evidence: $(@($wikiEvidence).Count)"
if (@($wikiRevisions).Count -gt 0) {
    $latest = $wikiRevisions | Select-Object -Last 1
    Write-Host "Latest revision: #$($latest.revision_id) at $($latest.synced_at)"
}

if ($subjectHits.Count -gt 0) {
    Write-Host "\nFrequency by matched subject:" -ForegroundColor Green
    $subjectHits | Sort-Object count -Descending | Select-Object -First $Top | Format-Table -AutoSize | Out-Host
}

if ($problemCandidates.Count -gt 0) {
    Write-Host "\nProblem candidates:" -ForegroundColor Yellow
    $problemCandidates | Select-Object -First $Top id, subject, status, responsible, endDate | Format-Table -AutoSize | Out-Host
}

$problemIds = @($problemCandidates | ForEach-Object { [string]$_.id })
$relatedLinks = @($links | Where-Object { $problemIds -contains [string]$_.problem_id })
if ($relatedLinks.Count -gt 0) {
    Write-Host "\nRelated historical measures (inferred):" -ForegroundColor Magenta
    $relatedLinks | Sort-Object score -Descending | Select-Object -First $Top problem_id, measure_id, measure_subject, score, common_tokens | Format-Table -AutoSize | Out-Host
}

# llm-wiki edge traversal
$entityProblemIds = @($problemIds | ForEach-Object { "task:$_" })
$pmEdges = @($wikiEdges | Where-Object { $_.relation -eq 'problem_measure' -and ($entityProblemIds -contains [string]$_.source_entity_id) })
if ($pmEdges.Count -gt 0) {
    Write-Host "\nWiki graph links (problem -> measure):" -ForegroundColor DarkMagenta
    $pmEdges | Select-Object -First $Top source_entity_id, target_entity_id, weight, inferred_by | Format-Table -AutoSize | Out-Host

    $measureEntities = @($wikiEntities | Where-Object { ($pmEdges.target_entity_id) -contains [string]$_.entity_id })
    if ($measureEntities.Count -gt 0) {
        Write-Host "\nMeasure entities from wiki graph:" -ForegroundColor DarkYellow
        $measureEntities | Select-Object -First $Top entity_id, name, due_date, responsible | Format-Table -AutoSize | Out-Host
    }
}

if (@($events).Count -gt 0 -and @($problemIds).Count -gt 0) {
    $matchedEvents = @($events | Where-Object { $problemIds -contains [string]$_.id })
    if (@($matchedEvents).Count -gt 0) {
        Write-Host "\nProblem event history:" -ForegroundColor DarkCyan
        $matchedEvents | Select-Object -First $Top id, subject, status, taskStart, endDate | Format-Table -AutoSize | Out-Host
    }
}

# evidence trace
$evMatches = @($wikiEvidence | Where-Object {
    $_.payload -and $_.payload.subject -and ([string]$_.payload.subject).ToLower().Contains($q)
})
if ($evMatches.Count -gt 0) {
    Write-Host "\nEvidence trace (top):" -ForegroundColor Gray
    $evMatches | Select-Object -First $Top evidence_id, source_task_id, captured_at | Format-Table -AutoSize | Out-Host
}

# page hit summary
$pageHits = @($wikiPages | Where-Object { $_.title -and ([string]$_.title).ToLower().Contains($q) })
if ($pageHits.Count -gt 0) {
    Write-Host "\nWiki pages matched:" -ForegroundColor Blue
    $pageHits | Select-Object -First $Top page_id, title, kind, source_task_id | Format-Table -AutoSize | Out-Host
}