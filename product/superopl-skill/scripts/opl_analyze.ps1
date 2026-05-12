param(
    [Parameter(Mandatory = $true)] [string]$Query,
    [int]$Top = 5,
    [ValidateSet('table','json','markdown')] [string]$Output = 'table',
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

$wikiDir = Join-Path $kbPath 'wiki'
$wikiEntitiesPath = Join-Path $wikiDir 'entities.json'
$wikiEdgesPath = Join-Path $wikiDir 'edges.json'
$wikiEvidencePath = Join-Path $wikiDir 'evidence.json'
$wikiPagesPath = Join-Path $wikiDir 'pages.json'
$wikiRevisionsPath = Join-Path $wikiDir 'revisions.json'
$confirmedLinksPath = Join-Path $wikiDir 'confirmed_links.json'

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
$confirmedLinks = if (Test-Path $confirmedLinksPath) { @((Get-Content -Raw -Path $confirmedLinksPath | ConvertFrom-Json).items) } else { @() }

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

$problemIds = @($problemCandidates | ForEach-Object { [string]$_.id })
$relatedLinks = @($links | Where-Object { $problemIds -contains [string]$_.problem_id })
$confirmedForProblems = @($confirmedLinks | Where-Object { $problemIds -contains [string]$_.problem_id })

$inferredFiltered = $relatedLinks
if ($confirmedForProblems.Count -gt 0) {
    $confirmedKeys = @($confirmedForProblems | ForEach-Object { "{0}-{1}" -f $_.problem_id, $_.measure_id })
    $inferredFiltered = @($relatedLinks | Where-Object { ($confirmedKeys -notcontains ("{0}-{1}" -f $_.problem_id, $_.measure_id)) })
}

$entityProblemIds = @($problemIds | ForEach-Object { "task:$_" })
$pmEdges = @($wikiEdges | Where-Object { $_.relation -eq 'problem_measure' -and ($entityProblemIds -contains [string]$_.source_entity_id) })
$measureEntities = if ($pmEdges.Count -gt 0) {
    @($wikiEntities | Where-Object { ($pmEdges.target_entity_id) -contains [string]$_.entity_id })
} else { @() }

$matchedEvents = if (@($events).Count -gt 0 -and @($problemIds).Count -gt 0) {
    @($events | Where-Object { $problemIds -contains [string]$_.id })
} else { @() }

$evMatches = @($wikiEvidence | Where-Object {
    $_.payload -and $_.payload.subject -and ([string]$_.payload.subject).ToLower().Contains($q)
})

$pageHits = @($wikiPages | Where-Object { $_.title -and ([string]$_.title).ToLower().Contains($q) })
$latestRevision = if (@($wikiRevisions).Count -gt 0) { $wikiRevisions | Select-Object -Last 1 } else { $null }

$result = [PSCustomObject]@{
    query = $Query
    generated_at = (Get-Date).ToString('s')
    summary = [PSCustomObject]@{
        matched_problems = @($problemCandidates).Count
        wiki_entities = @($wikiEntities).Count
        wiki_edges = @($wikiEdges).Count
        wiki_evidence = @($wikiEvidence).Count
        confirmed_links = @($confirmedLinks).Count
        latest_revision = $latestRevision
    }
    frequency_hits = @($subjectHits | Sort-Object count -Descending | Select-Object -First $Top)
    problem_candidates = @($problemCandidates | Select-Object -First $Top id, subject, status, responsible, endDate)
    confirmed_measures = @($confirmedForProblems | Select-Object -First $Top problem_id, measure_id, note, confirmed_by, confirmed_at)
    inferred_measures = @($inferredFiltered | Sort-Object score -Descending | Select-Object -First $Top problem_id, measure_id, measure_subject, score, common_tokens)
    wiki_problem_measure_edges = @($pmEdges | Select-Object -First $Top source_entity_id, target_entity_id, weight, inferred_by)
    wiki_measure_entities = @($measureEntities | Select-Object -First $Top entity_id, name, due_date, responsible)
    problem_events = @($matchedEvents | Select-Object -First $Top id, subject, status, taskStart, endDate)
    evidence_trace = @($evMatches | Select-Object -First $Top evidence_id, source_task_id, captured_at)
    page_hits = @($pageHits | Select-Object -First $Top page_id, title, kind, source_task_id)
}

if ($Output -eq 'json') {
    $result | ConvertTo-Json -Depth 30
    exit 0
}

if ($Output -eq 'markdown') {
    $lines = @()
    $lines += "# OPL Knowledge Analysis"
    $lines += ""
    $lines += "- Query: $($result.query)"
    $lines += "- Generated: $($result.generated_at)"
    $lines += "- Matched Problems: $($result.summary.matched_problems)"
    $lines += "- Confirmed Links: $($result.summary.confirmed_links)"
    $lines += ""

    $lines += "## Problem Candidates"
    $lines += "| ID | Subject | Status | Responsible | Due Date |"
    $lines += "|---:|---|---:|---|---|"
    if (@($result.problem_candidates).Count -eq 0) {
        $lines += "| - | None | - | - | - |"
    } else {
        foreach ($r in $result.problem_candidates) {
            $lines += "| $($r.id) | $($r.subject) | $($r.status) | $($r.responsible) | $($r.endDate) |"
        }
    }
    $lines += ""

    $lines += "## Confirmed Measures (Priority)"
    $lines += "| Problem ID | Measure ID | Note | Confirmed By | Confirmed At |"
    $lines += "|---:|---:|---|---|---|"
    if (@($result.confirmed_measures).Count -eq 0) {
        $lines += "| - | - | None | - | - |"
    } else {
        foreach ($r in $result.confirmed_measures) {
            $lines += "| $($r.problem_id) | $($r.measure_id) | $($r.note) | $($r.confirmed_by) | $($r.confirmed_at) |"
        }
    }
    $lines += ""

    $lines += "## Inferred Measures (Fallback)"
    $lines += "| Problem ID | Measure ID | Measure Subject | Score |"
    $lines += "|---:|---:|---|---:|"
    if (@($result.inferred_measures).Count -eq 0) {
        $lines += "| - | - | None | - |"
    } else {
        foreach ($r in $result.inferred_measures) {
            $lines += "| $($r.problem_id) | $($r.measure_id) | $($r.measure_subject) | $($r.score) |"
        }
    }

    ($lines -join "`n")
    exit 0
}

# table output (default)
Write-Host "Analysis query: $Query" -ForegroundColor Cyan
Write-Host "Matched problems: $($result.summary.matched_problems)"
Write-Host "Wiki entities: $($result.summary.wiki_entities), edges: $($result.summary.wiki_edges), evidence: $($result.summary.wiki_evidence), confirmed_links: $($result.summary.confirmed_links)"
if ($result.summary.latest_revision) {
    Write-Host "Latest revision: #$($result.summary.latest_revision.revision_id) at $($result.summary.latest_revision.synced_at)"
}

if (@($result.frequency_hits).Count -gt 0) {
    Write-Host "\nFrequency by matched subject:" -ForegroundColor Green
    $result.frequency_hits | Format-Table -AutoSize | Out-Host
}
if (@($result.problem_candidates).Count -gt 0) {
    Write-Host "\nProblem candidates:" -ForegroundColor Yellow
    $result.problem_candidates | Format-Table -AutoSize | Out-Host
}
if (@($result.confirmed_measures).Count -gt 0) {
    Write-Host "\nConfirmed historical measures (priority):" -ForegroundColor Green
    $result.confirmed_measures | Format-Table -AutoSize | Out-Host
}
if (@($result.inferred_measures).Count -gt 0) {
    Write-Host "\nRelated historical measures (inferred fallback):" -ForegroundColor Magenta
    $result.inferred_measures | Format-Table -AutoSize | Out-Host
}
if (@($result.wiki_problem_measure_edges).Count -gt 0) {
    Write-Host "\nWiki graph links (problem -> measure):" -ForegroundColor DarkMagenta
    $result.wiki_problem_measure_edges | Format-Table -AutoSize | Out-Host
}
if (@($result.wiki_measure_entities).Count -gt 0) {
    Write-Host "\nMeasure entities from wiki graph:" -ForegroundColor DarkYellow
    $result.wiki_measure_entities | Format-Table -AutoSize | Out-Host
}
if (@($result.problem_events).Count -gt 0) {
    Write-Host "\nProblem event history:" -ForegroundColor DarkCyan
    $result.problem_events | Format-Table -AutoSize | Out-Host
}
if (@($result.evidence_trace).Count -gt 0) {
    Write-Host "\nEvidence trace (top):" -ForegroundColor Gray
    $result.evidence_trace | Format-Table -AutoSize | Out-Host
}
if (@($result.page_hits).Count -gt 0) {
    Write-Host "\nWiki pages matched:" -ForegroundColor Blue
    $result.page_hits | Format-Table -AutoSize | Out-Host
}