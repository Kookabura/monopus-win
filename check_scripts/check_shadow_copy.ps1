[CmdletBinding()]
Param
(
	[Parameter(Mandatory=$true)][string[]]$disks
)
$states_text = @('ok', 'warning', 'critical', 'unknown')
$state = 3
$n = 0
$d = ""

try
{
	foreach($disk in $disks)
	{
		$deviceID = (gwmi win32_volume | Where-Object {$_.Name -eq $disk + ":\"}).deviceID
		$deviceID = $deviceID.TrimStart("\\?\")
		$deviceID = "Win32_Volume.DeviceID=`"\\\\?\\" + $deviceID + "\`""
		$shadowQuery = gwmi win32_shadowstorage | Where-Object {$_.Volume -eq $deviceID}
		
		if ($shadowQuery)
		{
			$n++
		}
		else
		{
			$d += " " + $disk
		}
	}
	
    if ($n -eq 0)
	{
		$state = 0
    }
	else
	{
		$state = 1
    }
}
catch
{
    Write-Host $_ -ForegroundColor Red
}

$output = "check_shadow_copy.$($states_text[$state])::$d"
Write-Output $output
exit $state