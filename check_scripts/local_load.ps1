[CmdletBinding()]
Param(
  [Parameter()]
   [int32]$W = 90,
  [Parameter()]
   [int32]$C = 95,
  [Parameter()]
    $config = $global:config,
  [Parameter()]
	$average = -1
)

$states_text = @('ok', 'war', 'critical')
$state = 0
$tmp = (Split-Path $PSCommandPath -Parent) + "/tmp/temp.xml"
$first = $false

if (!(Test-Path (Split-Path $tmp -Parent))) {
    mkdir -Path (Split-Path $tmp -Parent) | Out-Null
}

if (Test-Path $tmp) {
    $indices = Import-Clixml $tmp
} else {
    $indices = @{}
}

if ($indices['cpu'] -ne $null -and (Get-Date) -lt (ls $tmp).LastWriteTime.AddMinutes(60)) {
    $first = $true
}

if (!$first) {
    
    $sample = [wmi]"Win32_PerfRawData_PerfOS_Processor.Name='_Total'"
    $indices = @{'cpu' = @{
            'load' = $sample.PercentProcessorTime
            'timestamp' = $sample.Timestamp_Sys100NS
        }
    }
    $output = "first==1"
} else {
    $sample = [wmi]"Win32_PerfRawData_PerfOS_Processor.Name='_Total'"
    $average = [int]((1 - ( ($sample.PercentProcessorTime - $indices['cpu']['load']) / ($sample.Timestamp_Sys100NS - $indices['cpu']['timestamp']) ) ) * 100)
    while (($average -lt 0 -or $average -gt 100) -and $max -lt 3) {
        $prev_load = if ($sample.PercentProcessorTime) {$sample.PercentProcessorTime} else {$indices['cpu']['load']}
        $prev_timestamp = if ($sample.Timestamp_Sys100NS) {$sample.Timestamp_Sys100NS} else {$indices['cpu']['timestamp']}
        $sample = [wmi]"Win32_PerfRawData_PerfOS_Processor.Name='_Total'"
        $average = [int]((1 - ( ($sample.PercentProcessorTime - $prev_load) / ($sample.Timestamp_Sys100NS - $prev_timestamp) ) ) * 100)
        $max++
    }
    $output = "load==$average | load=$average;$w;$c;0;"
}

if ($average -ge $w -and $average -lt $c) {
    $state = 1
} elseif ($average -ge $c) {
    $state = 2
}


$indices | Export-Clixml $tmp
$output = "local_load_win_$($states_text[$state])::$output"
Write-Output $output
exit $state