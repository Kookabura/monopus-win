[CmdletBinding()]
Param(
  [Parameter()]
   [int32]$W = 3,
  [Parameter()]
   [int32]$C
)

$states_text = @('ok', 'warning', 'critical')
$state = 0

$boottime = Get-WmiObject win32_operatingsystem | % {$_.ConvertToDateTime($_.lastbootuptime)}
$uptime = [int]((get-date) - ([datetime]$boottime)).TotalSeconds
$perf = [int]((get-date) - ([datetime]$boottime)).TotalMinutes

if ($uptime -le $w -and $uptime -gt $c) {
    $state = 1
} elseif ($c -gt 0 -and $uptime -le $c) {
    $state = 2
}

$output = "uptime.$($states_text[$state])::time==$uptime | uptime=$perf;;;"
Write-Output $output
exit $state