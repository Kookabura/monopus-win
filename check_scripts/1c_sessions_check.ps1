[CmdletBinding()]
Param(
    [Parameter()][int32]$period = 10,
    [Parameter()][int32]$W = 95,
    [Parameter()][int32]$C = 100,
   # [Parameter][string]$server = "HV-01"
 #   [Parameter(Mandatory=$true)][string]$server
    [Parameter()][string]$server='localhost',
#    [Parameter(Mandatory=$true)][string]$base_name='bd_test'
   [Parameter()][string]$base_name='bd_test'
)
$states_text = @('ok', 'warning', 'critical', 'unknown')

$platform1c_obj = "V83.COMConnector"
$state = 0
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

    $result = Start-Job -ArgumentList @($server, $log_file, $platform1c_obj) -ScriptBlock {

        $unicUser = @()
        $comobj1c = New-Object -ComObject $args[2]

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

        $result = New-Object PsObject
        $result | Add-Member -Name SessionCount -Value $all_sessions_count -MemberType NoteProperty
        $result | Add-Member -Name UniqueUser -Value $unicUser.count -MemberType NoteProperty
        $result | Add-Member -Name BackgroundJob -Value $BackgroundJob -MemberType NoteProperty

        Write-Output $result

    } | Wait-Job | Receive-Job
	
	if ($result.SessionCount -gt $W)
	{
		$state = 1
		
		if ($result.SessionCount -gt $C)
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

$output = "1c_sessions_check.$($states_text[$state])::all_sessions_count==$($result.SessionCount)__unic_user==$($result.UniqueUser)__background_job==$($BackgroundJob) | all_sessions_count=$($result.SessionCount);;;; unic_user=$($result.UniqueUser);;;; background_job=$($result.BackgroundJob);;;;"

Write-Output $output
exit $state