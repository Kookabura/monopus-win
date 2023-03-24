[CmdletBinding()]
Param(
)
$output = $null
$perf = $null
$t = $host.ui.RawUI.ForegroundColor
$states_text = @('ok', 'warning', 'critical', 'unknown')
$state_colors = @('Green', 'Yellow', 'Red', 'DarkGray')
$state = 0

#Задаем глубину просмотра журнала
$Date = (Get-Date).AddDays(-1)
#Выбираем журнал; Если есть ошибки, предупреждения или сбои, говорим об ошибке; если бекапа не было, тоже ошибка
$errors = Get-WinEvent -FilterHashtable @{logname="Microsoft-Windows-Backup"; level=1,2,3; starttime=$date} -ErrorAction SilentlyContinue
$finished_backups = Get-WinEvent -FilterHashtable @{logname="Microsoft-Windows-Backup"; level=4; ID=14; starttime=$date} -ErrorAction SilentlyContinue

if ($errors.Count -or $finished_backups.count -eq 0) {
    $state = 2
}

$output = "check_wbackup.$($states_text[$state])::errors==$($errors.Count)__finished_backups==$($finished_backups.count) | errors=$($errors.Count);;;;; finished_backups=$($finished_backups.count);;;;;"
Write-Verbose $output
Write-Output $output
exit $state