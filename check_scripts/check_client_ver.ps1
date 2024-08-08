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
                        
                    Try { [io.file]::OpenWrite("$($Config.installation_path)\file.tmp").close() }
                    Catch { 
                        Write-Warning "Unable to write to output file $outputfile"
                        return $false
                    }

                    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                    Invoke-WebRequest "https://github.com/Kookabura/monopus-win/archive/$NewVersion.zip" -OutFile "$env:TEMP\monopus-win.zip" -UseBasicParsing -TimeoutSec 30

                    if (Test-Path "$env:TEMP\monopus-win-$NewVersion") {
                        rm "$env:TEMP\monopus-win-$NewVersion" -Force -Recurse
                    }

                    Add-Type -AssemblyName System.IO.Compression.FileSystem
                    [System.IO.Compression.ZipFile]::ExtractToDirectory("$env:TEMP\monopus-win.zip", $env:TEMP)

                    cp "$env:TEMP\monopus-win-$NewVersion\*" $Config.installation_path -Recurse -Force -Exclude 'main.cfg'

                    $config_sample = Get-Content "$($Config.installation_path)\main.cfg.sample" -Raw | ConvertFrom-Json
                    foreach ($prop in $config_sample.psobject.Properties) {
                        if(!(Get-Member -inputobject $config -name $prop.name -Membertype Properties)){
                            #Property not exists
                            $config | Add-Member -MemberType NoteProperty -Name $prop.name -Value $config_sample.$($prop.name)
                        }
                    }

                    $config | Add-Member -MemberType NoteProperty -Name 'version' -Value $NewVersion.ToString() -Force
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
    $latest_version = [System.Version](Invoke-WebRequest "https://monopus.io/ver.txt" -UseBasicParsing -TimeoutSec 30).content
    if ($latest_version -gt [System.Version]$config.version) {
        if ($v = Update-MonOpusClient -Config $Config -NewVersion $latest_version) {
            
            cmd /c "SCHTASKS /End /TN $($config.task_name) && SCHTASKS /Run /TN $($config.task_name)"
        } else {
            $state = 1
        }
    }

    $output += "ver==$($config.version.toString())"
    $output = "check_client_ver_$($states_text[$state])::$output | $perf"
    Write-Verbose $output
    Write-Output $output
    exit $state
}