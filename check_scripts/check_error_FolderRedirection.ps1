[CmdletBinding()]
Param(
)
$output = $null
$perf = $null
$states_text = @('ok', 'warning', 'critical')
$state = 0

#проверка
$Events = Get-WinEvent -FilterHashtable @{LogName='Application'; ID=502} -ErrorAction SilentlyContinue | ? {$_.TimeCreated -le (Get-Date).AddDays(-2)}
$EventsCount = $Events.Count
#

if ($EventsCount) 
    {
        $state = "2"
    }

$output = "EventsCount$($states_text[$state])::Events==$EventsCount | Events=$EventsCount;;;;;"
Write-Verbose $output
Write-Output $output
exit $state