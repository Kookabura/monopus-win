# monOpus Windows Monitoring Client
monOpus.io Windows monitoring client written on Powershell.
Monitor-Host.ps1 is run by a Windows service that starts at boot and restarts the monitor if it exits.
Check scripts might be used separately from Monitor-Host.ps1.

## Installation steps

1. Clone this repository to `C:\Program Files (x86)\MonOpus`.
2. Open **Windows PowerShell as Administrator**. In the repository directory, run `.\action_scripts\setup\Install-Monitor-Host.ps1`. PowerShell requires `.\` for a script in the current directory.
3. Enter the API key when prompted. The input is hidden. To provide it as a parameter, run `.\action_scripts\setup\Install-Monitor-Host.ps1 -ApiKey 'your_api_key'`.

The service is named `MonOpusMonitorHost`. The installer creates or updates `C:\Program Files (x86)\MonOpus\main.cfg`, places the service executable in `action_scripts\setup`, configures LocalSystem and automatic startup, and starts the service. On first start, the monitor registers the host through the API and saves the returned monitoring point ID in `main.cfg`; this ID is never entered manually. The installer prints each step and writes the same messages to `install.log` in the repository root. The API key is never written to the installation log. Running the installer again updates the existing service and configuration while retaining its monitoring point ID.

Check the result with `Get-Service MonOpusMonitorHost`. When updating a configuration that already has a monitoring point ID, the installer checks whether the API returns monitoring checks and records a warning if it cannot confirm this. `monitor-host-service.log` in the repository root records monitor starts, exits, and PowerShell errors. If an older monitoring scheduled task exists, the installer disables it after the service starts.

If the service is running but checks do not report, inspect the `API HTTP ... success ... checks` line in `install.log` and the `API check/status ...` line in `monitor-host-service.log`. These lines show response metadata without the API key.

The configured client should then report its checks to monOpus.io.
