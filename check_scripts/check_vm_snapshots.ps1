[CmdletBinding()]
Param(
)
$output = $null
$perf = $null
$states_text = @('ok', 'warning', 'critical')
$state = 0

$snapshots = Get-VMSnapshot –VMname * | ? {$_.CreationTime -lt (Get-Date).AddDays(-1)}
$snap_count = $snapshots.count

if ($snap_count) 
    {
        $state = "2"
    }

$output = "vm_snapshots_$($states_text[$state])::snapshots==$snap_count | snapshots=$snap_count;;;;;"
Write-Verbose $output
Write-Output $output
exit $state