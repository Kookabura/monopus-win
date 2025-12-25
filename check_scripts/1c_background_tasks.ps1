[CmdletBinding()]
Param(
    [Parameter()][int32]$period = 10,
    [Parameter()][int32]$W = 0,
    [Parameter()][int32]$C = 10,
    [Parameter()][string]$server = 'localhost',
    [Parameter(Mandatory=$true)][string]$base_name
)

$t = $host.ui.RawUI.ForegroundColor
$states_text = @('ok', 'warning', 'critical', 'unknown')
$state_colors = @('Green', 'Yellow', 'Red', 'DarkGray')

$platform1c_obj = "V83.COMConnector"
$state = 0
$memory_used = 0
$log_file = 'C:\Program Files (x86)\monopus\check_scripts\1c_background_tasks.log'

try
{
    try {
        Add-Content -Value "$(get-date) Creating com object" -Path $log_file -Encoding Unicode
        $comobj1c = New-Object -ComObject $platform1c_obj			#Создаем COM объект 1С
    } catch {
        Add-Content -Value "$(get-date) COM issue. Starting regsvr32" -Path $log_file -Encoding Unicode
        $comDllPath = Get-ChildItem -Path "c:\Program Files" -Filter "comcntr.dll" -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch 'C:\\Program Files\\Microsoft Azure Recovery Services Agent\\Scratch\\SSBV' } | Select-Object -ExpandProperty FullName -last 1

        $regsvr32Output = regsvr32.exe /s $comDllPath           # Если библиотека не зарегистрирована - регистрируем её
        Add-Content -Value "$(get-date) Creating COM again" -Path $log_file -Encoding Unicode
        $comobj1c = New-Object -ComObject $platform1c_obj
    }

    $memory_used = Start-Job -ArgumentList @($server, $log_file, $platform1c_obj, $base_name) -ScriptBlock {

        Add-Content -Value "$(get-date) Creating com object" -Path $args[1] -Encoding Unicode
        $comobj1c = New-Object -ComObject $args[2]			#Создаем COM объект 1С
    
        Add-Content -Value "$(get-date) ConnectAgent $($args[0])" -Path $args[1] -Encoding Unicode
	    $connect1c = $comobj1c.ConnectAgent($args[0])	#Подключаемя к агенту сервера 1С

        Add-Content -Value "$(get-date) GetClusters" -Path $args[1] -Encoding Unicode
	    $cluster1c = $connect1c.GetClusters()						#Получаем доступные кластеры на данном сервере

        Add-Content -Value "$(get-date) Cluster auth" -Path $args[1] -Encoding Unicode
	    $connect1c.Authenticate($cluster1c[0],"","")				#Подключаемся к кластеру; При условии что кластер только один, тоесть выбираем первый - [0]

	    #Получаем список сессий
	    #$sessions = $connect1c.GetSessions($cluster1c[0]) #.durationCurrent #[0]
        Add-Content -Value "$(get-date) Get sessions" -Path $args[1] -Encoding Unicode
        $infoBases = $connect1c.GetInfoBases($cluster1c[0])

        Add-Content -Value "$(get-date) List bases" -Path $args[1] -Encoding Unicode
        foreach ( $base in $infoBases)
        {
            if ( $base.Name -eq $args[3] )
            {
                Add-Content -Value "$(get-date) GetinfoBaseSessions" -Path $args[1] -Encoding Unicode
                $sessions = $connect1c.GetInfoBaseSessions($cluster1c[0], $base)
            }
        }

        foreach ($session in $sessions)
        {
            if ( $session.AppID -eq "BackgroundJob"  -and $session.MemoryCurrent -gt 0)
            {
                Add-Content -Value "$(get-date) Memory sum $($session.MemoryCurrent)" -Path $args[1] -Encoding Unicode
                $memory_used += $session.MemoryCurrent
            }
       
        }

        Write-Output $memory_used

    } | wait-job | receive-job

}
catch
{
    Write-Host $_ -ForegroundColor Red
    $state = 3
}

$memory_used = [math]::Round($memory_used / 1Mb, 2)

$output = "1c_background_tasks.$($states_text[$state])::memory_used==$memory_used | memory_used=$memory_used;;;;"

$host.ui.RawUI.ForegroundColor = $($state_colors[$state])
Write-Output $output
$host.ui.RawUI.ForegroundColor = $t
exit $state