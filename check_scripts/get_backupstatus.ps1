[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true,
               Position=0,
               ValueFromPipelineByPropertyName=$true,
               ParameterSetName='Parameter Set 1')]
    [ValidateNotNullOrEmpty()]
    [string[]]$backup,
    [Parameter(Mandatory=$true)]
    $storage,
    [Parameter()]
    [string[]]$RetainPolicy = @('daily', 'monthly')
)

Begin {
    $output = $null
    $perf = $null
    $t = $host.ui.RawUI.ForegroundColor
    $states_text = @('ok', 'warning', 'critical', 'unknown')
    $state_colors = @('Green', 'Yellow', 'Red', 'DarkGray')
    $state = @(0)
    $bad_backups = 0
    $backups = @{
        'good' = @();
        'bad' = @();
        'unknown' = @();
    }
}


Process {
    foreach($b in $backup){
        # TODO Оповещение о проблемах с удалением старых копий
        foreach ($policy in $RetainPolicy) {
            $copies = ls "$storage\$policy\$b*" -ErrorAction SilentlyContinue | sort lastwritetime -Descending

            switch ($policy) {
                'daily' {$period = -2}
                'weekly' {$period = -8}
                'monthly' {$period = -32}
            }

            if (!$copies.count -or $copies[0].LastWriteTime -lt (get-date).AddDays($period)) {
                $backups['bad'] += "$($b)_$policy"
                $message = "_expired_latest_copy"
                $state +=2
            }

            $perf += " $($b)_$policy=$($copies.count);;;;;;"

            if ($backups['bad'] -notcontains "$($b)_$policy") {
                $backups['good'] += "$($b)_$policy"
            }
        }

    }
}

End {
    $state = ($state | measure -Maximum).Maximum
    $perf += " bad_backups=" + ($backups['bad'].count + $backups['unknown'].count) + ';1;1;0;' + $backup.count*$RetainPolicy.count
    $output = "good==" + ($backups['good'] -join ',') + "__bad==" + ($backups['bad'] -join ',') + "__unknown==" + ($backups['unknown'] -join ',')
    $output = "get_backupstatus_$($states_text[$state])$message::$output | $perf"
    Write-Verbose $output
    $host.ui.RawUI.ForegroundColor = $($state_colors[$state])
    Write-Output $output
    $host.ui.RawUI.ForegroundColor = $t
    exit $state
}


