[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true)][string]$path,
  [Parameter(Mandatory=$false)][string]$E, # Папки-исключения (через запятую: archive,failed)
  [Parameter()][int32]$W,
  [Parameter()][int32]$C
)

$states_text = @('ok', 'warning', 'critical', 'unknown')
$state = 0
$total_files = 0
$metrics = @()

# Разбиваем строку исключений в массив и приводим к нижнему регистру для надежности
$excludeFolders = @()
if ($E) {
    $excludeFolders = $E -split ',' | ForEach-Object { $_.Trim().ToLower() }
}

# Проверяем, существует ли корневая папка
if (-not (Test-Path $path)) {
    Write-Output "check_files_in_folder.unknown | total_files=0"
    exit 3
}

# Ищем все подпапки
$subfolders = Get-ChildItem -Path $path -Directory -ErrorAction SilentlyContinue

if ($subfolders.Count -eq 0) {
    # Если подпапок нет, считаем в корне
    $count = (Get-ChildItem -Path $path -File -ErrorAction SilentlyContinue | Measure-Object).Count
    $total_files = $count
} else {
    # Проходим по каждой папке
    foreach ($folder in $subfolders) {
        $folderNameLower = $folder.Name.ToLower()
        
        # Проверяем, есть ли папка в списке исключений
        if ($excludeFolders -notcontains $folderNameLower) {
            
            # Считаем файлы
            $count = (Get-ChildItem -Path $folder.FullName -File -ErrorAction SilentlyContinue | Measure-Object).Count
            
            # Суммируем ВСЕГДА, даже если файлов 0 (хотя для метрики 0 можно не писать)
            $total_files += $count
            
            # Добавляем метрику, только если файлы есть
            if ($count -gt 0) {
                # Очищаем имя от пробелов и спецсимволов для InfluxDB
                $safe_name = "folder_" + ($folder.Name -replace '[\s\.\-]','_' -replace '[^a-zA-Z0-9_а-яА-Я]','')
                $metrics += "$safe_name=$count"
            }
        }
    }
}

# Добавляем тотал в начало списка метрик
$metrics = @("total_files=$total_files") + $metrics

# Логика статусов
if ($total_files -ge $C) {
    $state = 2 # Critical
} elseif ($total_files -ge $W) {
    $state = 1 # Warning
} else {
    $state = 0 # OK
}

# Формат вывода: Имя.статус | метрика1=значение1 метрика2=значение2
$perfdata = $metrics -join ' '
$output = "check_files_in_folder.$($states_text[$state]) | $perfdata"

Write-Output $output
exit $state