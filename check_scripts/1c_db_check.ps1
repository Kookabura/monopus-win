[CmdletBinding()]
Param(
    [Parameter()][float]$W = 0.8,
    [Parameter()][float]$C = 1,
    [Parameter()][int32]$period = 10,
    [Parameter(Mandatory=$true)][string]$server
)

$t = $host.ui.RawUI.ForegroundColor
$states_text = @('ok', 'warning', 'critical', 'unknown')
$state_colors = @('Green', 'Yellow', 'Red', 'DarkGray')

$platform1c_obj = "V83.COMConnector"
$state = 0

$perfdata = ""

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
	$sessions = $connect1c.GetSessions($cluster1c[0]) #.durationCurrent #[0]
    $DB_call_time = ($connect1c.GetWorkingProcesses($cluster1c[0]).AvgDBCallTime | measure -Maximum).Maximum
    $DB_call_time = [math]::Round($DB_call_time, 2)

    if ($DB_call_time -ge $W -and $DB_call_time -lt $C) {
        $state = 1
    } elseif ($DB_call_time -ge $C) {
        $state = 2
    }

    $perfdata = "db_call_time=$($DB_call_time);;;;"
}
catch
{
    Write-Host $_ -ForegroundColor Red
    $state = 3
}



$output = "1c_db_check.$($states_text[$state])::db_call_time==$DB_call_time | $($perfdata)"

$host.ui.RawUI.ForegroundColor = $($state_colors[$state])
Write-Output $output
$host.ui.RawUI.ForegroundColor = $t
exit $state

