param(
    [string]$ConfigPath = '..\config\skill_config.json',
    [string]$ProfileName,
    [string]$OutputDir = '..\test-results'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$runPath = Join-Path $PSScriptRoot 'run.ps1'
if (-not (Test-Path $runPath)) { throw "run.ps1 not found at $runPath" }

if (-not [System.IO.Path]::IsPathRooted($OutputDir)) {
    $OutputDir = Join-Path $PSScriptRoot $OutputDir
}
if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null }

function Invoke-TestCase {
    param(
        [string]$Name,
        [string]$Intent,
        [object]$CaseArgs,
        [bool]$ExpectSuccess,
        [string]$ExpectedErrorCode
    )

    $cmdArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$runPath,'-Intent',$Intent,'-Protocol','json','-ConfigPath',$ConfigPath)
    if ($ProfileName) { $cmdArgs += @('-ProfileName', $ProfileName) }
    $argMap = @{}
    if ($CaseArgs -is [System.Collections.IDictionary]) {
        foreach ($k in $CaseArgs.Keys) { $argMap[[string]$k] = $CaseArgs[$k] }
    } elseif ($CaseArgs -and $CaseArgs.PSObject -and $CaseArgs.PSObject.Properties) {
        foreach ($prop in $CaseArgs.PSObject.Properties) {
            if ($prop.Name -notin @('Count','Length','LongLength','Rank','SyncRoot','IsFixedSize','IsReadOnly','IsSynchronized')) {
                $argMap[$prop.Name] = $prop.Value
            }
        }
    }

    foreach ($k in $argMap.Keys) {
        $cmdArgs += @("-$k", [string]$argMap[$k])
    }

    $lines = @(& powershell @cmdArgs 2>&1)
    $exitCode = $LASTEXITCODE
    $text = ($lines | ForEach-Object { [string]$_ }) -join "`n"

    $obj = $null
    $ok = $false
    $reason = ''

    try {
        $obj = $text | ConvertFrom-Json -ErrorAction Stop
        if ($ExpectSuccess) {
            $ok = ($exitCode -eq 0 -and $obj.status -eq 'ok')
            if (-not $ok) { $reason = "expected success but got status=$($obj.status), exit=$exitCode" }
        } else {
            $actualCode = $null
            if ($obj.errors -and @($obj.errors).Count -gt 0) { $actualCode = [string]$obj.errors[0].code }
            $ok = ($obj.status -eq 'error' -and ($ExpectedErrorCode -eq $actualCode))
            if (-not $ok) { $reason = "expected error code '$ExpectedErrorCode' but got '$actualCode'" }
        }
    }
    catch {
        $ok = $false
        $reason = "json parse failed: $($_.Exception.Message)"
    }

    return [PSCustomObject]@{
        name = $Name
        intent = $Intent
        expect_success = $ExpectSuccess
        passed = $ok
        reason = $reason
        exit_code = $exitCode
        status = if ($obj) { $obj.status } else { 'unknown' }
        error_code = if ($obj -and $obj.errors -and @($obj.errors).Count -gt 0) { [string]$obj.errors[0].code } else { '' }
    }
}

$cases = @(
    [PSCustomObject]@{ name='read success'; intent='read'; args=@{ Entity='tasks'; Output='table' }; expectSuccess=$true; expectedErrorCode='' },
    [PSCustomObject]@{ name='track success'; intent='track'; args=@{}; expectSuccess=$true; expectedErrorCode='' },
    [PSCustomObject]@{ name='knowledge-sync success'; intent='knowledge-sync'; args=@{}; expectSuccess=$true; expectedErrorCode='' },
    [PSCustomObject]@{ name='knowledge-confirm list success'; intent='knowledge-confirm'; args=@{ Action='list' }; expectSuccess=$true; expectedErrorCode='' },
    [PSCustomObject]@{ name='analyze success'; intent='analyze'; args=@{ Query='opl' }; expectSuccess=$true; expectedErrorCode='' },

    [PSCustomObject]@{ name='analyze missing query'; intent='analyze'; args=@{}; expectSuccess=$false; expectedErrorCode='validation_error' },
    [PSCustomObject]@{ name='knowledge-confirm add missing ids'; intent='knowledge-confirm'; args=@{ Action='add' }; expectSuccess=$false; expectedErrorCode='validation_error' },
    [PSCustomObject]@{ name='write missing subject'; intent='write'; args=@{ Responsible='uio1sgh' }; expectSuccess=$false; expectedErrorCode='validation_error' },
    [PSCustomObject]@{ name='delete missing taskid'; intent='delete'; args=@{}; expectSuccess=$false; expectedErrorCode='validation_error' }
)

$results = @()
foreach ($c in $cases) {
    $r = Invoke-TestCase -Name $c.name -Intent $c.intent -CaseArgs $c.args -ExpectSuccess $c.expectSuccess -ExpectedErrorCode $c.expectedErrorCode
    $results += $r
    if ($r.passed) {
        Write-Host "PASS: $($r.name)" -ForegroundColor Green
    } else {
        Write-Host "FAIL: $($r.name) -> $($r.reason)" -ForegroundColor Red
    }
}

$summary = [PSCustomObject]@{
    generated_at = (Get-Date).ToString('s')
    total = $results.Count
    passed = @($results | Where-Object { $_.passed }).Count
    failed = @($results | Where-Object { -not $_.passed }).Count
    items = $results
}

$file = Join-Path $OutputDir ("smoke-{0}.json" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
Set-Content -Path $file -Value ($summary | ConvertTo-Json -Depth 20) -Encoding UTF8
Write-Host "Smoke test report: $file" -ForegroundColor Cyan

if ($summary.failed -gt 0) { exit 1 }