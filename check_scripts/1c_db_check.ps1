[CmdletBinding()]
Param(
    [Parameter()][float]$W = 0.8,
    [Parameter()][float]$C = 1,
    [Parameter()][int32]$period = 10
)

$t = $host.ui.RawUI.ForegroundColor
$states_text = @('ok', 'warning', 'critical', 'unknown')
$state_colors = @('Green', 'Yellow', 'Red', 'DarkGray')

$platform1c_obj = "V83.COMConnector"
#$service1c_name =  "1C:Enterprise 8.3 Server Agent*"
$agent1c_connection = "192.168.10.11"   #192.168.10.10/bd_test, 192.168.10.11/bd_test
#$ErrorActionPreference = "SilentlyContinue"
$state = 0

try
{
    #regsvr32 "c:\Program Files\1cv8\8.3.19.1264\bin\comcntr.dll" IInfoBaseConnectionInfo.durationAllDBMS

	$comobj1c = New-Object -ComObject $platform1c_obj			#Создаем COM объект 1С
	$connect1c = $comobj1c.ConnectAgent($agent1c_connection)	#Подключаемя к агенту сервера 1С


	$cluster1c = $connect1c.GetClusters()						#Получаем доступные кластеры на данном сервере
	$connect1c.Authenticate($cluster1c[0],"","")				#Подключаемся к кластеру; При условии что кластер только один, тоесть выбираем первый - [0]

	#Получаем список сессий
	$sessions = $connect1c.GetSessions($cluster1c[0]) #.durationCurrent #[0]
    $DB_call_time = $connect1c.GetWorkingProcesses($cluster1c[0]).AvgDBCallTime
    $DB_call_time = [math]::Round($DB_call_time, 2)

    if ($DB_call_time -ge $W -and $DB_call_time -lt $C) {
        $state = 1
    } elseif ($DB_call_time -ge $C) {
        $state = 2
    }
}
catch
{
    Write-Host $_ -ForegroundColor Red
    $state = 3
}



$output = "1c_db_check.$($states_text[$state])::db_call_time==$DB_call_time | db_call_time=$DB_call_time;;;;"

$host.ui.RawUI.ForegroundColor = $($state_colors[$state])
Write-Output $output
$host.ui.RawUI.ForegroundColor = $t
exit $state