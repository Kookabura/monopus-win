[CmdletBinding()]
Param
(
	[Parameter()][int32]$h = 24
)

$t = $host.ui.RawUI.ForegroundColor
$states_text = @('ok', 'warning', 'critical', 'unknown')
$state_colors = @('Green', 'Yellow', 'Red', 'DarkGray')
$date = (Get-Date).AddHours(-$h)

$state = @(0)
$backup_names = @{
    'Failed' = @();
    'Warning' = @();
}

try
{
	asnp VeeamPSSnapin

	foreach ($Job in (Get-VBRJob | where {$_.JobType -eq "Backup"}))
	{
        foreach ($BackupSession in (Get-VBRBackupSession | Where {$_.jobId -eq $job.Id.Guid}))
        {
            if ($BackupSession.EndTime -ge $date)
            {
                if ($BackupSession.Result -eq "Warning")
                {
                    $backup_names['Warning'] += $BackupSession.OrigJobName
                    $state += 1
                }

                if ($BackupSession.Result -eq "Failed")
                {
                    $backup_names['Failed'] += $BackupSession.OrigJobName
                    $state += 2
                }
            }
        }
	}

    $state = ($state | measure -Maximum).Maximum
} 
catch
{
	$state = 3
}

$perf = "warning_backups=" + $backup_names['Warning'].count + ';1;1;0;' + " failed_backups="+ $backup_names['Failed'].count + ';1;1;0;'
$output = "Warning==" + ($backup_names['Warning'] -join ', ') + "__Failed==" + ($backup_names['Failed'] -join ', ')

$output = "check_veeam_backup_status.$($states_text[$state])$message::$output | $perf"
$host.ui.RawUI.ForegroundColor = $($state_colors[$state])
Write-Output $output
$host.ui.RawUI.ForegroundColor = $t
exit $state
