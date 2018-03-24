﻿# Host monitoring and sending data to monopus.io

try {
    $config = iex (Get-Content -Raw -Path "${env:ProgramFiles(x86)}\MonOpus\main.cfg")
    $settings_obj = (Invoke-WebRequest $config['uri'] -Method Post -UseBasicParsing -Body @{api_key=$config['api_key'];id=$config['id'];mon_action='check/status';class="host"}).content | ConvertFrom-Json
    $services = @{}
    ($settings_obj.data.services).psobject.properties  | % {$services[$_.Name] = $_.Value}
    $work = $true
} catch {
    Write-Output ("Error on init stage: " + $_)
    exit 1
}

while ($work) {

    $timestamp = [int][double]::Parse((Get-Date -UFormat %s))
    $bad_keys = @()

    foreach ($key in $services.Keys) {

        $updatedon = if ($services[$key].updatedon) {[int][double]::Parse((Get-Date -Date $services[$key].updatedon -UFormat %s))} else {0}
    
        if ($services[$key].active -and $services[$key].passive -and $services[$key].command -and ($updatedon+$services[$key].interval*60) -lt $timestamp) {

            $args = if ($services[$key].args) {$services[$key].args -replace '=', ' '} else {''}
            $command = ($config['scripts_path'] + $services[$key].command + ".ps1")
            $w = if($services[$key].warning) {"-w $($services[$key].warning)"} else {}
            $c = if($services[$key].critical) {"-c $($services[$key].critical)"} else {}
            
            $result = iex "& `"$command`" $args $w $c"
            $r = Invoke-WebRequest $config['uri'] -Method Post -UseBasicParsing -Body @{api_key=$config['api_key'];id=$services[$key].id;mon_action='check/handle_result';result=$result;state=$lastexitcode}
            $response = $r.content | ConvertFrom-Json
            Write-Verbose $response
            
            if ($r.statusCode -eq 200) {
                if (!$response.success -or !$response.data) {
                    $bad_keys += $key
                } else {

                    $services[$key].updatedon = $response.data.updatedon
                    $services[$key].active = $response.data.active
                    $services[$key].interval = if ($response.data.interval) {$response.data.interval} Else {1}
                }
            }
        }
    
    }

    if ($bad_keys) {
        foreach ($k in $bad_keys) {
            $services.remove($k)
        }
    }

    Write-Verbose ($services | Out-String)


    if (!$services.count) {
        $work = $false
    }

    sleep -Seconds 60

}