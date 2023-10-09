[CmdletBinding()]
Param(
    [Parameter()][int32]$period = 10,
    [Parameter()][int32]$W = 0,
    [Parameter()][int32]$C = 10,
    [Parameter][string]$server = 'localhost',
    [Parameter(Mandatory=$true)][string]$base_name
)

$t = $host.ui.RawUI.ForegroundColor
$states_text = @('ok', 'warning', 'critical', 'unknown')
$state_colors = @('Green', 'Yellow', 'Red', 'DarkGray')

$platform1c_obj = "V83.COMConnector"
$state = 0
$memory_used = 0

try
{
    try {
        $comobj1c = New-Object -ComObject $platform1c_obj			#Создаем COM объект 1С
    } catch {
        $comDllPath = Get-ChildItem -Path "c:\Program Files" -Filter "comcntr.dll" -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch 'C:\\Program Files\\Microsoft Azure Recovery Services Agent\\Scratch\\SSBV' } | Select-Object -ExpandProperty FullName -last 1

        $regsvr32Output = regsvr32.exe /s $comDllPath           # Если библиотека не зарегистрирована - регистрируем её
        $comobj1c = New-Object -ComObject $platform1c_obj
    }

	$connect1c = $comobj1c.ConnectAgent($server)	#Подключаемя к агенту сервера 1С


	$cluster1c = $connect1c.GetClusters()						#Получаем доступные кластеры на данном сервере
	$connect1c.Authenticate($cluster1c[0],"","")				#Подключаемся к кластеру; При условии что кластер только один, тоесть выбираем первый - [0]

	#Получаем список сессий
	#$sessions = $connect1c.GetSessions($cluster1c[0]) #.durationCurrent #[0]
    $infoBases = $connect1c.GetInfoBases($cluster1c[0])
    foreach ( $base in $infoBases)
    {
        if ( $base.Name -eq $base_name )
        {
            $sessions = $connect1c.GetInfoBaseSessions($cluster1c[0], $base)
        }
    }
    

    foreach ($session in $sessions)
    {
        if ( $session.AppID -eq "BackgroundJob" )
        {

            $memory_used += $session.MemoryCurrent
        }
       
    }
}
catch
{
    Write-Host $_ -ForegroundColor Red
    $state = 3
}


$memory_used = [math]::Round(($memory_used / 1024) / 1024, 2)


$output = "1c_background_tasks.$($states_text[$state])::memory_used==$($memory_used) | memory_used=$($memory_used);;;;"

$host.ui.RawUI.ForegroundColor = $($state_colors[$state])
Write-Output $output
$host.ui.RawUI.ForegroundColor = $t
exit $state


