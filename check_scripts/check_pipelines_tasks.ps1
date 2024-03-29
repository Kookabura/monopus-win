[CmdletBinding()]
Param
(
	[Parameter()][string]$organization_name = "",
	[Parameter()][string]$project_name = "",
	[Parameter()][string]$pass = "",
    [Parameter()][int32]$W,
    [Parameter()][int32]$C
)

$t = $host.ui.RawUI.ForegroundColor
$states_text = @('ok', 'warning', 'critical', 'unknown')
$state_colors = @('Green', 'Yellow', 'Red', 'DarkGray')
$state = 0
$count_active = 0
$count_stuck = 0
$count_warning = 0
$now = get-date

$authenication = @{Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($pass)")) }
$url = "https://dev.azure.com/$($organization_name)/$($project_name)/_apis/pipelines?api-version=6.0-preview.1"

try
{
	$listId += (Invoke-RestMethod -Method GET -Uri $url -Headers $authenication).value.id

	foreach ($id in $listId)
	{
		$pipeUrl = "https://dev.azure.com/$($organization_name)/$($project_name)/_apis/pipelines/$id/runs?api-version=6.0-preview.1"
		$pipeline = Invoke-RestMethod -Method GET -Uri $pipeUrl -Headers $authenication

		foreach ($p in $pipeline.value)
		{
			if ($p.state -eq "inprogress") #"inprogress" "completed"
			{
				$count_active++

				$ts = New-TimeSpan -Start $p.createdDate -End $now
				$minutes_difference = ($ts.Days * 1440) + ($ts.Hours * 60) + $ts.Minutes
                
				if ($minutes_difference -ge $W)
				{
					$count_warning++

					if ($minutes_difference -ge $C)
					{
						$count_stuck++
					}
				}
			}
		}
	}
    
	if ($count_warning -gt 0)
	{
		$state = 1

		if ($count_stuck -gt 0)
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

$output = "check_pipelines_tasks.$($states_text[$state])::warning==$count_warning::stuck==$count_stuck | active_pipelines=$count_active; stuck_pipelines=$count_stuck;"

$host.ui.RawUI.ForegroundColor = $($state_colors[$state])
Write-Output $output
$host.ui.RawUI.ForegroundColor = $t
exit $state
