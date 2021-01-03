[CmdletBinding()]
Param(
  [Parameter()]
   [int32]$W = 90,
  [Parameter()]
   [int32]$C = 95,
  [Parameter()]
   [string[]]$process = @('Idle'),
  [Parameter()]
    $config = $global:config
)

$states_text = @('ok', 'war', 'critical', 'unknown')
$state = 0
$tmp = (Split-Path $PSCommandPath -Parent) + "/tmp/temp_process_load.xml"
$first = $false
$average_sum = $output = $perfdata = $null


if ($process -eq '%') {
    $state = 3
    $output = 'message==process_name_error'

} else {

    if (!(Test-Path (Split-Path $tmp -Parent))) {
        mkdir -Path (Split-Path $tmp -Parent) | Out-Null
    }

    if (Test-Path $tmp) {
        $indices = Import-Clixml $tmp
    } else {
        $indices = @{}
    }

    $total = [wmi]"Win32_PerfRawData_PerfProc_Process.Name='_Total'"
    
    foreach ($p in $process) {

        $query = “Select * from Win32_PerfRawData_PerfProc_Process where name like '$p'”

        if ($perf = gwmi -Query $query) {
            
            $sample = $perf | Measure-Object -Sum -Property PercentProcessorTime

            if ($indices['cpu'] -ne $null -and $indices['cpu'][$p] -ne $null -and (Get-Date) -lt (ls $tmp).LastWriteTime.AddMinutes(60)) {
                $first = $true
            }

            if (!$first) {

                if ($indices['cpu'] -ne $null) {
                    $indices['cpu'][$p] = $sample.sum
                } else {
                    $indices = @{'cpu' = @{
                            $p = $sample.sum
                            'total' = $total.PercentProcessorTime
                        }
                    }
                }

                $output = "process==$($p)__first==1"

            } else {

                $average = [int](( ($sample.sum - $indices['cpu'][$p]) / ($total.PercentProcessorTime - $indices['cpu']['total']) ) * 100)
                $indices['cpu'][$p] = $sample.sum

                if ($average -lt 0 -or $average -gt 100) {
                    # Need regetting the samples
                    $output = "process==$($p)__first==1"
                    $average_sum = 0
                
                } else {

                    $prefix = if ($output) {'__'} else {''}
                    $output +=  "$($prefix)$($p)_load==$average"
                    $perfdata += " $p=$average;$w;$c;0;"

                    $average_sum += $average
                }


            }
        } else {
            $state = 3
            $output = 'message==no_such_process'
        }
    }

    if ($average_sum -ge $w -and $average_sum -lt $c) {
        $state = 1
    } elseif ($average_sum -ge $c) {
        $state = 2
    }

    $indices['cpu']['total'] = $total.PercentProcessorTime
    $indices | Export-Clixml $tmp
}

$output = "process_load_win_$($states_text[$state])::$output|$perfdata"
Write-Output $output
exit $state