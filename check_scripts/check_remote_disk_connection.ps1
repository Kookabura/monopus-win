[CmdletBinding()]
Param
(
	[Parameter()][int32]$period = 15
)

Begin
{
	$t = $host.ui.RawUI.ForegroundColor
	$states_text = @('ok', 'warning', 'critical', 'unknown')
	$state_colors = @('Green', 'Yellow', 'Red', 'DarkGray')
	$event_count = 0
}
	
Process
{
	try
	{
		$event_count = (Get-WinEvent -FilterHashtable @{LogName='Application'; StartTime=$(Get-Date).AddMinutes(('-' + $period)); ID=1521,1504,4098} -ErrorAction SilentlyContinue).count

		if ($event_count -gt 0)
		{
			$state = 2
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
}

End
{
	$output = "check_remote_disk_connection.$($states_text[$state]) | err_connection=$event_count;;;"
	Write-Verbose $output
	$host.ui.RawUI.ForegroundColor = $($state_colors[$state])
	Write-Output $output
	$host.ui.RawUI.ForegroundColor = $t
	exit $state
}
