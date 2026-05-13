param(
    [int]$DayWindow = 30,
    [string]$ConfigPath = '..\config\skill_config.json',
    [string]$ProfileName
)

. "$PSScriptRoot\common.ps1"
$profile = Get-SuperOPLConfig -ConfigPath $ConfigPath -ProfileName $ProfileName
$kbPath = Get-KnowledgeBasePath -Profile $profile
$linksDir = Join-Path $kbPath 'links'
$wikiDir = Join-Path $kbPath 'wiki'
$wikiEdgesPath = Join-Path $wikiDir 'edges.json'
$wikiEvidencePath = Join-Path $wikiDir 'evidence.json'
if (-not (Test-Path $linksDir)) { New-Item -ItemType Directory -Path $linksDir -Force | Out-Null }
if (-not (Test-Path $wikiDir)) { New-Item -ItemType Directory -Path $wikiDir -Force | Out-Null }

$tasksResp = Invoke-SuperOPLApi -Method GET -Endpoint "/api/opls/$($profile.opl_id)/tasks/" -Profile $profile
$tasks = Get-SuperOPLTasks -TasksApiResponse $tasksResp

$problems = @($tasks | Where-Object { [int]$_.type -eq 6 })
$measures = @($tasks | Where-Object { [int]$_.type -eq 7 })

function Get-Tokens([string]$s) {
    if (-not $s) { return @() }
    return @($s.ToLower() -replace '[^a-z0-9\u4e00-\u9fa5 ]',' ' -split '\s+' | Where-Object { $_ -and $_.Length -ge 2 } | Select-Object -Unique)
}

$links = @()
$wikiLinkEdges = @()
$linkEvidence = @()
$now = (Get-Date).ToString('s')

foreach ($p in $problems) {
    $pTokens = Get-Tokens $p.subject
    $pDate = $null
    if ($p.taskStart) { try { $pDate = [datetime]$p.taskStart } catch { $pDate = $null } }

    foreach ($m in $measures) {
        $mTokens = Get-Tokens $m.subject
        $common = @($pTokens | Where-Object { $mTokens -contains $_ })

        $dateScore = 0
        if ($pDate -and $m.taskStart) {
            try {
                $mDate = [datetime]$m.taskStart
                $days = [math]::Abs(($mDate - $pDate).Days)
                if ($days -le $DayWindow) { $dateScore = 1 }
            } catch {}
        }

        $tokenScore = if ($common.Count -ge 2) { 2 } elseif ($common.Count -eq 1) { 1 } else { 0 }
        $score = $tokenScore + $dateScore

        if ($score -ge 2) {
            $link = [PSCustomObject]@{
                problem_id      = [string]$p.id
                problem_subject = [string]$p.subject
                measure_id      = [string]$m.id
                measure_subject = [string]$m.subject
                score           = $score
                common_tokens   = $common
                inferred_by     = "token+time_window"
                inferred_at     = $now
            }
            $links += $link

            $wikiLinkEdges += [PSCustomObject]@{
                edge_id = "edge-pm-task:$($p.id)-task:$($m.id)"
                relation = 'problem_measure'
                source_entity_id = "task:$($p.id)"
                target_entity_id = "task:$($m.id)"
                weight = [double]($score / 3.0)
                inferred_by = 'knowledge_link_rule'
                updated_at = $now
            }

            $linkEvidence += [PSCustomObject]@{
                evidence_id = "ev-link-$($p.id)-$($m.id)"
                source_type = 'inference'
                source_task_id = [string]$p.id
                entity_id = "task:$($p.id)"
                captured_at = $now
                payload = [PSCustomObject]@{
                    linked_measure_task_id = [string]$m.id
                    score = $score
                    common_tokens = $common
                    day_window = $DayWindow
                    rule = 'token+time_window'
                }
            }
        }
    }
}

$byProblem = @{}
foreach ($l in $links) {
    $problemKey = [string]$l.problem_id
    if (-not $byProblem.ContainsKey($problemKey)) { $byProblem[$problemKey] = @() }
    $byProblem[$problemKey] += $l
}

$out = [PSCustomObject]@{
    updated_at   = $now
    opl_id       = [string]$profile.opl_id
    day_window   = $DayWindow
    total_links  = $links.Count
    by_problem   = $byProblem
    links        = $links
}
$outPath = Join-Path $linksDir 'problem_measure_links.json'
Set-Content -Path $outPath -Value ($out | ConvertTo-Json -Depth 20) -Encoding UTF8

# Merge inferred edges/evidence into wiki files
$wikiEdgesObj = [PSCustomObject]@{ updated_at = $now; items = @() }
if (Test-Path $wikiEdgesPath) {
    try { $wikiEdgesObj = Get-Content -Raw -Path $wikiEdgesPath | ConvertFrom-Json } catch {}
    if (-not $wikiEdgesObj.items) { $wikiEdgesObj.items = @() }
}
$baseEdges = @($wikiEdgesObj.items | Where-Object { $_.relation -ne 'problem_measure' })
$wikiEdgesObj = [PSCustomObject]@{ updated_at = $now; items = @($baseEdges + $wikiLinkEdges) }
Set-Content -Path $wikiEdgesPath -Value ($wikiEdgesObj | ConvertTo-Json -Depth 20) -Encoding UTF8

$wikiEvObj = [PSCustomObject]@{ updated_at = $now; items = @() }
if (Test-Path $wikiEvidencePath) {
    try { $wikiEvObj = Get-Content -Raw -Path $wikiEvidencePath | ConvertFrom-Json } catch {}
    if (-not $wikiEvObj.items) { $wikiEvObj.items = @() }
}
$baseEv = @($wikiEvObj.items | Where-Object { -not (($_.evidence_id -as [string]) -like 'ev-link-*') })
$wikiEvObj = [PSCustomObject]@{ updated_at = $now; items = @($baseEv + $linkEvidence) }
Set-Content -Path $wikiEvidencePath -Value ($wikiEvObj | ConvertTo-Json -Depth 20) -Encoding UTF8

Write-Host "Problem-Measure linking complete." -ForegroundColor Green
Write-Host "Output: $outPath"
Write-Host "Total links: $($links.Count)"
Write-Host "Wiki edges updated: $wikiEdgesPath"