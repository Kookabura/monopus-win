[CmdletBinding()]
Param(
)
$output = $null
$perf = $null
$states_text = @('ok', 'warning', 'critical')
$state = 0

$inProgressJobs = Get-DPMJob -Status InProgress
$date = Get-Date


if ($inProgressJobs.Count -ge 1 -and $date -ge (Get-date '08:30') -and $date -lt (Get-Date '19:00') -and $date.DayOfWeek -notmatch "Saturday|Sunday") {
    $state = 2
}

$output = "inprogress==$($inProgressJobs.count)"
$perf = "inprogress=$($inProgressJobs.count);;;"
$output = "dpm_running_jobs_$($states_text[$state])::$output | $perf"
Write-Verbose $output
Write-Output $output
exit $state