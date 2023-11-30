[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true)][string]$python,
  [Parameter()][string]$pythonScript = "C:\Program Files (x86)\MonOpus\check_scripts\vendor\PowerChute\get_data.py"
)

$thresholds = [PSCustomObject]@{
    'ok' = [PSCustomObject]@{
        BatteryCharge = 95
        SelfTestDate = 14
        RuntimeCalibDate = 85
    }
    'war' = [PSCustomObject]@{
        BatteryCharge = 80
        SelfTestDate = 20
        RuntimeCalibDate = 90
    }
    'cri' = [PSCustomObject]@{
        BatteryCharge = 80
        SelfTestDate = 20
        RuntimeCalibDate = 90
    }
}

$states_text = @('ok', 'war', 'cri')
$jsonOutput = & $python $pythonScript
$result = $jsonOutput | ConvertFrom-Json

Write-Verbose $jsonOutput

$checkResult = [PSCustomObject]@{   
    BatteryCharge = 0
    SelfTestDate = 0
    SelfTestStaus = 0
    RuntimeCalibDate = 0
}

$info = '';

if ([double]$result.status.BatteryCharge -lt $thresholds.cri.BatteryCharge) {
    $checkResult.BatteryCharge = 2
    $info += ' Заряд батареи < 80%,'
} elseif ([double]$result.status.BatteryCharge -ge $thresholds.war.BatteryCharge -and
    [double]$result.status.BatteryCharge -lt $thresholds.ok.BatteryCharge) {
    $checkResult.BatteryCharge = 1
    $info += ' Заряд батареи >= 80%,'
}

if ($result.status.LastReplaceBatteryTestStatus -eq 'not passed') {
    $checkResult.SelfTestDate = 2
    $info += ' Статус селф-теста not passed,'
}

$selfTestDate = [datetime]::parseexact($result.diagnostics.SelfTestDate, 'dd.MM.yyyy', $null) 
$selfTestDateDifference = (Get-Date) - $selfTestDate
if ($selfTestDateDifference.Days -lt $thresholds.ok.SelfTestDate) {
    $checkResult.SelfTestDate = 0
} elseif ($selfTestDateDifference.Days -gt $thresholds.ok.SelfTestDate) {
    $checkResult.SelfTestDate = 1
    $info += ' Дата селф-теста > 14 дней,'
} elseif ($selfTestDateDifference.Days -gt -$thresholds.cri.SelfTestDate) {
    $checkResult.SelfTestDate = 2
    $info += ' Дата селф-теста > 20дней,'
}


$runtimeCalibDate = [datetime]::parseexact($result.diagnostics.RuntimeCalibDate, 'dd.MM.yyyy', $null) 
$runtimeCalibDateDifference = (Get-Date) - $runtimeCalibDate
if ($runtimeCalibDateDifference.days -lt -$thresholds.ok.RuntimeCalibdate) {
    $checkResult.RuntimeCalibDate = 0
} elseif ($runtimeCalibDateDifference.days -gt $thresholds.ok.RuntimeCalibdate) {
    $checkResult.RuntimeCalibDate = 1
    $info += ' Дата калибровки > 85 дней,'
} elseif ($runtimeCalibDateDifference.days -gt $thresholds.cri.RuntimeCalibdate) {
    $checkResult.RuntimeCalibDate = 2
    $info += ' Дата калибровки > 90 дней,'
}


$info = $info.Trim() -replace '.$'
if ($info) { $info = "::info==$($info)" }

$state = $checkResult.PSObject.Properties | ForEach-Object { $_.Value } | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum

$output = "check_power_chute.$($states_text[$state])$($info) | SelfTestDate=$($selfTestDateDifference.days);;;; RuntimeCalibdate=$($runtimeCalibDateDifference.days)"
Write-Output $output

exit $state
