[CmdletBinding()]
Param(

)

$output = $null
$perf = $null
$t = $host.ui.RawUI.ForegroundColor
$states_text = @('ok', 'warning', 'critical', 'unknown')
$state_colors = @('Green', 'Yellow', 'Red', 'DarkGray')
$state = 0

$sessions = (Get-RDUserSession  | measure-object).Count
$perf = "active_sessions=" + $sessions + ";0;0;0;"


$output = "get_rd_sessions_$($states_text[$state])::$output | $perf"
Write-Verbose $output
$host.ui.RawUI.ForegroundColor = $($state_colors[$state])
Write-Output $output
$host.ui.RawUI.ForegroundColor = $t
exit $state