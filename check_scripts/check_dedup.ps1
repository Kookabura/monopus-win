[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)][string]$volume
)

$states_text = @('ok', 'warning', 'critical', 'unknown')
$volume = $volume.TrimEnd(':') + ':'
$state = 3 # unknown по умолчанию

try {
    # Пробуем получить информацию о дедупликации
    $result = Get-DedupVolume -ErrorAction Stop | Where-Object {$_.Volume -eq $volume}
    
    if ($result) {
        if ($result.Enabled) {
            $state = 0 # ok - дедупликация включена
            
            # Извлекаем числовые значения для графиков
            $savedSpace = $result.SavedSpace -replace '[^\d\.]'
            $savingsRate = $result.SavingsRate -replace '[^\d\.]'
            
            # Определяем множитель для SavedSpace
            $unit = $result.SavedSpace -replace '[\d\.\s]', ''
            $multiplier = switch ($unit) {
                'TB' { 1TB }
                'GB' { 1GB }
                'MB' { 1MB }
                'KB' { 1KB }
                default { 1 }
            }
            
            $savedSpaceBytes = [double]$savedSpace * $multiplier
            
            $perfData = "saved_space=$([math]::Round($savedSpaceBytes,2))B;;; savings_rate=$($savingsRate)%;;;"
        }
        else {
            $state = 2 # critical - дедупликация отключена
            $perfData = "saved_space=0B;;; savings_rate=0%;;;"
        }
    }
    else {
        # Том не найден в результатах дедупликации
        $state = 3 # unknown
        $perfData = "saved_space=0B;;; savings_rate=0%;;;"
    }
}
catch {
    # Ошибка при выполнении команды (служба не установлена или другая ошибка)
    $state = 3 # unknown
    $perfData = "saved_space=0B;;; savings_rate=0%;;;"
}

$output = "check_dedup.$($states_text[$state]) | $perfData"
Write-Output $output
exit $state