[CmdletBinding()]
Param(
  [Parameter()]
   [int32]$W = 90,
  [Parameter()]
   [int32]$C = 95
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

if ($indices['cpu'] -ne $null) {
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
    $indices['cpu']['load'] = $sample.PercentProcessorTime
    $indices['cpu']['timestamp'] = $sample.Timestamp_Sys100NS
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