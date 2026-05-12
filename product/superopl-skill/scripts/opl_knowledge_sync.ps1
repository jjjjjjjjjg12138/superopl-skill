param(
    [string]$ConfigPath = '..\config\skill_config.json',
    [string]$ProfileName
)

. "$PSScriptRoot\common.ps1"
$profile = Get-SuperOPLConfig -ConfigPath $ConfigPath -ProfileName $ProfileName
$kbPath = Get-KnowledgeBasePath -Profile $profile

$indexPath = Join-Path $kbPath 'index.json'
$statsDir = Join-Path $kbPath 'statistics'
$freqPath = Join-Path $statsDir 'frequency.json'
$eventsPath = Join-Path $statsDir 'problem_events.json'
$problemsDir = Join-Path $kbPath 'problems'
$reportsDir = Join-Path $kbPath 'reports'
$linksDir = Join-Path $kbPath 'links'

# llm-wiki style storage
$wikiDir = Join-Path $kbPath 'wiki'
$wikiPagesDir = Join-Path $wikiDir 'pages'
$wikiPagesPath = Join-Path $wikiDir 'pages.json'
$wikiChunksPath = Join-Path $wikiDir 'chunks.jsonl'
$wikiEntitiesPath = Join-Path $wikiDir 'entities.json'
$wikiEdgesPath = Join-Path $wikiDir 'edges.json'
$wikiEvidencePath = Join-Path $wikiDir 'evidence.json'
$wikiRevisionsPath = Join-Path $wikiDir 'revisions.json'

foreach ($p in @($kbPath, $statsDir, $problemsDir, $reportsDir, $linksDir, $wikiDir, $wikiPagesDir)) {
    if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
}

$tasksResp = Invoke-SuperOPLApi -Method GET -Endpoint "/api/opls/$($profile.opl_id)/tasks/" -Profile $profile
$tasks = Get-SuperOPLTasks -TasksApiResponse $tasksResp
$now = (Get-Date).ToString('s')

function Get-TypeName([int]$code) {
    switch ($code) {
        1 { 'task' }
        2 { 'decision' }
        3 { 'information' }
        4 { 'review' }
        6 { 'problem' }
        7 { 'measure' }
        default { 'unknown' }
    }
}

# legacy index + frequency
$indexItems = @()
$bySubject = @{}
$byKeyword = @{}
$problemEvents = @()

# llm-wiki artifacts
$wikiPages = @()
$wikiEntities = @()
$wikiEvidence = @()
$wikiEdges = @()
$wikiChunkLines = @()

foreach ($t in $tasks) {
    $typeName = Get-TypeName -code ([int]$t.type)
    $entityId = "task:$($t.id)"
    $pageId = "$typeName-$($t.id)"
    $title = if ($t.subject) { [string]$t.subject } else { "$typeName $($t.id)" }

    $indexItems += [PSCustomObject]@{
        id          = [string]$t.id
        subject     = [string]$t.subject
        type        = [int]$t.type
        status      = [string]$t.status
        responsible = [string]$t.responsible
        owner       = [string]$t.owner
        taskStart   = [string]$t.taskStart
        endDate     = [string]$t.endDate
        updated_at  = $now
    }

    if ([int]$t.type -eq 6) {
        $subjectKey = (($t.subject -replace '\s+', ' ').Trim().ToLower())
        if (-not $subjectKey) { $subjectKey = "problem-$($t.id)" }

        if (-not $bySubject.ContainsKey($subjectKey)) {
            $bySubject[$subjectKey] = [PSCustomObject]@{ count = 0; ids = @() }
        }
        $bySubject[$subjectKey].count = [int]$bySubject[$subjectKey].count + 1
        $bySubject[$subjectKey].ids = @($bySubject[$subjectKey].ids + @([string]$t.id) | Select-Object -Unique)

        $tokens = @($subjectKey.Split(' ') | Where-Object { $_.Length -ge 4 } | Select-Object -Unique)
        foreach ($kw in $tokens) {
            if (-not $byKeyword.ContainsKey($kw)) {
                $byKeyword[$kw] = [PSCustomObject]@{ count = 0; ids = @() }
            }
            $byKeyword[$kw].count = [int]$byKeyword[$kw].count + 1
            $byKeyword[$kw].ids = @($byKeyword[$kw].ids + @([string]$t.id) | Select-Object -Unique)
        }

        $problemEvents += [PSCustomObject]@{
            id          = [string]$t.id
            subject     = [string]$t.subject
            status      = [string]$t.status
            taskStart   = [string]$t.taskStart
            endDate     = [string]$t.endDate
            responsible = [string]$t.responsible
            owner       = [string]$t.owner
        }
    }

    $wikiEntities += [PSCustomObject]@{
        entity_id = $entityId
        name = $title
        entity_type = $typeName
        source_task_id = [string]$t.id
        status = [string]$t.status
        responsible = [string]$t.responsible
        owner = [string]$t.owner
        task_start = [string]$t.taskStart
        due_date = [string]$t.endDate
        updated_at = $now
    }

    $wikiPages += [PSCustomObject]@{
        page_id = $pageId
        title = $title
        kind = $typeName
        entity_id = $entityId
        source_task_id = [string]$t.id
        updated_at = $now
    }

    $body = @(
        "# $title",
        "",
        "- Type: $typeName",
        "- Task ID: $($t.id)",
        "- Status: $($t.status)",
        "- Responsible: $($t.responsible)",
        "- Owner: $($t.owner)",
        "- Start Date: $($t.taskStart)",
        "- Due Date: $($t.endDate)",
        "- Synced At: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    ) -join "`n"

    $safe = (($title -replace '\s+',' ').Trim().ToLower() -replace '[^a-z0-9\- ]','' -replace '\s+','-')
    if ([string]::IsNullOrWhiteSpace($safe)) { $safe = $pageId }
    $pagePath = Join-Path $wikiPagesDir "$safe.md"
    Set-Content -Path $pagePath -Value $body -Encoding UTF8

    $chunks = @($body -split "`n`n")
    $idx = 0
    foreach ($ch in $chunks) {
        if (-not [string]::IsNullOrWhiteSpace($ch)) {
            $chunkObj = [PSCustomObject]@{
                chunk_id = "$pageId-$idx"
                page_id = $pageId
                entity_id = $entityId
                source_task_id = [string]$t.id
                text = $ch
                updated_at = $now
            }
            $wikiChunkLines += ($chunkObj | ConvertTo-Json -Depth 10 -Compress)
            $idx++
        }
    }

    $wikiEvidence += [PSCustomObject]@{
        evidence_id = "ev-task-$($t.id)"
        source_type = 'superopl_task'
        source_task_id = [string]$t.id
        entity_id = $entityId
        captured_at = $now
        payload = [PSCustomObject]@{
            subject = [string]$t.subject
            type = [int]$t.type
            status = [string]$t.status
            responsible = [string]$t.responsible
            owner = [string]$t.owner
            taskStart = [string]$t.taskStart
            endDate = [string]$t.endDate
        }
    }
}

# basic graph edges directly from ownership/responsibility overlap
$byResponsible = @{}
foreach ($e in $wikiEntities) {
    $r = [string]$e.responsible
    if ([string]::IsNullOrWhiteSpace($r)) { continue }
    if (-not $byResponsible.ContainsKey($r)) { $byResponsible[$r] = @() }
    $byResponsible[$r] += $e
}
foreach ($key in $byResponsible.Keys) {
    $group = @($byResponsible[$key])
    if ($group.Count -lt 2) { continue }
    for ($i = 0; $i -lt $group.Count; $i++) {
        for ($j = $i + 1; $j -lt $group.Count; $j++) {
            $wikiEdges += [PSCustomObject]@{
                edge_id = "edge-resp-$($group[$i].entity_id)-$($group[$j].entity_id)"
                relation = 'same_responsible'
                source_entity_id = [string]$group[$i].entity_id
                target_entity_id = [string]$group[$j].entity_id
                weight = 0.3
                inferred_by = 'sync_rule'
                updated_at = $now
            }
        }
    }
}

$index = [PSCustomObject]@{
    updated_at = $now
    opl_id     = [string]$profile.opl_id
    items      = $indexItems
}
$freq = [PSCustomObject]@{
    updated_at = $now
    by_subject = $bySubject
    by_keyword = $byKeyword
}

# rebuild legacy problem pages
Get-ChildItem -Path $problemsDir -Filter '*.md' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
foreach ($p in @($indexItems | Where-Object { [int]$_.type -eq 6 })) {
    $safeName = (($p.subject -replace '\s+',' ').Trim().ToLower() -replace '[^a-z0-9\- ]','' -replace '\s+','-')
    if ([string]::IsNullOrWhiteSpace($safeName)) { $safeName = "problem-$($p.id)" }
    $mdPath = Join-Path $problemsDir "$safeName.md"
    $md = @(
        "# Problem: $($p.subject)",
        "",
        "- ID: $($p.id)",
        "- Status: $($p.status)",
        "- Responsible: $($p.responsible)",
        "- Owner: $($p.owner)",
        "- Start Date: $($p.taskStart)",
        "- Due Date: $($p.endDate)",
        "- Last Synced: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    ) -join "`n"
    Set-Content -Path $mdPath -Value $md -Encoding UTF8
}

# revisions
$revisions = @()
if (Test-Path $wikiRevisionsPath) {
    try {
        $existing = Get-Content -Raw -Path $wikiRevisionsPath | ConvertFrom-Json
        if ($existing) { $revisions = @($existing) }
    } catch {}
}
$nextRev = [int](@($revisions).Count + 1)
$revisions += [PSCustomObject]@{
    revision_id = $nextRev
    opl_id = [string]$profile.opl_id
    synced_at = $now
    item_count = @($indexItems).Count
    page_count = @($wikiPages).Count
    entity_count = @($wikiEntities).Count
    evidence_count = @($wikiEvidence).Count
}

Set-Content -Path $indexPath -Value ($index | ConvertTo-Json -Depth 20) -Encoding UTF8
Set-Content -Path $freqPath -Value ($freq | ConvertTo-Json -Depth 20) -Encoding UTF8
Set-Content -Path $eventsPath -Value (([PSCustomObject]@{ updated_at = $now; items = $problemEvents }) | ConvertTo-Json -Depth 20) -Encoding UTF8

Set-Content -Path $wikiPagesPath -Value (([PSCustomObject]@{ updated_at = $now; items = $wikiPages }) | ConvertTo-Json -Depth 20) -Encoding UTF8
Set-Content -Path $wikiEntitiesPath -Value (([PSCustomObject]@{ updated_at = $now; items = $wikiEntities }) | ConvertTo-Json -Depth 20) -Encoding UTF8
Set-Content -Path $wikiEdgesPath -Value (([PSCustomObject]@{ updated_at = $now; items = $wikiEdges }) | ConvertTo-Json -Depth 20) -Encoding UTF8
Set-Content -Path $wikiEvidencePath -Value (([PSCustomObject]@{ updated_at = $now; items = $wikiEvidence }) | ConvertTo-Json -Depth 20) -Encoding UTF8
Set-Content -Path $wikiRevisionsPath -Value ($revisions | ConvertTo-Json -Depth 20) -Encoding UTF8
if ($wikiChunkLines.Count -gt 0) { Set-Content -Path $wikiChunksPath -Value ($wikiChunkLines -join "`n") -Encoding UTF8 } else { Set-Content -Path $wikiChunksPath -Value '' -Encoding UTF8 }

Write-Host "Knowledge base sync complete." -ForegroundColor Green
Write-Host "Index: $indexPath"
Write-Host "Frequency: $freqPath"
Write-Host "Problem events: $eventsPath"
Write-Host "Wiki pages: $wikiPagesPath"
Write-Host "Wiki entities: $wikiEntitiesPath"
Write-Host "Wiki evidence: $wikiEvidencePath"
Write-Host "Wiki revisions: $wikiRevisionsPath"