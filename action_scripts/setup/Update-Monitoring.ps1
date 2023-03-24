$recreate_task = $true
$task_login = Read-Host "Enter account login" #domen\login
$task_pass = Read-Host "Enter account password"
$srv_list = 'C:\scripts\srv.txt'

# Return $false or installed version number
Function Update-MonOpusClient
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]$Config,
        [Parameter(Mandatory=$true)][System.Version]$NewVersion
    )
    process
	{
        try 
		{
            if (Test-Path $Config.installation_path) {
                        
                Try { [io.file]::OpenWrite("$($Config.installation_path)\file.tmp").close() }
                Catch { 
                    Write-Warning "Unable to write to output file $outputfile"
                    return $false
                }

                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                Invoke-WebRequest "https://github.com/Kookabura/monopus-win/archive/$NewVersion.zip" -OutFile "$env:TEMP\monopus-win.zip" -UseBasicParsing

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

$config = Get-Content "C:\scripts\monopus-win\main.cfg.sample" -Raw | ConvertFrom-Json
#$config | Add-Member -MemberType NoteProperty -Name 'installation_path' -Value "C:\Program Files (x86)\MonOpus\"
#Update-MonOpusClient -Config $config -NewVersion 1.6.2

foreach ($srv in (Get-Content $srv_list)) {
    Write-Host "Работаю с сервером $srv"
    if ($recreate_task) {
        schtasks /Query /s $srv /TN 'Мониторинг' 2>&1>$null
        if (!$LASTEXITCODE) {
            schtasks /end  /s $srv /tn 'Мониторинг'
            schtasks /delete  /s $srv /tn 'Мониторинг' /f
        }
    }
    if (!(Test-Path "\\$srv\c$\program files (x86)\monopus\"))
    {
        mkdir "\\$srv\c$\program files (x86)\monopus\"
    }

    cp "C:\Program Files (x86)\monOpus\Monitor-Host.ps1" "\\$srv\c$\program files (x86)\monopus\Monitor-Host.ps1"
    cp "C:\Program Files (x86)\monOpus\check_scripts\" "\\$srv\c$\program files (x86)\monopus\check_scripts\" -Force -Recurse

    $config_sample = Get-Content "C:\Program Files (x86)\monOpus\main.cfg.sample" -Raw | ConvertFrom-Json

    if (Test-Path "\\$srv\c$\program files (x86)\monopus\main.cfg") {
        $config = Get-Content "\\$srv\c$\program files (x86)\monopus\main.cfg" -Raw | ConvertFrom-Json

        foreach ($prop in $config_sample.psobject.Properties) {
            if(!(Get-Member -inputobject $config -name $prop.name -Membertype Properties)){
                #Property not exists
                $config | Add-Member -MemberType NoteProperty -Name $prop.name -Value $config_sample.$($prop.name)
            }
        }

    } else {
        $config = $config_sample
    }

    $config | Add-Member -MemberType NoteProperty -Name 'version' -Value 1.6.2 -Force
    $Config | ConvertTo-Json -Compress | Set-Content -Path "\\$srv\c$\program files (x86)\monopus\main.cfg"

    if ($recreate_task) {
        schtasks /Create /s $srv /XML "C:\scripts\scheduler_task.xml" /tn 'Мониторинг' /ru $task_login /rp $task_pass
        schtasks /run  /s $srv /tn 'Мониторинг'
    }
}

# Перезапуск задачи
foreach ($srv in (Get-Content $srv_list)) {
    write-host "restart task on $srv"
    schtasks /End /S $srv /TN 'Мониторинг'
    schtasks /Run /S $srv /TN "Мониторинг"
}

<#foreach ($srv in (Get-Content C:\scripts\srv.txt)) {
    if ($srv -ne 'fs-01') {
        $config = Get-Content "\\$srv\c`$\program files (x86)\monopus\main.cfg" -Raw | ConvertFrom-Json
        $config | Add-Member -MemberType NoteProperty -Name 'task_name' -Value 'Мониторинг' -Force
        $Config | ConvertTo-Json -Compress | Set-Content -Path "\\$srv\c`$\program files (x86)\monopus\main.cfg"
    }
}#>