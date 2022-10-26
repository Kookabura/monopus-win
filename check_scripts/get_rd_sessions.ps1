[CmdletBinding()]
Param(

)

$output = $null
$perf = $null
$t = $host.ui.RawUI.ForegroundColor
$states_text = @('ok', 'warning', 'critical', 'unknown')
$state_colors = @('Green', 'Yellow', 'Red', 'DarkGray')
$state = 0

try
{
    $sessions = (Get-RDUserSession  | measure-object).Count
    if ($sessions -eq 0)
    {
        $sessions = (query session | measure-object).Count
    }
}
catch
{
    $state = 3
}

$output = "get_rd_sessions_$($states_text[$state])::$output | active_sessions=$sessions;0;0;0;"
Write-Verbose $output
$host.ui.RawUI.ForegroundColor = $($state_colors[$state])
Write-Output $output
$host.ui.RawUI.ForegroundColor = $t
exit $state