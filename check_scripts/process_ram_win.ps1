[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true)]
   [int32]$W,
  [Parameter(Mandatory=$true)]
   [int32]$C,
  [Parameter(Mandatory=$true)][string]$process,
  #[Parameter()]
   #[string[]]$process = @('rphost'),
  [Parameter()]
    $config = $global:config
)

$states_text = @('ok', 'warning', 'critical', 'unknown')
$output = $perfdata = $null


if ($process -eq '%') {
    $state = 3
    $output = 'message==process_name_error'

} else {
    try
    {

        $sample = Get-Process -Name $process -ErrorAction Stop
        $mem = $sample | Measure-Object -Sum -Property WorkingSet64
        $mem = [math]::Round(($mem.Sum / 1MB), 2)
        #$mem = [math]::Round(($mem.sum / 1024) / 1024, 2)

       # $prefix = if ($output) {'__'} else {''}
       # $output +=  "$($prefix)$($p)_ram==$mem"
       # $perfdata += " $p=$mem;;;;"

        if ($mem -ge $w -and $mem -lt $c) {
        $state = 1
        } elseif ($mem -ge $c) {
        $state = 2
        } else {$state = 0
        }
    }
    catch [Microsoft.PowerShell.Commands.ProcessCommandException]
    {
        $state = 3
        $output = 'message==no_such_process'
    }
}
if ($output) {
    $output = "process_ram_win_$($states_text[$state])::$output"
    Write-Output $output
    exit $state
}
else{
    $output = "process_ram_win_$($states_text[$state])::ram==$mem | ram=$mem;;;;"
    Write-Output $output
    exit $state
}

