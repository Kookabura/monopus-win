[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true)][string]$H,
  [Parameter(Mandatory=$true)][string]$login,
  [Parameter(Mandatory=$true)][string]$password,
  [Parameter()][int]$W = 40,
  [Parameter()][int]$C = 60
)

$states_text = @('ok', 'warning', 'critical', 'unknown')
$state = 0
$perfdata = @()
$output_text = ""
$max_temp = 0
$problem_cpus = @()

# SSL bypass для PowerShell 5.1
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy


# Подготовка аутентификации
$pair = "$login`:$password"
$bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
$base64 = [Convert]::ToBase64String($bytes)
$headers = @{
    Authorization = "Basic $base64"
    "Content-Type" = "application/json"
}

$url = "https://$($H)/rest/v1/Chassis/1/Thermal"

try {
    # Получение данных
    $data = Invoke-RestMethod -Uri $url -Headers $headers -ErrorAction Stop
    
    # Фильтрация CPU
    $cpus = $data.Temperatures | Where-Object { $_.Name -match 'CPU' }
    
    if (-not $cpus) {
        $output_text = "Датчики температуры процессора не обнаружены."
        $state = 3
    } else {
        # Обработка каждого процессора
        foreach ($cpu in $cpus) {
            $temp = $cpu.ReadingCelsius
            $cpu_name = $cpu.Name
            
            # Обновляем максимальную температуру
            if ($temp -gt $max_temp) {
                $max_temp = $temp
            }
            
            # Проверка порогов для этого CPU
            $cpu_state = 0
            if ($temp -ge $C) {
                $cpu_state = 2
                $problem_cpus += "$($cpu_name): ${temp}°C (CRITICAL)"
            } elseif ($temp -ge $W) {
                $cpu_state = 1
                $problem_cpus += "$($cpu_name): ${temp}°C (WARNING)"
            }
            
            # Обновляем общий статус
            if ($cpu_state -gt $state) {
                $state = $cpu_state
            }
            
            # Добавляем perfdata для каждого CPU
            $perfdata += "'$cpu_name'=${temp};$W;$C;0;"
        }
        
        # Формируем текст вывода
        if ($state -eq 0) {
            $output_text = "${max_temp}°C"
        } elseif ($problem_cpus.Count -eq 1) {
            $output_text = "$($problem_cpus[0])"
        } else {
            $output_text = "$($problem_cpus.Count)"
            $output_text += " - " + ($problem_cpus -join ", ")
        }
    }
} catch {
    $output_text = "ERROR: $($_.Exception.Message)"
    $state = 3
}

$perfdata_string = $perfdata -join " "
$output = "check_cpu_temperatures.$($states_text[$state])::$output_text | $perfdata_string"

Write-Output $output
exit $state