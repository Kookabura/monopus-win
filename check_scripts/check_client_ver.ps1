[CmdletBinding()]
Param(
    [Parameter()]
    $config = $global:config
)

Begin {
        # Return $false or installed version number
        Function Update-MonOpusClient {
            [CmdletBinding()]
            Param(
                [Parameter(Mandatory=$true)]
                $Config,
                [Parameter(Mandatory=$true)]
                [System.Version]$NewVersion
                
            )
            process {

                try {

                    if (Test-Path $Config.installation_path) {
                        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                        Invoke-WebRequest "https://github.com/Kookabura/monopus-win/archive/$NewVersion.zip" -OutFile "$env:TEMP\monopus-win.zip"

                        if (Test-Path "$env:TEMP\monopus-win-$NewVersion") {
                            rm "$env:TEMP\monopus-win-$NewVersion" -Force -Recurse
                        }

                        Add-Type -AssemblyName System.IO.Compression.FileSystem
                        [System.IO.Compression.ZipFile]::ExtractToDirectory("$env:TEMP\monopus-win.zip", $env:TEMP)

                        cp "$env:TEMP\monopus-win-$NewVersion\*" $Config.installation_path -Recurse -Force -Exclude 'main.cfg'
                        $Config | ConvertTo-Json -Compress | Set-Content -Path "$($Config.installation_path)\main.cfg"

                        Write-Verbose "Client successfully updated"

                        return $NewVersion
                    }
                } catch {
                    Write-Error ("Error on update client stage: " + $_)
                }

                return $false
            }
        }
}

Process {
    $output = $null
    $perf = $null
    $states_text = @('ok', 'warning', 'critical', 'unknown')
    $state_colors = @('Green', 'Yellow', 'Red', 'DarkGray')
    $state = 0

    #Check updates
    $latest_version = [System.Version](Invoke-WebRequest "https://monopus.io/ver.txt").content
    if ($latest_version -gt [System.Version]$config.version) {
        Write-Output $latest_version
        if ($v = Update-MonOpusClient -Config $Config -NewVersion $latest_version) {
            Write-Output 'Test'
            $output += "ver==$v"
            $config | Add-Member @{version=$v.ToString()} -PassThru -Force | Out-Null
            $Config | ConvertTo-Json -Compress | Set-Content -Path "$($Config.installation_path)\main.cfg"
            cmd /c "SCHTASKS /End /TN $($config.task_name) && SCHTASKS /Run /TN $($config.task_name)"
        } else {
            $state = 1
        }
    }

    $output = "check_client_ver_$($states_text[$state])::$output | $perf"
    Write-Verbose $output
    Write-Output $output
    exit $state
}