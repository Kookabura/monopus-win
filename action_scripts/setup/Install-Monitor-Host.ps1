#requires -Version 3.0

param(
    [string]$ClientId,
    [string]$ApiKey
)

$ErrorActionPreference = 'Stop'

$serviceName = 'MonOpusMonitorHost'
$installRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$expectedRoot = Join-Path ${env:ProgramFiles(x86)} 'MonOpus'
$configPath = Join-Path $installRoot 'main.cfg'
$monitorPath = Join-Path $installRoot 'Monitor-Host.ps1'
$sourcePath = Join-Path $PSScriptRoot 'Monitor-Host-Service.cs'
$servicePath = Join-Path $PSScriptRoot 'Monitor-Host-Service.exe'
$logPath = Join-Path $installRoot 'install.log'
$buildPath = $null

function Write-InstallLog {
    param([string]$Message)

    if (-not [string]::IsNullOrEmpty($ApiKey)) {
        $Message = $Message.Replace($ApiKey, '[hidden]')
    }
    $line = '{0} {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Write-Host $line
    Add-Content -LiteralPath $logPath -Value $line -Encoding UTF8
}

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Open Windows PowerShell as Administrator, then run .\action_scripts\setup\Install-Monitor-Host.ps1.'
}

try {
    Write-InstallLog "Starting monOpus installation. Log: $logPath"
    Write-InstallLog "Installation directory: $installRoot"

    if ($installRoot.TrimEnd('\') -ine [IO.Path]::GetFullPath($expectedRoot).TrimEnd('\')) {
        throw "The repository must be located at '$expectedRoot'."
    }
    if (-not (Test-Path -LiteralPath $monitorPath -PathType Leaf)) {
        throw "Monitor script not found: $monitorPath"
    }
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Service source not found: $sourcePath"
    }
    Write-InstallLog "Monitor script: $monitorPath"
    Write-InstallLog "Service source: $sourcePath"

    if ([string]::IsNullOrWhiteSpace($ClientId)) {
        $ClientId = Read-Host 'Client ID'
    }
    if ([string]::IsNullOrWhiteSpace($ApiKey)) {
        $secureKey = Read-Host 'API key' -AsSecureString
        $keyPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureKey)
        try {
            $ApiKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($keyPointer)
        }
        finally {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($keyPointer)
        }
    }
    if ([string]::IsNullOrWhiteSpace($ClientId) -or [string]::IsNullOrWhiteSpace($ApiKey)) {
        throw 'Client ID and API key must both be non-empty.'
    }
    if ($ApiKey -eq $serviceName) {
        throw 'The API key is the service name. Enter the actual API key from monOpus.'
    }
    Write-InstallLog "Client ID: $ClientId; API key: supplied (value is not logged)."

    $config = @{}
    $legacyTaskName = 'Monitoring'
    if (Test-Path -LiteralPath $configPath -PathType Leaf) {
        try {
            $existing = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
        }
        catch {
            throw "Existing configuration is not valid JSON: $configPath"
        }
        foreach ($property in $existing.PSObject.Properties) {
            $config[$property.Name] = $property.Value
        }
        if (-not [string]::IsNullOrWhiteSpace([string]$config['task_name'])) {
            $legacyTaskName = [string]$config['task_name']
        }
        Write-InstallLog "Existing configuration loaded: $configPath"
    }
    else {
        Write-InstallLog "Creating configuration: $configPath"
    }

    if (-not $config.ContainsKey('uri')) { $config['uri'] = 'https://monopus.io/api.json' }
    if (-not $config.ContainsKey('timeout')) { $config['timeout'] = '30' }
    if (-not $config.ContainsKey('version')) { $config['version'] = '1.7' }
    $config['installation_path'] = $installRoot.TrimEnd('\') + '\'
    $config['scripts_path'] = (Join-Path $installRoot 'check_scripts') + '\'
    $config['id'] = $ClientId
    $config['api_key'] = $ApiKey
    [void]$config.Remove('task_name')
    $configJson = $config | ConvertTo-Json -Depth 8
    Write-InstallLog 'Configuration prepared; obsolete task_name removed.'

    Write-InstallLog "Checking API response from $($config['uri'])."
    try {
        $apiResponse = Invoke-WebRequest -Uri $config['uri'] -Method Post -UseBasicParsing `
            -Body @{ api_key = $ApiKey; id = $ClientId; mon_action = 'check/status'; class = 'host' } `
            -TimeoutSec 20
        $apiResult = $apiResponse.Content | ConvertFrom-Json
        $apiSuccess = if ($null -ne $apiResult.success) { [string]$apiResult.success } else { 'absent' }
        $apiServices = $apiResult.data.services
        $apiServicesType = if ($null -eq $apiServices) { 'absent' } else { $apiServices.GetType().Name }
        $apiServiceCount = 0
        if ($apiServices -is [pscustomobject]) {
            $apiServiceCount = @($apiServices.PSObject.Properties).Count
        }
        elseif ($apiServices -is [array]) {
            $apiServiceCount = $apiServices.Count
        }
        $responseFields = ($apiResult.PSObject.Properties | ForEach-Object { $_.Name }) -join ','
        $dataFields = ($apiResult.data.PSObject.Properties | ForEach-Object { $_.Name }) -join ','
        Write-InstallLog "API HTTP $($apiResponse.StatusCode); JSON characters: $($apiResponse.Content.Length); success: $apiSuccess; services type: $apiServicesType; checks: $apiServiceCount; response fields: $responseFields; data fields: $dataFields."
        if ($apiResult.success -eq $false) {
            Write-InstallLog 'WARNING: The API returned success=false. Check the client ID and API key.'
        }
        elseif ($apiServices -isnot [pscustomobject]) {
            Write-InstallLog 'WARNING: The API did not return checks in the object format required by Monitor-Host.ps1.'
        }
        elseif ($apiServiceCount -eq 0) {
            Write-InstallLog 'WARNING: The API responded but returned no monitoring checks.'
        }
        else {
            Write-InstallLog 'API response contains monitoring checks.'
        }
    }
    catch {
        Write-InstallLog "WARNING: API check failed: $($_.Exception.Message)"
    }

    $buildPath = Join-Path $env:TEMP ('MonOpusMonitorHost-{0}.exe' -f [guid]::NewGuid().ToString('N'))
    Write-InstallLog 'Compiling the Windows service executable.'
    Add-Type -Path $sourcePath -OutputAssembly $buildPath -OutputType WindowsApplication `
        -ReferencedAssemblies 'System.dll', 'System.ServiceProcess.dll'
    Write-InstallLog "Compilation completed: $buildPath"

    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    if ($service) {
        Write-InstallLog "Existing service found: $serviceName ($($service.Status))."
        if ($service.Status -ne 'Stopped') {
            Write-InstallLog 'Stopping the existing service before updating its executable.'
            Stop-Service -Name $serviceName
            (Get-Service -Name $serviceName).WaitForStatus('Stopped', (New-TimeSpan -Seconds 30))
        }
    }
    else {
        Write-InstallLog "Service does not exist yet: $serviceName"
    }

    Copy-Item -LiteralPath $buildPath -Destination $servicePath -Force
    Write-InstallLog "Service executable: $servicePath"
    $configJson | Set-Content -LiteralPath $configPath -Encoding UTF8
    Write-InstallLog "Configuration saved: $configPath (client ID: $ClientId; API key hidden)."

    $quotedServicePath = '"{0}"' -f $servicePath
    if (-not $service) {
        New-Service -Name $serviceName -DisplayName 'monOpus Host Monitor' `
            -BinaryPathName $quotedServicePath -StartupType Automatic `
            -Description 'Runs and supervises Monitor-Host.ps1' | Out-Null
        Write-InstallLog "Service registered: $serviceName"
    }

    $scOutput = & sc.exe config $serviceName 'binPath=' $quotedServicePath 'start=' 'auto' 'obj=' 'LocalSystem'
    if ($LASTEXITCODE -ne 0) { throw "Service configuration failed: $($scOutput -join ' ')" }
    Write-InstallLog 'Service configured for automatic startup as LocalSystem.'

    $scOutput = & sc.exe failure $serviceName 'reset=' '86400' 'actions=' 'restart/5000/restart/5000/restart/5000'
    if ($LASTEXITCODE -ne 0) { throw "Service recovery configuration failed: $($scOutput -join ' ')" }
    Write-InstallLog 'Service recovery configured: restart after a service failure.'

    Start-Service -Name $serviceName
    (Get-Service -Name $serviceName).WaitForStatus('Running', (New-TimeSpan -Seconds 30))
    Write-InstallLog "Service is running: $serviceName"

    $serviceInfo = Get-CimInstance -ClassName Win32_Service -Filter "Name='$serviceName'"
    if (-not $serviceInfo -or $serviceInfo.PathName -notlike "*$servicePath*" -or
        $serviceInfo.StartMode -ne 'Auto' -or $serviceInfo.StartName -notmatch 'LocalSystem') {
        throw "Service registration does not match the expected executable, startup mode, or account."
    }
    Write-InstallLog "Service account: $($serviceInfo.StartName); startup: $($serviceInfo.StartMode); executable: $($serviceInfo.PathName)"

    if (Get-Command Get-ScheduledTask -ErrorAction SilentlyContinue) {
        foreach ($taskName in @($legacyTaskName, 'Monitoring') | Select-Object -Unique) {
            foreach ($task in @(Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue)) {
                $actionText = ($task.Actions | ForEach-Object { "$($_.Execute) $($_.Arguments)" }) -join ' '
                if ($actionText -match 'Monitor-Host\.ps1') {
                    try {
                        Stop-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -ErrorAction SilentlyContinue
                        Disable-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -ErrorAction Stop | Out-Null
                        Write-InstallLog "Disabled old monitoring task: $($task.TaskPath)$($task.TaskName)"
                    }
                    catch {
                        Write-InstallLog "WARNING: Could not disable old monitoring task $($task.TaskName): $($_.Exception.Message)"
                    }
                }
            }
        }
    }
    Write-InstallLog "Installation finished. Configuration: $configPath; log: $logPath"
}
catch {
    $message = $_.Exception.Message
    try { Write-InstallLog "ERROR: $message" } catch { Write-Host "ERROR: $message" }
    throw
}
finally {
    if ($buildPath -and (Test-Path -LiteralPath $buildPath)) {
        Remove-Item -LiteralPath $buildPath -Force
    }
}
