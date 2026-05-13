Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-ConfigPath {
    param([string]$ConfigPath)
    if ([System.IO.Path]::IsPathRooted($ConfigPath)) { return $ConfigPath }
    $scriptDir = $PSScriptRoot
    if (-not $scriptDir) { $scriptDir = (Get-Location).Path }
    return (Join-Path $scriptDir $ConfigPath)
}

function Get-SuperOPLConfig {
    param(
        [string]$ConfigPath = '..\config\skill_config.json',
        [string]$ProfileName
    )

    $resolved = Resolve-ConfigPath -ConfigPath $ConfigPath
    if (-not (Test-Path $resolved)) {
        throw "Config file not found: $resolved. Copy config/skill_config.template.json to config/skill_config.json and fill values first."
    }

    $raw = Get-Content -Path $resolved -Raw | ConvertFrom-Json
    $active = if ($ProfileName) { $ProfileName } else { $raw.active_profile }
    if (-not $active) { throw 'active_profile is missing in config file.' }

    $profile = $raw.profiles.$active
    if (-not $profile) { throw "Profile '$active' not found in config file." }

    foreach ($k in @('api_key','opl_id','user_login','base_url')) {
        if (-not $profile.$k -or [string]::IsNullOrWhiteSpace([string]$profile.$k)) {
            throw "Profile '$active' is missing required field: $k"
        }
    }

    return [PSCustomObject]@{
        config_path         = $resolved
        raw                 = $raw
        active_profile      = $active
        api_key             = [string]$profile.api_key
        opl_id              = [string]$profile.opl_id
        user_login          = [string]$profile.user_login
        user_name           = [string]$profile.user_name
        base_url            = ([string]$profile.base_url).TrimEnd('/')
        knowledge_base_path = if ($raw.knowledge_base_path) { [string]$raw.knowledge_base_path } else { '.\knowledge_base' }
    }
}

function Save-SuperOPLConfig {
    param(
        [Parameter(Mandatory = $true)] [pscustomobject]$ConfigObject,
        [Parameter(Mandatory = $true)] [string]$ConfigPath
    )
    $json = $ConfigObject | ConvertTo-Json -Depth 12
    Set-Content -Path $ConfigPath -Value $json -Encoding UTF8
}

function Invoke-SuperOPLApi {
    param(
        [Parameter(Mandatory = $true)] [string]$Method,
        [Parameter(Mandatory = $true)] [string]$Endpoint,
        [Parameter(Mandatory = $true)] [pscustomobject]$Profile,
        [object]$Body
    )

    $uri = "{0}{1}" -f $Profile.base_url, $Endpoint
    if ($uri -match '\?') { $uri = "${uri}&key=$($Profile.api_key)" }
    else { $uri = "${uri}?key=$($Profile.api_key)" }

    $params = @{ Method = $Method; Uri = $uri; ContentType = 'application/json' }
    if ($null -ne $Body) { $params.Body = ($Body | ConvertTo-Json -Depth 30) }

    try { return Invoke-RestMethod @params }
    catch {
        $message = $_.Exception.Message
        if ($_.ErrorDetails.Message) { $message = "$message | API Response: $($_.ErrorDetails.Message)" }
        throw "SuperOPL API call failed [$Method $Endpoint]: $message"
    }
}

function Get-SuperOPLData {
    param([object]$ApiResponse)
    if ($null -eq $ApiResponse) { return $null }
    if ($ApiResponse.PSObject.Properties.Name -contains 'data') { return $ApiResponse.data }
    return $ApiResponse
}

function Get-SuperOPLTasks {
    param([object]$TasksApiResponse)
    $data = Get-SuperOPLData -ApiResponse $TasksApiResponse
    if ($null -eq $data) { return @() }

    $items = @()
    if ($data -is [System.Collections.IDictionary]) {
        $items = @($data.Values)
    } elseif ($data -is [System.Array]) {
        $items = @($data)
    } elseif ($data.PSObject -and @($data.PSObject.Properties).Count -gt 0) {
        $items = @($data.PSObject.Properties | ForEach-Object { $_.Value })
    }

    $normalized = @()
    foreach ($t in $items) {
        $hasTaskId = @($t.PSObject.Properties.Name) -contains 'taskId'
        $hasId = @($t.PSObject.Properties.Name) -contains 'id'
        $id = if ($hasTaskId) { $t.taskId } elseif ($hasId) { $t.id } else { $null }

        $hasEndDateActualISO = @($t.PSObject.Properties.Name) -contains 'endDateActualISO'
        $hasEndDateActual = @($t.PSObject.Properties.Name) -contains 'endDateActual'
        $hasEndDate = @($t.PSObject.Properties.Name) -contains 'endDate'
        $hasTaskStart = @($t.PSObject.Properties.Name) -contains 'taskStart'
        $hasTaskStartISO = @($t.PSObject.Properties.Name) -contains 'taskStartISO'
        $hasReminderState = @($t.PSObject.Properties.Name) -contains 'reminderState'
        $hasChangeStatusDate = @($t.PSObject.Properties.Name) -contains 'changeStatusDate'

        $endDate = ''
        if ($hasEndDateActualISO -and $t.endDateActualISO) {
            $endDate = [string]$t.endDateActualISO
            if ($endDate.Length -ge 10) { $endDate = $endDate.Substring(0,10) }
        } elseif ($hasEndDateActual -and $t.endDateActual -and (@($t.endDateActual.PSObject.Properties.Name) -contains 'date')) {
            $endDate = [string]$t.endDateActual.date
            if ($endDate.Length -ge 10) { $endDate = $endDate.Substring(0,10) }
        } elseif ($hasEndDate -and $t.endDate) {
            $endDate = [string]$t.endDate
        }

        $taskStart = ''
        if ($hasTaskStart -and $t.taskStart -and (@($t.taskStart.PSObject.Properties.Name) -contains 'date')) {
            $taskStart = [string]$t.taskStart.date
            if ($taskStart.Length -ge 10) { $taskStart = $taskStart.Substring(0,10) }
        } elseif ($hasTaskStartISO -and $t.taskStartISO) {
            $taskStart = [string]$t.taskStartISO
            if ($taskStart.Length -ge 10) { $taskStart = $taskStart.Substring(0,10) }
        }

        $normalized += [PSCustomObject]@{
            id              = [string]$id
            taskId          = [string]$id
            subject         = if (@($t.PSObject.Properties.Name) -contains 'subject') { [string]$t.subject } else { '' }
            type            = if (@($t.PSObject.Properties.Name) -contains 'type') { [int]$t.type } else { 0 }
            status          = if (@($t.PSObject.Properties.Name) -contains 'status') { [string]$t.status } else { '' }
            responsible     = if (@($t.PSObject.Properties.Name) -contains 'responsible') { [string]$t.responsible } else { '' }
            owner           = if (@($t.PSObject.Properties.Name) -contains 'owner') { [string]$t.owner } else { '' }
            endDate         = $endDate
            taskStart       = $taskStart
            reminderState   = if ($hasReminderState) { [string]$t.reminderState } else { '' }
            changeStatusDate= if ($hasChangeStatusDate) { [string]$t.changeStatusDate } else { '' }
            raw             = $t
        }
    }
    return $normalized
}

function Convert-TypeToCode {
    param([Parameter(Mandatory = $true)][string]$Type)
    $map = @{ 'task' = 1; 'decision' = 2; 'information' = 3; 'review' = 4; 'problem' = 6; 'measure' = 7 }
    $key = $Type.ToLower().Trim()
    if (-not $map.ContainsKey($key)) { throw "Unsupported type '$Type'. Use one of: $($map.Keys -join ', ')" }
    return $map[$key]
}

function Get-KnowledgeBasePath {
    param([pscustomobject]$Profile)
    $configDir = Split-Path -Parent $Profile.config_path
    if ([System.IO.Path]::IsPathRooted($Profile.knowledge_base_path)) { return $Profile.knowledge_base_path }
    return (Join-Path (Split-Path -Parent $configDir) $Profile.knowledge_base_path)
}
