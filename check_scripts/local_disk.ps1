[CmdletBinding()]

Param(
  [Parameter()]
   [string]$W = 10,
  [Parameter()]
   [string]$C = 5,
  [Parameter()]
   [string]$drive = 'C'
)

$output = $null
$perf = $null
$t = $host.ui.RawUI.ForegroundColor
$state_colors = @('Green', 'Yellow', 'Red', 'DarkGray')
$states_text = @('ok', 'warning', 'critical', 'unknown')
$state = 0
$W = $W -replace "[^0-9]"
$C = $C -replace "[^0-9]"

Write-Verbose "Проверяем диск $drive"
if ($drive.Length -eq 1) {
    $drive += ':\'
} elseif ($drive.Length -eq 2) {
    $drive += '\'
}

$drive = $drive -replace '\\','\\'

$vol = gwmi Win32_Volume -Filter "Name='$($drive)'"

if ($vol) {

  $used_units = $vol.Capacity - $vol.FreeSpace
  $used_pct = [math]::Round($used_units*100/$vol.Capacity)
  $free_pct = [math]::Round($vol.FreeSpace*100/$vol.Capacity)

  $disk_name = $drive.trim(':\').Replace('\\','\')
  
  if ($vol.FreeSpace -lt 1Gb) {
    $free_units = "$([math]::Round($vol.FreeSpace/1Mb))Mb"
  } elseif ($vol.FreeSpace -lt 1Tb) {
    $free_units = "$([math]::Round($vol.FreeSpace/1Gb, 1))Gb"
  } else {
    $free_units = "$([math]::Round($vol.FreeSpace/1Tb, 1))Tb"
  }

  $output += "::dev==$($disk_name)__free_units==$($free_units)__dused_units==$([math]::Round($used_units/1Mb))__dused_pct==$($used_pct)"
  $perf += $disk_name + '=' + [math]::Round($used_units/1Mb) + "MB;" + [math]::Round($vol.Capacity*$w/100/1MB) + ';' + [math]::Round($vol.Capacity*$c/100/1MB) + ';0;' + [math]::Round($vol.Capacity/1Mb) + ' '
  if ($w -and $c) {
      if ($free_pct -le $W -and $free_pct -gt $C) {
        $state = 1
      } elseif ($free_pct -le $C) {
        $state = 2
      }
  }
} else {
    $state = 2
    $output = "_not_found::dev==$($drive)"
}

$output = "local_disk_$($states_text[$state])$output | $perf"

Write-Verbose $output
$host.ui.RawUI.ForegroundColor = $($state_colors[$state])
Write-Output $output
$host.ui.RawUI.ForegroundColor = $t
exit $state