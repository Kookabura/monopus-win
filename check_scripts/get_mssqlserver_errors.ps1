[CmdletBinding()]
Param
(
    [Parameter()][int32]$d
)

$output = $null
$perf = $null
$t = $host.ui.RawUI.ForegroundColor
$states_text = @('ok', 'warning', 'critical', 'unknown')
$state_colors = @('Green', 'Yellow', 'Red', 'DarkGray')
$c_unit = 0
$state = @(0)
$events_details = @{
    'Error' = @();
    'Warning' = @();
}

try
{
	$Events = Get-WinEvent -FilterHashtable @{logname="Application"; level=1,2,3; starttime=(Get-Date).AddDays(-$d); ProviderName="MSSQLSERVER","SQLSERVERAGENT";} -ErrorAction SilentlyContinue

	foreach ($Event in $Events)
	{
        if ($Event.Level -in (1,2))
        {
            $events_details['Error'] += "EventId: " + $Event.Id + " TimeCreated: " + $Event.TimeCreated + " Message: "+ $Event.Message
            $state += 2
        }
        else
        {
            $events_details['Warning'] += "EventId: " + $Event.Id + " TimeCreated: " + $Event.TimeCreated + " Message: "+ $Event.Message
            $state += 1
        }
	}

	$state = ($state | measure -Maximum).Maximum
    if (($state -eq 2) -and ($events_details['Warning'].count -gt 0))
    {
        $events_details['Error'] += $events_details['Warning']
        $c_unit = $events_details['Warning'].count
    }
}
catch
{
	$state = 3
}

$perf = "error_events=" + ($events_details['Error'].count - $c_unit) + ';1;1;0;' + " warning_events="+ $events_details['Warning'].count + ';1;1;0;'
$output = "error==" + ($events_details['Error'] -join '; ') + "__warning==" + ($events_details['Warning'] -join '; ')

$output = "get_mssqlserver_errors.$($states_text[$state])::$output | $perf"
Write-Output $output
exit $state