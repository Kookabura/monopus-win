[CmdletBinding()]
Param
(
    [Parameter()][int]$warning = 600,
    [Parameter()][int]$critical = 900
)

$states_text = @('ok', 'warning', 'critical', 'unknown')
$state = 0
$lastSync = ""
$secondsAgo = 0

function Get-NtpLastSyncTime {
    $output = w32tm /query /status 2>$null
    
    # Ищем строку, содержащую дату в формате DD.MM.YYYY или MM/DD/YYYY
    $datePattern = '\b\d{1,2}[./]\d{1,2}[./]\d{2,4}\s+\d{1,2}:\d{2}:\d{2}\b'
    
    foreach ($line in $output) {
        if ($line -match $datePattern) {
            $dateString = $matches[0]
            try {
                $date = [DateTime]::Parse($dateString)
                
                # Дополнительная проверка — дата не должна быть в далеком будущем/прошлом
                if ($date -lt (Get-Date).AddYears(1) -and $date -gt (Get-Date).AddYears(-1)) {
                    return $date
                }
            } catch {
                continue
            }
        }
    }
    
    return $null
}

try {
    if ($critical -le $warning) {
        throw "Critical threshold must be greater than warning threshold"
    }
    
    $syncTime = Get-NtpLastSyncTime
    
    if ($syncTime) {
        $lastSync = $syncTime.ToString("yyyy-MM-dd HH:mm:ss")
        $secondsAgo = [math]::Round((New-TimeSpan -Start $syncTime -End (Get-Date)).TotalSeconds, 0)
        
        # Определяем статус
        if ($secondsAgo -ge $critical) {
            $state = 2
        } elseif ($secondsAgo -ge $warning) {
            $state = 1
        } else {
            $state = 0
        }
    } else {
        $lastSync = "N/A"
        $secondsAgo = -1
        $state = 3
    }
}
catch {
    Write-Host $_
    $lastSync = "Error"
    $secondsAgo = -1
    $state = 3
}

$output = "check_ntp_sync.$($states_text[$state])::lastSync==$($lastSync)__secondsAgo==$($secondsAgo) | secondsAgo=$($secondsAgo);;;;" 
Write-Output $output.ToString()
exit $state