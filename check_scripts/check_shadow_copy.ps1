[CmdletBinding()]
Param
(
	[Parameter(Mandatory=$true)][string[]]$disks
)
$states_text = @('ok', 'warning', 'critical', 'unknown')
$state = 3
$d = ""

try
{
	foreach($disk in $disks)
	{
		$deviceID = (gwmi win32_volume | Where-Object {$_.Name -eq $disk + ":\"}).deviceID
		$deviceID = $deviceID.TrimStart("\\?\")
		$deviceID = "Win32_Volume.DeviceID=`"\\\\?\\" + $deviceID + "\`""
		$shadowQuery = gwmi win32_shadowstorage | Where-Object {$_.Volume -eq $deviceID}
		
		if (!$shadowQuery)
		{
            $d += $disk + ", "
		}
	}
	
    if ($d)
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

$d = $d.TrimEnd(", ")

$output = "check_shadow_copy.$($states_text[$state])::disks==$d"
Write-Output $output
exit $state