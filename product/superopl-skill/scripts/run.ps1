param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('setup','read','write','edit','delete','track','report','knowledge-sync','knowledge-link','knowledge-search','knowledge-confirm','analyze')]
    [string]$Intent,

    [ValidateSet('json','raw')]
    [string]$Protocol = 'json',

    [string]$ConfigPath = '..\config\skill_config.json',
    [string]$ProfileName,

    [string]$Query,
    [string]$Output,
    [int]$Top,

    [string]$ApiKey,
    [string]$OplId,
    [string]$UserLogin,
    [string]$UserName,
    [string]$BaseUrl,

    [string]$Entity,
    [string]$Status,
    [string]$Responsible,
    [string]$Type,
    [string]$FromDate,
    [string]$ToDate,

    [string]$TaskId,
    [string]$Subject,
    [string]$DueDate,
    [string]$Description,
    [string]$Prio,
    [string]$Owner,
    [string]$TaskStart,
    [string]$StatusComment,
    [string]$DueDateChangeReason,

    [string]$OutputPath,
    [int]$UpcomingDays,
    [int]$RecentClosedDays,
    [int]$DayWindow,

    [ValidateSet('add','remove','list')]
    [string]$Action,
    [string]$ProblemId,
    [string]$MeasureId,
    [string]$Note,

    [int]$MaxOutputLines = 120,
    [int]$MaxOutputChars = 8000
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Add-IfPresent {
    param([hashtable]$Map,[string]$Key,$Value)
    if ($null -ne $Value -and -not ([string]::IsNullOrWhiteSpace([string]$Value))) { $Map[$Key] = $Value }
}

function Add-IfPositiveInt {
    param([hashtable]$Map,[string]$Key,[int]$Value)
    if ($Value -gt 0) { $Map[$Key] = $Value }
}

function To-ArgList {
    param([hashtable]$Map)
    $args = @()
    foreach ($k in $Map.Keys) {
        $args += "-$k"
        $args += [string]$Map[$k]
    }
    return ,$args
}

function Try-ParseJsonFromText {
    param([string]$Text)
    if (-not $Text) { return $null }
    try { return ($Text | ConvertFrom-Json -ErrorAction Stop) } catch {}

    $m = [regex]::Matches($Text, '(?s)\{.*?\}')
    if ($m.Count -gt 0) {
        for ($i = $m.Count - 1; $i -ge 0; $i--) {
            try { return ($m[$i].Value | ConvertFrom-Json -ErrorAction Stop) } catch {}
        }
    }
    return $null
}

function Normalize-ErrorCode {
    param([string]$Message)
    if (-not $Message) { return 'runtime_error' }
    $m = $Message.ToLower()
    if ($m -like '*requires -*' -or $m -like '*not found*' -or $m -like '*mandatory*') { return 'validation_error' }
    if ($m -like '*api call failed*' -or $m -like '*invoke-restmethod*' -or $m -like '*response status code*') { return 'api_error' }
    return 'runtime_error'
}

function Resolve-ErrorDetails {
    param(
        [string]$Message,
        [string]$Source = 'run.ps1'
    )

    $code = Normalize-ErrorCode -Message $Message
    $hint = 'Check script output and parameters.'
    $httpStatus = $null

    if ($Message -match '\b(401|403|404|406|429|500|502|503)\b') {
        $httpStatus = [int]$matches[1]
    }

    if ($code -eq 'validation_error') {
        $hint = 'Check required parameters for this intent (for example Query/Subject/TaskId).'
    }
    elseif ($code -eq 'api_error') {
        if ($httpStatus -eq 401 -or $httpStatus -eq 403) {
            $hint = 'Authentication or permission failed. Verify API key, user login, and OPL access rights.'
        }
        elseif ($httpStatus -eq 406) {
            $hint = 'Request rejected by SuperOPL validation. Check loginUser/responsible/type/date fields.'
        }
        elseif ($httpStatus -ge 500) {
            $hint = 'SuperOPL service might be unstable. Retry later and check server status.'
        }
        else {
            $hint = 'API call failed. Check endpoint, payload fields, and SuperOPL response details.'
        }
    }

    return [PSCustomObject]@{
        code = $code
        message = $Message
        hint = $hint
        source = $Source
        http_status = $httpStatus
    }
}

function Limit-Output {
    param(
        [string[]]$Lines,
        [int]$MaxLines,
        [int]$MaxChars
    )

    $src = @($Lines)
    $wasLineTruncated = $false
    if ($MaxLines -gt 0 -and $src.Count -gt $MaxLines) {
        $src = @($src | Select-Object -First $MaxLines)
        $wasLineTruncated = $true
    }

    $text = ($src -join "`n")
    $wasCharTruncated = $false
    if ($MaxChars -gt 0 -and $text.Length -gt $MaxChars) {
        $text = $text.Substring(0, $MaxChars)
        $wasCharTruncated = $true
    }

    return [PSCustomObject]@{
        lines = $src
        text = $text
        truncated = ($wasLineTruncated -or $wasCharTruncated)
        line_truncated = $wasLineTruncated
        char_truncated = $wasCharTruncated
    }
}

function New-Envelope {
    param(
        [string]$Status,
        [string]$Intent,
        [int]$ExitCode,
        [string]$ScriptName,
        [hashtable]$Params,
        [object]$ParsedJson,
        [string]$OutputText,
        [string[]]$OutputLines,
        [object[]]$Errors,
        [bool]$WasTruncated = $false,
        [bool]$LineTruncated = $false,
        [bool]$CharTruncated = $false
    )

    $errOut = @()
    if ($null -ne $Errors) { $errOut = @($Errors) }

    return [PSCustomObject]@{
        status = $Status
        intent = $Intent
        timestamp = (Get-Date).ToString('s')
        exit_code = $ExitCode
        data = [PSCustomObject]@{
            script = $ScriptName
            params = $Params
            parsed_json = $ParsedJson
            output_text = $OutputText
            output_lines = $OutputLines
            truncated = $WasTruncated
            line_truncated = $LineTruncated
            char_truncated = $CharTruncated
        }
        errors = $errOut
    }
}

$common = @{}
Add-IfPresent -Map $common -Key 'ConfigPath' -Value $ConfigPath
Add-IfPresent -Map $common -Key 'ProfileName' -Value $ProfileName

$scriptName = ''
$p = @{}

try {
    switch ($Intent) {
        'setup' {
            $scriptName = 'opl_setup.ps1'
            Add-IfPresent -Map $p -Key 'ApiKey' -Value $ApiKey
            Add-IfPresent -Map $p -Key 'OplId' -Value $OplId
            Add-IfPresent -Map $p -Key 'UserLogin' -Value $UserLogin
            Add-IfPresent -Map $p -Key 'UserName' -Value $UserName
            Add-IfPresent -Map $p -Key 'BaseUrl' -Value $BaseUrl
            Add-IfPresent -Map $p -Key 'ConfigPath' -Value $ConfigPath
        }
        'read' {
            $scriptName = 'opl_read.ps1'
            $p = @{} + $common
            Add-IfPresent -Map $p -Key 'Entity' -Value $Entity
            Add-IfPresent -Map $p -Key 'Status' -Value $Status
            Add-IfPresent -Map $p -Key 'Responsible' -Value $Responsible
            Add-IfPresent -Map $p -Key 'Type' -Value $Type
            Add-IfPresent -Map $p -Key 'FromDate' -Value $FromDate
            Add-IfPresent -Map $p -Key 'ToDate' -Value $ToDate
            Add-IfPresent -Map $p -Key 'Output' -Value $Output
        }
        'write' {
            if (-not $Subject) { throw 'write intent requires -Subject' }
            if (-not $Responsible) { throw 'write intent requires -Responsible' }
            $scriptName = 'opl_write.ps1'
            $p = @{} + $common
            Add-IfPresent -Map $p -Key 'Subject' -Value $Subject
            Add-IfPresent -Map $p -Key 'Type' -Value $Type
            Add-IfPresent -Map $p -Key 'Responsible' -Value $Responsible
            Add-IfPresent -Map $p -Key 'Owner' -Value $Owner
            Add-IfPresent -Map $p -Key 'TaskStart' -Value $TaskStart
            Add-IfPresent -Map $p -Key 'DueDate' -Value $DueDate
            Add-IfPresent -Map $p -Key 'Description' -Value $Description
            Add-IfPresent -Map $p -Key 'Prio' -Value $Prio
        }
        'edit' {
            if (-not $TaskId) { throw 'edit intent requires -TaskId' }
            $scriptName = 'opl_edit.ps1'
            $p = @{} + $common
            Add-IfPresent -Map $p -Key 'TaskId' -Value $TaskId
            Add-IfPresent -Map $p -Key 'Subject' -Value $Subject
            Add-IfPresent -Map $p -Key 'DueDate' -Value $DueDate
            Add-IfPresent -Map $p -Key 'Responsible' -Value $Responsible
            Add-IfPresent -Map $p -Key 'Status' -Value $Status
            Add-IfPresent -Map $p -Key 'StatusComment' -Value $StatusComment
            Add-IfPresent -Map $p -Key 'DueDateChangeReason' -Value $DueDateChangeReason
        }
        'delete' {
            if (-not $TaskId) { throw 'delete intent requires -TaskId' }
            $scriptName = 'opl_delete.ps1'
            $p = @{} + $common
            Add-IfPresent -Map $p -Key 'TaskId' -Value $TaskId
        }
        'track' {
            $scriptName = 'opl_track.ps1'
            $p = @{} + $common
            Add-IfPositiveInt -Map $p -Key 'UpcomingDays' -Value $UpcomingDays
            Add-IfPresent -Map $p -Key 'Output' -Value $Output
        }
        'report' {
            $scriptName = 'opl_report.ps1'
            $p = @{} + $common
            Add-IfPresent -Map $p -Key 'OutputPath' -Value $OutputPath
            Add-IfPositiveInt -Map $p -Key 'UpcomingDays' -Value $UpcomingDays
            Add-IfPositiveInt -Map $p -Key 'RecentClosedDays' -Value $RecentClosedDays
        }
        'knowledge-sync' {
            $scriptName = 'opl_knowledge_sync.ps1'
            $p = @{} + $common
        }
        'knowledge-link' {
            $scriptName = 'opl_knowledge_link.ps1'
            $p = @{} + $common
            Add-IfPositiveInt -Map $p -Key 'DayWindow' -Value $DayWindow
        }
        'knowledge-search' {
            if (-not $Query) { throw 'knowledge-search intent requires -Query' }
            $scriptName = 'opl_knowledge_search.ps1'
            $p = @{} + $common
            Add-IfPresent -Map $p -Key 'Query' -Value $Query
            Add-IfPositiveInt -Map $p -Key 'Top' -Value $Top
        }
        'knowledge-confirm' {
            $scriptName = 'opl_knowledge_confirm.ps1'
            $p = @{} + $common
            Add-IfPresent -Map $p -Key 'Action' -Value $Action
            Add-IfPresent -Map $p -Key 'ProblemId' -Value $ProblemId
            Add-IfPresent -Map $p -Key 'MeasureId' -Value $MeasureId
            Add-IfPresent -Map $p -Key 'Note' -Value $Note
        }
        'analyze' {
            if (-not $Query) { throw 'analyze intent requires -Query' }
            $scriptName = 'opl_analyze.ps1'
            $p = @{} + $common
            Add-IfPresent -Map $p -Key 'Query' -Value $Query
            Add-IfPositiveInt -Map $p -Key 'Top' -Value $Top
            Add-IfPresent -Map $p -Key 'Output' -Value $Output
        }
    }

    $scriptPath = Join-Path $PSScriptRoot $scriptName
    if (-not (Test-Path $scriptPath)) { throw "Target script not found: $scriptPath" }

    if ($Protocol -eq 'raw') {
        & $scriptPath @p
        $rawExit = 0
        $lec = Get-Variable -Name LASTEXITCODE -ErrorAction SilentlyContinue
        if ($lec) { $rawExit = [int]$lec.Value }
        exit $rawExit
    }

    $psArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $scriptPath) + (To-ArgList -Map $p)
    $outputLines = @(& powershell @psArgs 2>&1)
    $exitCode = $LASTEXITCODE

    $fullLines = @($outputLines | ForEach-Object { [string]$_ })
    $limited = Limit-Output -Lines $fullLines -MaxLines $MaxOutputLines -MaxChars $MaxOutputChars
    $combined = $limited.text
    $parsed = Try-ParseJsonFromText -Text $combined

    $errors = @()
    if ($exitCode -ne 0) {
        $errors = @(Resolve-ErrorDetails -Message $combined -Source $scriptName)
    }
    $status = if ($exitCode -eq 0) { 'ok' } else { 'error' }

    $envelope = New-Envelope -Status $status -Intent $Intent -ExitCode $exitCode -ScriptName $scriptName -Params $p -ParsedJson $parsed -OutputText $combined -OutputLines $limited.lines -Errors $errors -WasTruncated $limited.truncated -LineTruncated $limited.line_truncated -CharTruncated $limited.char_truncated
    $envelope | ConvertTo-Json -Depth 20

    if ($exitCode -ne 0) { exit $exitCode }
}
catch {
    if ($Protocol -eq 'raw') { throw }

    $msg = $_.Exception.Message
    $limited = Limit-Output -Lines @($msg) -MaxLines $MaxOutputLines -MaxChars $MaxOutputChars
    $err = Resolve-ErrorDetails -Message $limited.text -Source 'run.ps1'
    $envelope = New-Envelope -Status 'error' -Intent $Intent -ExitCode 1 -ScriptName $scriptName -Params $p -ParsedJson $null -OutputText $limited.text -OutputLines $limited.lines -Errors @($err) -WasTruncated $limited.truncated -LineTruncated $limited.line_truncated -CharTruncated $limited.char_truncated
    $envelope | ConvertTo-Json -Depth 20
    exit 1
}