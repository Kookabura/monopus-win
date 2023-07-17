[CmdletBinding()]
Param(
)

$t = $host.ui.RawUI.ForegroundColor
$states_text = @('ok', 'warning', 'critical')
$state_colors = @('Green', 'Yellow', 'Red')
$state = 0

try {
    $syncScheduler = Get-ADSyncScheduler

    $delta = ($( $syncScheduler | Select NextSyncCycleStartTimeInUTC -expandproperty NextSyncCycleStartTimeInUTC).AddHours(+3) - (Get-Date)).TotalMinutes
    $delta = [math]::Round($delta, 0)
    $SyncEnableStatus = $($syncScheduler | Select SyncCycleEnabled  -expandproperty SyncCycleEnabled)
    $MaintenanceEnabledStatus = $($syncScheduler | Select MaintenanceEnabled  -expandproperty MaintenanceEnabled)
    $output = "До запланированной синхронизации $delta минут"
    if (($MaintenanceEnabledStatus -or $SyncEnableStatus) -ne "True") {
        $output = "Статус MaintenanceEnabledStatus = $MaintenanceEnabledStatus, SyncEnableStatus = $SyncEnableStatus"
        $state = 2
    }



    if (($MaintenanceEnabledStatus -and $SyncEnableStatus) -eq "True") {

    if (($delta -gt 35) -and ($delta -lt 70)) {
     $output = "До запланированной синхранизации $delta минут"
     $state = 1
     }
    if ($delta -gt 70) {
     $output = "До запланированной синхранизации $delta минут"
     $state = 2
     }

    }

} catch {
    $state = 2
    $output = $_.Exception.Message
}

$host.ui.RawUI.ForegroundColor = $($state_colors[$state])
Write-Output $output
$host.ui.RawUI.ForegroundColor = $t
exit $state