[CmdletBinding()]
PARAM()

# Host monitoring and sending data to monopus.io
Function Get-Services {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        $Config
    )
    process {
        $settings_obj = (Invoke-WebRequest $config.uri -Method Post -UseBasicParsing -Body @{api_key=$($config.api_key);id=$($config.id);mon_action='check/status';class="host"}).content | ConvertFrom-Json
        $services = @{}
        if ($settings_obj -and $settings_obj.data.services) {
            ($settings_obj.data.services).psobject.properties  | % {$services[$_.Name] = $_.Value}
        }
        return $services
    }
}

$max_retries = 6
$retry_interval = 10
$work = $false
$timeout = 10
$config_path = "${env:ProgramFiles(x86)}\MonOpus\main.cfg"
$start = Get-Date
$logPath = "C:\Program Files (x86)\monOpus\Logfile.log"

if ($logPath -and $PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) {
    Start-Transcript -Path $logPath
}

try {
    $config = Get-Content -Raw -Path $config_path | ConvertFrom-Json

    if (!$config.id) {
        $op_system = gwmi win32_operatingsystem
        $data = @{
            'name' = (hostname);
            'address' = (Invoke-RestMethod http://ipinfo.io/json | Select -exp ip);
            'os' = $op_system.caption;
            'memory' = (('{0:N0}' -f ($op_system.TotalVisibleMemorySize / 1Mb)) + 'Gb');
            'api_key' = $config.api_key;
            'mon_action' = 'site/create';
            'drives' = ((gwmi win32_logicaldisk | ? {$_.drivetype -eq 3}).deviceid -replace ':') -join ','
        }

        $response = Invoke-RestMethod $config.uri -Method Post -Body $data

        $config | Add-Member @{id=$($response.data.id)} -PassThru -Force | Out-Null
        $config | ConvertTo-Json -Compress | Set-Content -Path $config_path
    }

    # TO DO: Add check for several time before stopping because checks might be created later
    for ($i=1; $i -le $max_retries; $i++) {
        if ($services = Get-Services -Config $config) {
            $work = $true
            break;
        } else {
            if ($i -eq $max_retries) {
                Write-Output "There are no services for this host"
                exit
            } else {
                sleep -Seconds $retry_interval
            }
        }
    }
    
} catch {
    Write-Error ("Error on init stage: " + $_)
    exit 1
}

while ($work) {
    Write-Verbose "$(get-date) Starting work with services $(ConvertTo-Json $services)"
    $timestamp = [int][double]::Parse((Get-Date -UFormat %s))
    $bad_keys = @()

    foreach ($key in $services.Keys) {

        $updatedon = if ($services[$key].updatedon) {[int][double]::Parse((Get-Date -Date $services[$key].updatedon -UFormat %s))} else {0}
    
        if ($services[$key].active -and $services[$key].passive -and $services[$key].command -and (($updatedon+$services[$key].interval*60) -lt $timestamp -or $services[$key].state -eq 3)) {
            
            Write-Verbose "$(get-date) Handling service $key"
           
            $parameters = @{}
            if($services[$key].warning) {
                $parameters['w'] = $services[$key].warning
            }
            if($services[$key].critical) {
                $parameters['c'] = $services[$key].critical
            }
            if ($services[$key].args) {
                foreach ($p in ($services[$key].args.trim('-') -split '-')) {
                     $a = $p.trim() -split '='
                     $parameters[$a[0]] = $a[1]
                }
            }

            $command = ($config.scripts_path + $services[$key].command + ".ps1")

            
            if (Test-Path $command) {
                Write-Verbose "$(get-date) Starting check command $command with parameters: $($parameters | ConvertTo-Json)"

                $job = [PowerShell]::Create().AddScript({
                  param($command, $parameters)
                  $parameters.output = & $command @parameters
                  $parameters.code = $LASTEXITCODE
                }).AddArgument($command).AddArgument($parameters)

                # start thee job
                $async = $job.BeginInvoke()

                $n = 0
                while (!$async.IsCompleted -and $n -le $timeout) {
                    $n++
                    sleep 1
                }

                if ($n -gt $timeout) {
                    Write-Verbose "$(get-date) Timeout exceeded"
                    $job.Stop()
                } else {
                    if ($job.HadErrors) {
                        Write-Verbose "$(get-date) Job finished with error $($job.Streams.Error)"
                    }
                    $result = $parameters.output
                    $lastexitcode = $parameters.code
                    $job.EndInvoke($async)
                }


            } else {
                $lastexitcode = 3
                $result = 'check_not_exsist_on_client'
            }

            try{
                if ($result) {
                    Write-Verbose "$(get-date) Sending result to monOpus. The result is $result"
                    $r = Invoke-WebRequest $config.uri -Method Post -UseBasicParsing -Body @{api_key=$($config.api_key);id=$services[$key].id;mon_action='check/handle_result';result=$result;state=$lastexitcode}
                    $response = $r.content | ConvertFrom-Json
                    Write-Verbose "$(get-date) $response"
                }
            } catch {
                Write-Error "$(get-date) $_"
            }
            
            if ($r.statusCode -eq 200) {
                if (!$response.success -or !$response.data) {
                    Write-Verbose "$(get-date) Removing service $key. Response is $r"
                    $bad_keys += $key
                } else {

                    $services[$key].updatedon = $response.data.updatedon
                    $services[$key].active = $response.data.active
                    $services[$key].interval = if ($response.data.interval) {$response.data.interval} Else {1}

                    # Get new services
                    if ($response.data.push_checks) {
                        $services = Get-Services -Config $config
                    }
                }
            }
        }
    
    }

    if ($bad_keys) {
        foreach ($k in $bad_keys) {
            $services.remove($k)
        }
    }

    Write-Verbose "$(get-date) Finished with services $(ConvertTo-Json $services)"


    if (!$services.count) {
        $work = $false
    }

    sleep -Seconds 60

}

if ($logPath) {
    Stop-Transcript
}