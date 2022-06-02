[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true)]
   [string[]]$H, #= @('ya.ru')
  [Parameter()]
   [string]$W = 10,
  [Parameter()]
   [string]$C = 5
)

$t = $host.ui.RawUI.ForegroundColor
$states_text = @('ok', 'warning', 'critical', 'unknown')
$state_colors = @('Green', 'Yellow', 'Red', 'DarkGray')
$state = 0
foreach($server in $H) {
    $res = Test-Connection -ComputerName $server -Count 5 -Quiet
    if($res -ne $true) {$state = 2}
}

$output = "check_ping_$($states_text[$state])"
$host.ui.RawUI.ForegroundColor = $($state_colors[$state])
Write-Output $output
$host.ui.RawUI.ForegroundColor = $t
exit $state