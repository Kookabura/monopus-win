[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true)][string]$H,
  [Parameter()][string]$login = $env:monopus_server_login,
  [Parameter()][string]$password = $env:monopus_server_password,
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

#$url = "https://$($H)/rest/v1/Chassis/1/Thermal"

# Функция для попытки запроса с обработкой редиректа 301/308 -> redfish
function Get-ThermalDataWithFallback {
    param(
        [string]$HostIP,
        [hashtable]$Headers,
        [string]$PrimaryPath = "/rest/v1/Chassis/1/Thermal",
        [string]$FallbackPath = "/redfish/v1/Chassis/1/Thermal"
    )
    
    # Пробуем основной (старый) URL
    $url = "https://$HostIP$PrimaryPath"
    try {
        Write-Verbose "Trying primary URL: $url"
        $data = Invoke-RestMethod -Uri $url -Headers $Headers -ErrorAction Stop
        return $data
    }
    catch {
        # Проверяем, есть ли доступ к ответу сервера
        $response = $_.Exception.Response
        if ($response -and ($response.StatusCode -eq 301 -or $response.StatusCode -eq 308)) {
            Write-Verbose "Got $($response.StatusCode) redirect, trying fallback URL..."
            $fallbackUrl = "https://$HostIP$FallbackPath"
            $data = Invoke-RestMethod -Uri $fallbackUrl -Headers $Headers -ErrorAction Stop
            return $data
        }
        # Если ошибка не связана с редиректом — пробрасываем дальше
        throw
    }
}

try {
    # Получение данных
    #$data = Invoke-RestMethod -Uri $url -Headers $headers -ErrorAction Stop
    $data = Get-ThermalDataWithFallback -HostIP $H -Headers $headers
    
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
                $problem_cpus += "$($cpu_name): $($temp)°C (CRITICAL)"
            } elseif ($temp -ge $W) {
                $cpu_state = 1
                $problem_cpus += "$($cpu_name): $($temp)°C (WARNING)"
            }
            
            # Обновляем общий статус
            if ($cpu_state -gt $state) {
                $state = $cpu_state
            }

            # Добавляем perfdata для каждого CPU с заменой пробелов
            $perf_cpu_name = $cpu_name -replace ' ', '_'
            $perfdata += "$perf_cpu_name=$($temp);;;;"
        }
        
        # Формируем текст вывода
        if ($state -eq 0) {
            $output_text = "$($max_temp)°C"
        } elseif ($problem_cpus.Count -eq 1) {
            $output_text += ("output_count==1__output_details==$($problem_cpus[0])")
        } else {
            $output_text = "output_count==$($problem_cpus.Count)"
            $output_text += ("__output_details==" + ($problem_cpus -join ", "))
        }
    }
} catch {
    $output_text = "output_text==ERROR: $($_.Exception.Message)"
    $state = 3
}

$perfdata_string = $perfdata -join " "
$output = "check_cpu_temperatures.$($states_text[$state])::$($output_text) | $perfdata_string"

Write-Output $output
exit $state