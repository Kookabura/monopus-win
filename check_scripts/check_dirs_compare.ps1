[CmdletBinding()]
Param
(
	[Parameter(Mandatory=$true)][string]$source,
	[Parameter(Mandatory=$true)][string]$destination,
	[Parameter()][string[]]$backupTasks
)

Begin
{
	$output = $null
	$diff = $null
	$t = $host.ui.RawUI.ForegroundColor
	$states_text = @('ok', 'warning', 'critical', 'unknown','task_is_active')
	$state_colors = @('Green', 'Yellow', 'Red', 'DarkGray')
	$state = 3
	$state2 = 3
	[bool]$backup = $false
}

Process
{
	try
	{
		foreach($backupTask in $backupTasks)
		{
			if ((Get-ScheduledTaskInfo $backupTask).State -eq 'Running')
			{
				$state=0
				$state2=4
				Write-Host 'Dirs are different, but the task is still running' -ForegroundColor Yellow
				$backup = $true
			}
		}
		
		if (!$backup)
		{
			$fso = Get-ChildItem -Recurse -path $source
			$fsoBU = Get-ChildItem -Recurse -path $destination
			$cmp = Compare-Object -ReferenceObject $fso -DifferenceObject $fsoBU
			$diff = $cmp.InputObject.Count
			
			if($diff -eq 0)
			{
				$state = 0
			}
			else
			{
				$state = 2
			}
			
			$state2=$state
		}
	}
	catch
	{
		Write-Host $_ -ForegroundColor Red
	}
}

End
{
	$output = "check_dirs_compare.$($states_text[$state2]) | diff=$diff;;;"
	Write-Verbose $output
	$host.ui.RawUI.ForegroundColor = $($state_colors[$state])
	Write-Output $output
	$host.ui.RawUI.ForegroundColor = $t
	exit $state
}
