[CmdletBinding()]
Param(
  [Parameter()]
   [int32]$period = 10,
  [Parameter()]
   [int32]$W = 5,
  [Parameter()]
   [int32]$C = 10
)

$t = $host.ui.RawUI.ForegroundColor
$states_text = @('ok', 'warning', 'critical', 'unknown')
$state_colors = @('Green', 'Yellow', 'Red', 'DarkGray')
$state = 0
$attempts = 0

try {
    $attempts = (Get-EventLog -LogName Security -After (Get-Date).AddMinutes(('-' + $period)) -InstanceId 4625 -EntryType FailureAudit -ErrorAction SilentlyContinue |  Measure-Object -Sum -Property Index).Count
    if ($attempts -ge $w -and $attempts -lt $c) {
    $state = 1
    } elseif ($c -gt 0 -and $attempts -ge $c) {
        $state = 2
    }
} catch {
    Write-Host $_
    $state = 3
}


$output = "brute_force.$($states_text[$state])::attempts==$attempts | attempts=$perf;;;"

$host.ui.RawUI.ForegroundColor = $($state_colors[$state])
Write-Output $output
$host.ui.RawUI.ForegroundColor = $t
exit $state