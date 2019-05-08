[CmdletBinding()]
Param(
  [Parameter()]
   [int32]$period = 10,
  [Parameter()]
   [int32]$W = 0,
  [Parameter()]
   [int32]$C = 10
)

$t = $host.ui.RawUI.ForegroundColor
$states_text = @('ok', 'warning', 'critical', 'unknown')
$state_colors = @('Green', 'Yellow', 'Red', 'DarkGray')
$state = 3

try {
    $attempts = (Get-WinEvent -FilterHashtable @{logname='security'; StartTime=$(Get-Date).AddMinutes(('-' + $period)); keywords=4503599627370496} -ErrorAction SilentlyContinue |  Measure-Object -Sum -Property Id -ErrorAction Stop).Count
    if ($w -and $attempts -ge $w -and $attempts -lt $c) {
        $state = 1
    } elseif ($c -and $attempts -ge $c) {
        $state = 2
    } elseif ($attempts -is [int]) {
        $state = 0
    }
} catch {
    Write-Host $_ -ForegroundColor Red
    $state = 3
}


$output = "brute_force.$($states_text[$state])::attempts==$attempts | attempts=$perf;;;"

$host.ui.RawUI.ForegroundColor = $($state_colors[$state])
Write-Output $output
$host.ui.RawUI.ForegroundColor = $t
exit $state