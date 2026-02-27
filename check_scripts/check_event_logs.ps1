[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)][string[]]$LogName,                     # Массив имён журналов (System, Application, ...) (Mandatory=$true)
    [Parameter(Mandatory=$true)][string]$EventID,                       # Массив кодов событий (Mandatory=$true)
    [Parameter()][int]$Period = 60,                                     # Период проверки в минутах
    [Parameter()][int]$W = 1,
    [Parameter()][int]$C = 2
)

# Функция приведения входных данных к массиву
function ConvertTo-ArrayFromInput {
    param($InputValue)
    if ($InputValue -is [string]) {
        return ($InputValue -split ',' | ForEach-Object { $_.Trim() })
    } elseif ($InputValue -is [array]) {
        if ($InputValue.Count -eq 1 -and $InputValue[0] -is [string] -and $InputValue[0] -match ',') {
            return ($InputValue[0] -split ',' | ForEach-Object { $_.Trim() })
        } else {
            return $InputValue
        }
    } else {
        return ,$InputValue
    }
}

$LogName = ConvertTo-ArrayFromInput $LogName
$EventID = ConvertTo-ArrayFromInput $EventID
$EventID = $EventID | ForEach-Object { [int]$_ }

$states_text = @('ok', 'warning', 'critical', 'unknown')
$state = 3
$totalCount = 0
$errorOccurred = $false
$startTime = (Get-Date).AddMinutes(-$Period)

foreach ($log in $LogName) {
    $logInfo = Get-WinEvent -ListLog $log -ErrorAction SilentlyContinue
    if (-not $logInfo) {
        Write-Verbose "Журнал '$log' не существует, пропускаем."
        continue
    }

    try {
        $events = Get-WinEvent -FilterHashtable @{
            LogName   = $log
            ID        = $EventID
            StartTime = $startTime
        } -ErrorAction Stop
        $totalCount += $events.Count
    }
    catch {
        # Обрабатываем ТОЛЬКО реальные ошибки, игнорируя отсутствие событий
        if ($_.Exception.Message -match "No events were found|EventId") {
            Write-Verbose "В журнале '$log' нет событий за последние $Period минут."
        }
        else {
            Write-Warning "Ошибка при обработке журнала '$log': $_"
            $errorOccurred = $true
        }
    }
}

# Определяем состояние
if ($errorOccurred) {
    $state = 3
} elseif ($C -and $totalCount -ge $C) {
    $state = 2
} elseif ($W -and $totalCount -ge $W) {
    $state = 1
} else {
    $state = 0
}

$output = "check_event_logs.$($states_text[$state])::count==$($totalCount) | count=$($totalCount);;;;"

Write-Output $output
exit $state