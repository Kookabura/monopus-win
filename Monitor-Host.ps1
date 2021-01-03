function Monitor-Host {
    <#
    .Synopsis
        Execute scripts with config from monopus.io. Requires Powershell 3.0
    #>

    [CmdletBinding()]
    PARAM(
        [Parameter()]
        [int]$retry_interval = 10,
        [Parameter()]
        [boolean]$work = $false,
        [Parameter()]
        [int]$timeout = 30,
        [Parameter()]
        [string]$config_path = "${env:ProgramFiles(x86)}\MonOpus\main.cfg"
    )

    Begin {
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

        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force


    }

    Process {

        try {
            $config = Get-Content -Raw -Path $config_path | ConvertFrom-Json

            #Create checks and host_id if $config_id is empty
            if (!$config.id) {
                Write-Verbose "Creating new item as there is no id in config"
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
                Write-Verbose "$(get-date) Response on creating item is: $($response | convertTo-Json)"
                if (!$response.success) {
                    throw "$(get-date) Error on host creation.";
                }

                $config | Add-Member @{id=$($response.data.id)} -PassThru -Force | Out-Null
                $config | ConvertTo-Json -Compress | Set-Content -Path $config_path
            }

            # TO DO: Add check for several time before stopping because checks might be created later
            while (!$work) {
                Write-Verbose "$(get-date) Getting services for config: $($config | ConvertTo-Json -Compress)"
                if ($services = Get-Services -Config $config) {
                    $work = $true
                    break;
                } else {
                    sleep -Seconds $retry_interval
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
                
                # Handle the service only if it's active, passive, has command attribute and it's tie for that or bad state 
                if ($services[$key].active -and $services[$key].passive -and $services[$key].command -and (($updatedon+$services[$key].interval*60) -lt $timestamp -or $services[$key].state -ge 1)) {
            
                    Write-Verbose "$(get-date) Handling service $key"
           
                    $parameters = @{}
                    if($services[$key].warning) {
                        $parameters['w'] = $services[$key].warning
                    }
                    if($services[$key].critical) {
                        $parameters['c'] = $services[$key].critical
                    }
                    if ($services[$key].args) {
                        $tmp = [System.Collections.ArrayList]($services[$key].args.trim() -replace "\s+"," " -split '^-| -')
                        $tmp.RemoveAt(0)
                        foreach ($p in $tmp) {
                             $a = $p.trim() -split " ",2
                             if ($a[1] -match ',') {
                                $value = $a[1] -split ','
                             } else {
                                $value = $a[1]
                             }
                             $parameters[$a[0]] = $value
                        }
                    }

                    $command = ($config.scripts_path + $services[$key].command + ".ps1")

            
                    $result = $false
                    if (Test-Path $command) {
                        Write-Verbose "$(get-date) Starting check command $command with parameters: $($parameters | ConvertTo-Json)"

                        $job = [PowerShell]::Create().AddScript({
                          param($command, $parameters, $config)
                          $global:a = $config
                          $parameters.output = & $command @parameters
                          $parameters.code = $LASTEXITCODE
                        }).AddArgument($command).AddArgument($parameters).AddArgument($config)

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
                            if ($job.HadErrors -and $job.Streams.Error) {
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
                            
                            # Send result only if state is changed or it's time fot that
                            if ($services[$key].state -ne $lastexitcode -or (($updatedon+$services[$key].interval*60) -lt $timestamp)) {
                                Write-Verbose "$(get-date) Sending result to monOpus. The result is $result"
                                $r = Invoke-WebRequest $config.uri -Method Post -UseBasicParsing -Body @{api_key=$($config.api_key);id=$services[$key].id;mon_action='check/handle_result';result=$result;state=$lastexitcode}
                                $response = $r.content | ConvertFrom-Json
                                Write-Verbose "$(get-date) $response"
                            } else {
                                Write-Verbose "$(get-date) State hasn't changed and it's early to send. Skipping sending to monOpus. $result"
                                continue
                            }
                            
                        }
                    } catch {
                        Write-Error "$(get-date) $_"
                    }
            
                    if ($r.statusCode -eq 200) {
                        if (!$response.success -or !$response.data) {
                            Write-Verbose "$(get-date) Removing service $key. Response is $response"
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
                $services = Get-Services -Config $config
            }

            sleep -Seconds 60

        }
    }

    End {

    }
}

#requires -Version 3.0
Monitor-Host # Add for logging: *>> "$PSScriptRoot\log.log"