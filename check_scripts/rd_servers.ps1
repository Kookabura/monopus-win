[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true)]
   [string]$CollectionName
)

$output = $null
$perf = $null
$t = $host.ui.RawUI.ForegroundColor
$states_text = @('ok', 'warning', 'critical', 'unknown')
$state_colors = @('Green', 'Yellow', 'Red', 'DarkGray')
$state = 0
# TO DO проверять существование коллекции. Что будет если запустить без коллекции через Monitor-Host?
if ($servers = Get-RDSessionHost -CollectionName $CollectionName -ErrorAction SilentlyContinue) {
    if ($servers = $servers | ? {$_.NewConnectionAllowed -ne 'Yes'}) {
        $names = $servers.SessionHost -join ','
        $output = "servers==$($names)"
        $state = 1
    }
} else {
    $state = 3
}

$output = "rd_servers_$($states_text[$state])::$output | $perf"
Write-Verbose $output
$host.ui.RawUI.ForegroundColor = $($state_colors[$state])
Write-Output $output
$host.ui.RawUI.ForegroundColor = $t
exit $state