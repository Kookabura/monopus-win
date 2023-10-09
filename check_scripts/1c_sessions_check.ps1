[CmdletBinding()]
Param(
    [Parameter()][int32]$period = 10,
    [Parameter()][int32]$W = 95,
    [Parameter()][int32]$C = 100,
    [Parameter][string]$server = 'localhost'
)

$states_text = @('ok', 'warning', 'critical', 'unknown')

$platform1c_obj = "V83.COMConnector"
$state = 0
$unicUser = @()
$BackgroundJob = 0

try
{
    try {
        $comobj1c = New-Object -ComObject $platform1c_obj			#Создаем COM объект 1С
    } catch {
        $comDllPath = Get-ChildItem -Path "c:\Program Files" -Filter "comcntr.dll" -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch 'C:\\Program Files\\Microsoft Azure Recovery Services Agent\\Scratch\\SSBV' } | Select-Object -ExpandProperty FullName -last 1

        $regsvr32Output = regsvr32.exe /s $comDllPath           # Если библиотека не зарегистрирована - регистрируем её
        $comobj1c = New-Object -ComObject $platform1c_obj
    }

	$connect1c = $comobj1c.ConnectAgent($server)

	$cluster1c = $connect1c.GetClusters()
	$connect1c.Authenticate($cluster1c[0],"","")

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


