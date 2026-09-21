# monOpus Windows Monitoring Client
monOpus.io Windows monitoring client written on Powershell.
Monitor-Host.ps1 is run by a Windows service that starts at boot and restarts the monitor if it exits.
Check scripts might be used separately from Monitor-Host.ps1.

## Installation steps
1. Clone this repository to `C:\Program Files (x86)\MonOpus`.
2. Open Windows PowerShell as Administrator and run `./Install-Monitor-Host.ps1` from that directory. Enter the client ID and API key when prompted. The API key prompt hides your input.
3. For unattended installation, pass both values: `./Install-Monitor-Host.ps1 -ClientId '123' -ApiKey 'your_api_key'`.

The installer creates `main.cfg`, compiles the service host, registers `MonOpusMonitorHost` as a LocalSystem service with automatic startup, configures recovery, and starts it. If `main.cfg` already exists, its other settings are preserved. The generated configuration and executable are ignored by Git.

The configured client should then report its checks to monOpus.io.
