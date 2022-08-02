[CmdletBinding()]
Param
(
	[Parameter(Mandatory=$true)][string[]]$disk
)

Begin
{
	$t = $host.ui.RawUI.ForegroundColor
	$states_text = @('ok', 'warning', 'critical', 'unknown')
	$state_colors = @('Green', 'Yellow', 'Red', 'DarkGray')
	$fails = 0
	$state = 3
}

Process
{
	try
	{
		foreach ($path in $disk)
		{
			if ( test-path $path )
			{
				$state = 0
			}
			else
			{
				$state = 2
				$fails++
			}
		}
	}
	catch
	{
		Write-Host $_ -ForegroundColor Red
	}
}

End
{
	$output = "check_remote_disk_connection.$($states_text[$state]) | err_connection=$fails;;;"
	Write-Verbose $output
	$host.ui.RawUI.ForegroundColor = $($state_colors[$state])
	Write-Output $output
	$host.ui.RawUI.ForegroundColor = $t
	exit $state
}