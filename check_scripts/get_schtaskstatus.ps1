[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true,
               Position=0,
               ValueFromPipelineByPropertyName=$true,
               ParameterSetName='Parameter Set 1')]
  [ValidateNotNullOrEmpty()]
  [string[]]$JobName
)

Begin {
    $output = $null
    $perf = $null
    $t = $host.ui.RawUI.ForegroundColor
    $states_text = @('ok', 'warning', 'critical', 'unknown')
    $state_colors = @('Green', 'Yellow', 'Red', 'DarkGray')
    $state = @()
    $bad_jobs = 0
    $jobs = @{
        'good' = @();
        'bad' = @();
        'unknown' = @();
    }
}


Process {
    foreach($job in $JobName){
        if ($task = Get-ScheduledTaskInfo $job -ErrorAction SilentlyContinue) {
            if (($task.LastTaskResult -ne "0") -and ($task.LastTaskResult -ne "267009"))
			{ 
                $state += 2
                $jobs['bad'] += $job
            } else {
                $state += 0
                $jobs['good'] += $job
            }
        } else {
            $state += 3
            $jobs['unknown'] += $job
        }
    }
}

End {
    $state = ($state | measure -Maximum).Maximum
    $perf = "bad_jobs=" + ($jobs['bad'].count + $jobs['unknown'].count) + ';1;1;0;' + $JobName.count
    $output = "good==" + ($jobs['good'] -join ', ') + "__bad==" + ($jobs['bad'] -join ', ') + "__unknown==" + ($jobs['unknown'] -join ', ')
    $output = "get_schtaskstatus_$($states_text[$state])::$output | $perf"
    Write-Verbose $output
    $host.ui.RawUI.ForegroundColor = $($state_colors[$state])
    Write-Output $output
    $host.ui.RawUI.ForegroundColor = $t
    exit $state
}
