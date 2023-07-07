[CmdletBinding()]
Param(
    [Parameter()][int32]$period = 10,
    [Parameter()][int32]$W = 95,
    [Parameter()][int32]$C = 100
)

$states_text = @('ok', 'warning', 'critical', 'unknown')

$platform1c_obj = "V83.COMConnector"
#$service1c_name =  "1C:Enterprise 8.3 Server Agent*"
$agent1c_connection = "192.168.10.11"   #192.168.10.10/bd_test, 192.168.10.11/bd_test
#$ErrorActionPreference = "SilentlyContinue"
$state = 0
$unicUser = @()
$BackgroundJob = 0

try
{
    #regsvr32 "c:\Program Files\1cv8\8.3.21.1624\bin\comcntr.dll" IInfoBaseConnectionInfo.durationAllDBMS

	$comobj1c = New-Object -ComObject $platform1c_obj			#Создаем COM объект 1С
	$connect1c = $comobj1c.ConnectAgent($agent1c_connection)	#Подключаемя к агенту сервера 1С


	$cluster1c = $connect1c.GetClusters()						#Получаем доступные кластеры на данном сервере
	$connect1c.Authenticate($cluster1c[0],"","")				#Подключаемся к кластеру; При условии что кластер только один, тоесть выбираем первый - [0]

	#Получаем список сессий
	$sessions = $connect1c.GetSessions($cluster1c[0]) #.durationCurrent #[0]

    foreach ($session in $sessions)
    {
        if (($session.AppID -eq "BackgroundJob") -or ($session.AppID -eq "SrvrConsole"))
        {
            $BackgroundJob++
        }
        else
        {
            if (!($unicUser -contains $session.userName))
            {
                $unicUser += $session.userName
            }
        }
    }
	
    $all_sessions_count = [int]$sessions.Count - $BackgroundJob 
	
	if ($all_sessions_count -gt $W)
	{
		$state = 1
		
		if ($all_sessions_count -gt $C)
		{
			$state = 2
		}
	}
}
catch
{
    Write-Host $_ -ForegroundColor Red
    $state = 3
}

$output = "1c_sessions_check.$($states_text[$state])::all_sessions_count==$($all_sessions_count)__unic_user==$($unicUser.count)__background_job==$($BackgroundJob) | all_sessions_count=$($all_sessions_count);;;; unic_user=$($unicUser.count);;;; background_job=$($BackgroundJob);;;;"

Write-Output $output
exit $state


