[CmdletBinding()]
Param(
)
$output = $null
$perf = $null
$states_text = @('ok', 'warning', 'critical')
$state = 0

if ($alerts = (Get-DPMAlert | ? {$_.Severity -match "Error|Warning"})) {
    $servers = $alerts.server -join ','
    $issues = ($alerts.DetailedErrorInfo -split ';')[0] -join ','
    $output = "servers==$($servers)__issues==$($issues)"
    $state = 2
}

$output = "dpm_jobs_$($states_text[$state])::$output | $perf"
Write-Verbose $output
Write-Output $output
exit $state