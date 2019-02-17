[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true)]
   [string]$CollectionName
)

$output = $null
$perf = $null
$states_text = @('ok', 'warning', 'critical')
$state = 0
# TO DO проверять существование коллекции. Что будет если запустить без коллекции через Monitor-Host?
if ($servers = Get-RDSessionHost -CollectionName $CollectionName | ? {$_.NewConnectionAllowed -ne 'Yes'}) {
    $names = $servers.SessionHost -join ','
    $output = "servers==$($names)"
    $state = 1
}

$output = "rd_servers_$($states_text[$state])::$output | $perf"
Write-Verbose $output
Write-Output $output
exit $state