[CmdletBinding()]
Param
(
	#[Parameter(Mandatory=$true)][string[]]$disk
)

Begin
{
	$t = $host.ui.RawUI.ForegroundColor
	$states_text = @('ok', 'warning', 'critical', 'unknown')
	$state_colors = @('Green', 'Yellow', 'Red', 'DarkGray')
	[string[]]$ofline_disk = $NULL
	$fails = 0
	$state = 3
}

Process
{
	try
	{
		$remote_disks = Get-SmbMapping
		
		foreach ($remote_disk in $remote_disks)
		{
			if ($remote_disk.status -ne "OK")
			{
				$ofline_disk += $remote_disk.localpath + " (" + $remote_disk.remotepath + ")"
				$fails++
			}
		}
		
		<#
		foreach ($path in $disk)
		{
			if (!(test-path $path))
			{
                $ofline_disk += $path
				$fails++
			}
		}#>
		if ($fails -gt 0)
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
	$output = "check_remote_disk_connection.$($states_text[$state])::offline_disks==$([string]::Join(', ', $ofline_disk)) | err_connection=$fails;;;"
	Write-Verbose $output
	$host.ui.RawUI.ForegroundColor = $($state_colors[$state])
	Write-Output $output
	$host.ui.RawUI.ForegroundColor = $t
	exit $state
}
