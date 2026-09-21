#requires -Version 3.0

param(
    [string]$ClientId,
    [string]$ApiKey
)

$ErrorActionPreference = 'Stop'

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run this installer from an elevated Windows PowerShell prompt.'
}

$serviceName = 'MonOpusMonitorHost'
$servicePath = Join-Path $PSScriptRoot 'Monitor-Host-Service.exe'
$sourcePath = Join-Path $PSScriptRoot 'Monitor-Host-Service.cs'
$monitorPath = Join-Path $PSScriptRoot 'Monitor-Host.ps1'
$configPath = Join-Path $PSScriptRoot 'main.cfg'
$expectedPath = Join-Path ${env:ProgramFiles(x86)} 'MonOpus'

if ([IO.Path]::GetFullPath($PSScriptRoot).TrimEnd('\') -ine
    [IO.Path]::GetFullPath($expectedPath).TrimEnd('\')) {
    throw "Clone the repository into '$expectedPath' before installing."
}

if (-not (Test-Path -LiteralPath $monitorPath -PathType Leaf)) {
    throw "Monitor script not found: $monitorPath"
}
if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
    throw "Service source not found: $sourcePath"
}
if (Get-Service -Name $serviceName -ErrorAction SilentlyContinue) {
    throw "Service '$serviceName' already exists. Stop and remove it before reinstalling."
}

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

$installPath = $PSScriptRoot.TrimEnd('\') + '\'
$defaults = @{
    uri = 'https://monopus.io/api.json'
    scripts_path = (Join-Path $PSScriptRoot 'check_scripts') + '\'
    installation_path = $installPath
    timeout = '30'
    version = '1.7'
    task_name = 'Monitoring'
}
$config = @{}
if (Test-Path -LiteralPath $configPath -PathType Leaf) {
    $existing = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
    foreach ($property in $existing.PSObject.Properties) {
        $config[$property.Name] = $property.Value
    }
}
foreach ($name in $defaults.Keys) {
    if (-not $config.ContainsKey($name)) {
        $config[$name] = $defaults[$name]
    }
}
$config['id'] = $ClientId
$config['api_key'] = $ApiKey

# The executable implements the Windows service protocol and supervises Monitor-Host.ps1.
Add-Type -Path $sourcePath -OutputAssembly $servicePath -OutputType WindowsApplication `
    -ReferencedAssemblies 'System.dll', 'System.ServiceProcess.dll'

$config | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $configPath -Encoding UTF8

New-Service -Name $serviceName -DisplayName 'monOpus Host Monitor' `
    -BinaryPathName ('"{0}"' -f $servicePath) -StartupType Automatic `
    -Description 'Runs and supervises Monitor-Host.ps1' | Out-Null

& sc.exe config $serviceName 'obj=' 'LocalSystem' | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Could not set LocalSystem account for service '$serviceName'."
}

# The wrapper restarts the monitor process; SCM restarts the wrapper if it fails.
& sc.exe failure $serviceName 'reset=' '86400' 'actions=' 'restart/5000/restart/5000/restart/5000' | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Could not configure recovery for service '$serviceName'."
}

Start-Service -Name $serviceName
Write-Host "Service '$serviceName' installed and started."
