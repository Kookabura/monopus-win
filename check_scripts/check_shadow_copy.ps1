[CmdletBinding()]
Param
(
	[Parameter(Mandatory=$true)][string[]]$disks
)
$states_text = @('ok', 'warning', 'critical', 'unknown')
$state = 3
$storageError = ""
$taskError = ""

try
{
	foreach($disk in $disks)
	{
		$deviceID = (gwmi win32_volume | Where-Object {$_.Name -eq $disk + ":\"}).deviceID
		$deviceID = $deviceID.TrimStart("\\?\")
		$taskDeviceID = $deviceID.TrimStart("Volume").TrimEnd("\")
		$deviceID = "Win32_Volume.DeviceID=`"\\\\?\\" + $deviceID + "\`""
		$shadowQuery = gwmi win32_shadowstorage | Where-Object {$_.Volume -eq $deviceID}
		
		if (!$shadowQuery)
		{
			$storageError += $disk + ", "
		}

		$shadowTask = Get-ScheduledTask -TaskName "ShadowCopyVolume$($taskDeviceID)" -ErrorAction SilentlyContinue

		if (!$shadowTask)
		{
			$taskError += $disk + ", "
		}

	}
	
	if ($storageError -or $taskError)
	{
		$state = 1
	}
	else
	{
		$state = 0
	}
}
catch
{
	Write-Host $_ -ForegroundColor Red
}

$storageError = $storageError.TrimEnd(", ")
$taskError = $taskError.TrimEnd(", ")

$output = "check_shadow_copy.$($states_text[$state])::storage==$($storageError)__task==$($taskError)"
Write-Output $output
exit $state