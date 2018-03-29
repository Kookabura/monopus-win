# Scripts finds processes with big memory usage. It useful on terminal (RDH\RDP) server.
# This check requires admin permission
[CmdletBinding()]
Param(
  [Parameter()]
   [int32]$period = 10,
  [Parameter()]
   [string]$W = 0,
  [Parameter()]
   [string]$C = 2000,
  [Parameter()]
   [string]$in = 'Mb',
  [Parameter()]
   [string]$AllowToKill = ''
)

$t = $host.ui.RawUI.ForegroundColor
$states_text = @('ok', 'warning', 'critical', 'unknown')
$state_colors = @('Green', 'Yellow', 'Red', 'DarkGray')
$state = 0
$procs = @()
$output = ''

$c = $c + $in
try {
    $procs = get-process -IncludeUserName | ? {$_.workingset -ge $c} | select Id, Name, UserName, @{n='Mem (' + $in + ')';e={'{0:N0}' -f ($_.workingset / "1$in")}}
    if ($procs) {
        $state = 2
        $users = ($procs.username | select -Unique) -join ','
        $names = ($procs.name | select -Unique) -join ','
        $output = "big_processes==$($procs.length)__names==$($names)__users==$users"

        if ($AllowToKill) {
            # Kill proccess. There might be shown message for user. Add filter for allowed to be killed process?
            $ak = $AllowToKill -split ','
            foreach ($e in $ak) {
                $procs | ? {$_.name -eq $e} | % {Stop-Process -Id $_.id -Force}
            }
        }
    }
} catch {
    $state = 3
}

$perf = "big_processes=$($procs.length);;;"
$output = "check_process.$($states_text[$state])::$output | $perf"

$host.ui.RawUI.ForegroundColor = $($state_colors[$state])
Write-Output $output
$host.ui.RawUI.ForegroundColor = $t
exit $state